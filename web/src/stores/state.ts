import { get, writable } from 'svelte/store';
import type { Inventory, ItemData, ItemNotification, RefreshPayload, RefreshSlotPayload, Slot, SlotWithItem } from '../types';
import { fetchNui } from '../lib/nui';

const emptyInventory = (): Inventory => ({
  id: '',
  type: '',
  slots: 0,
  maxWeight: 0,
  weight: 0,
  items: [],
});

export const leftInventory = writable<Inventory>(emptyInventory());
export const rightInventory = writable<Inventory>(emptyInventory());
export const locale = writable<Record<string, string>>({});
export const items = writable<Record<string, ItemData>>({
  water: { name: 'water', label: 'Water', stack: true, usable: true, close: false, count: 0 },
  burger: { name: 'burger', label: 'Burger', stack: true, usable: true, close: false, count: 0 },
});
export const imagePath = writable('images');
export const inventoryVisible = writable(false);
export const hotbarVisible = writable(false);
export const configVisible = writable(false);
export const inventoryLayout = writable<'classic' | 'stacked-right'>((localStorage.getItem('inventory-layout') as 'classic' | 'stacked-right') || 'classic');
export const itemAmount = writable(0);
export const activePlayerSlot = writable<number | null>(null);
export const shiftPressed = writable(false);
export const isBusy = writable(false);
export const additionalMetadata = writable<Array<{ metadata: string; value: string }>>([]);
export const contextMenu = writable<{ item: SlotWithItem; x: number; y: number; align?: 'align-left' | 'align-right' } | null>(null);
export const selectedSlot = writable<SlotWithItem | null>(null);
export const selectedInventorySlot = writable<{ inventory: string; slot: number } | null>(null);
export const tooltip = writable<{ item: SlotWithItem; inventoryType: string; x: number; y: number } | null>(null);
export const dragPreview = writable<{ item: SlotWithItem; x: number; y: number } | null>(null);
export const notifications = writable<ItemNotification[]>([]);
export const pinUnlocks = writable<Record<string, boolean>>({});
export const pinState = writable<{ inventoryId: string | number; required: boolean; unlocked: boolean; error?: string } | null>(null);
export const weaponModal = writable<{ item: SlotWithItem; slot: number } | null>(null);

// Admin audit panel
export type AuditEntry = { category: string; player: string; message: string; time: string };
export const auditVisible = writable(false);
export const auditEntries = writable<AuditEntry[]>([]);

// Built-in notification toasts — our themed replacement for ox_lib's lib.notify
// when ox_lib isn't on the server. Always visible (even with the inventory shut).
export type Toast = { id: number; title?: string; description: string; type: string };
export const toasts = writable<Toast[]>([]);
let toastId = 1;
export function pushToast(data: { title?: string; description: string; type?: string; duration?: number }) {
  const id = toastId++;
  toasts.update((current) => [...current, { id, title: data.title, description: data.description, type: data.type || 'inform' }].slice(-5));
  window.setTimeout(() => {
    toasts.update((current) => current.filter((t) => t.id !== id));
  }, data.duration || 4000);
}

// Keep per-item totals (items[name].count) in sync with the player's holdings,
// so crafting ingredient checks, hotbar counts and give amounts reflect what the
// player actually carries. Driven purely from the left (player) inventory.
leftInventory.subscribe((inv) => {
  items.update((map) => {
    const next: Record<string, ItemData> = {};
    for (const key in map) next[key] = { ...map[key]!, count: 0 };
    for (const slot of inv.items) {
      if (slot.name && next[slot.name]) next[slot.name]!.count += slot.count || 0;
    }
    return next;
  });
});

let hotbarTimer: number | undefined;
let notificationId = 1;

export function isSlotWithItem(slot: Slot | undefined, strict = false): slot is SlotWithItem {
  if (!slot?.name) return false;
  return !strict || (slot.count !== undefined && slot.weight !== undefined);
}

function itemDurability(metadata: Record<string, any> | undefined, curTime: number) {
  if (metadata?.durability === undefined) return undefined;

  let durability = metadata.durability;

  if (durability > 100 && metadata.degrade) {
    durability = ((metadata.durability - curTime) / (60 * metadata.degrade)) * 100;
  }

  return Math.max(0, durability);
}

function sourceItems(raw: Inventory['items'] | Record<string, Slot> | undefined): Slot[] {
  if (!raw) return [];
  return Array.isArray(raw) ? raw : Object.values(raw);
}

export function normalizeInventory(inv?: Partial<Inventory>): Inventory {
  if (!inv) return emptyInventory();

  const slots = Number(inv.slots || 0);
  const rawItems = sourceItems(inv.items as Inventory['items']);
  const curTime = Math.floor(Date.now() / 1000);

  return {
    id: inv.id ?? '',
    type: inv.type ?? '',
    slots,
    maxWeight: inv.maxWeight ?? 0,
    weight: inv.weight ?? 0,
    label: inv.label ?? '',
    groups: inv.groups,
    coords: inv.coords,
    distance: inv.distance,
    instance: inv.instance,
    items: Array.from({ length: slots }, (_, index) => {
      const slotNumber = index + 1;
      const found = rawItems.find((slot) => slot && Number(slot.slot) === slotNumber);
      const slot = found ? { ...found } : { slot: slotNumber };

      if (slot.name) {
        slot.durability = itemDurability(slot.metadata, curTime);
        void ensureItemData(slot.name);
      }

      return slot;
    }),
  };
}

export function setupInventories(data: { leftInventory?: Inventory; rightInventory?: Inventory }) {
  if (data.leftInventory) leftInventory.set(normalizeInventory(data.leftInventory));
  if (data.rightInventory) rightInventory.set(normalizeInventory(data.rightInventory));
  shiftPressed.set(false);
  isBusy.set(false);
}

export function initInventory(data: {
  locale?: Record<string, string>;
  items?: Record<string, ItemData>;
  leftInventory?: Inventory;
  imagepath?: string;
}) {
  if (data.locale) locale.set(data.locale);
  if (data.items) items.set(data.items);
  if (data.imagepath) imagePath.set(data.imagepath);
  if (data.leftInventory) leftInventory.set(normalizeInventory(data.leftInventory));
}

function targetStoreForPayload(payload: RefreshSlotPayload) {
  const left = get(leftInventory);
  const right = get(rightInventory);

  if (!payload.inventory || payload.inventory === 'player' || payload.inventory === left.id) return leftInventory;
  return rightInventory;
}

export function refreshSlots(payload: RefreshPayload) {
  if (payload.items) {
    const slotPayloads = Array.isArray(payload.items) ? payload.items : [payload.items];
    const curTime = Math.floor(Date.now() / 1000);

    for (const data of slotPayloads.filter(Boolean)) {
      const store = targetStoreForPayload(data);

      store.update((inventory) => {
        const itemsCopy = [...inventory.items];
        const slot = { ...data.item };
        slot.durability = itemDurability(slot.metadata, curTime);
        itemsCopy[slot.slot - 1] = slot;
        return { ...inventory, items: itemsCopy };
      });
    }
  }

  if (payload.itemCount) {
    items.update((current) => {
      const copy = { ...current };
      for (const [name, count] of Object.entries(payload.itemCount || {})) {
        if (copy[name]) copy[name] = { ...copy[name]!, count: (copy[name]!.count || 0) + count };
      }
      return copy;
    });
  }

  if (payload.weightData) {
    const { inventoryId, maxWeight } = payload.weightData;
    leftInventory.update((inventory) => (inventory.id === inventoryId ? { ...inventory, maxWeight } : inventory));
    rightInventory.update((inventory) => (inventory.id === inventoryId ? { ...inventory, maxWeight } : inventory));
  }

  if (payload.slotsData) {
    const { inventoryId, slots } = payload.slotsData;
    leftInventory.update((inventory) => (inventory.id === inventoryId ? normalizeInventory({ ...inventory, slots }) : inventory));
    rightInventory.update((inventory) => (inventory.id === inventoryId ? normalizeInventory({ ...inventory, slots }) : inventory));
  }
}

export async function ensureItemData(name: string) {
  if (get(items)[name]) return get(items)[name];

  const response = await fetchNui<ItemData | null>('getItemData', name).catch(() => null);

  if (response?.name) {
    items.update((current) => ({ ...current, [name]: response }));
    return response;
  }

  return undefined;
}

export function getItemLabel(slot: Slot) {
  if (!slot.name) return '';
  return slot.metadata?.label || get(items)[slot.name]?.label || slot.name;
}

export function getItemUrl(item: string | Slot) {
  const path = get(imagePath);

  if (typeof item === 'object') {
    if (!item.name) return '';
    if (item.metadata?.imageurl) return String(item.metadata.imageurl);
    if (item.metadata?.image) return `${path}/${item.metadata.image}.png`;
    item = item.name;
  }

  const itemData = get(items)[item];
  if (itemData?.image) return itemData.image;

  return `${path}/${item}.png`;
}

export function getTotalWeight(inv: Inventory) {
  return inv.items.reduce((total, slot) => total + (isSlotWithItem(slot) ? slot.weight || 0 : 0), 0);
}

export function showHotbar() {
  if (hotbarTimer) window.clearTimeout(hotbarTimer);
  hotbarVisible.set(true);
  hotbarTimer = window.setTimeout(() => hotbarVisible.set(false), 3000);
}

export function addNotification(data: [Slot, string, number?]) {
  const id = notificationId++;
  notifications.update((current) => [...current, { id, item: data[0], kind: data[1], count: data[2] }].slice(-5));
  window.setTimeout(() => {
    notifications.update((current) => current.filter((notification) => notification.id !== id));
  }, 2800);
}

export function mergeAdditionalMetadata(data: Array<{ metadata: string; value: string }>) {
  additionalMetadata.update((current) => {
    const next = [...current];
    for (const entry of data) {
      if (!next.find((item) => item.value === entry.value)) next.push(entry);
    }
    return next;
  });
}

export function closeFloatingUi() {
  contextMenu.set(null);
  tooltip.set(null);
}
