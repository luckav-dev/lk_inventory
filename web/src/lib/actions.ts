import { get } from 'svelte/store';
import {
  closeFloatingUi,
  activePlayerSlot,
  getItemLabel,
  getTotalWeight,
  isBusy,
  isSlotWithItem,
  itemAmount,
  items,
  leftInventory,
  locale,
  notifications,
  rightInventory,
  shiftPressed,
} from '../stores/state';
import type { DragSource, DropTarget, Inventory, ItemData, Slot, SlotWithItem } from '../types';
import { InventoryType } from '../types';
import { fetchNui } from './nui';

type Snapshot = {
  left: Inventory;
  right: Inventory;
};

const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
const isEqual = (a: unknown, b: unknown) => JSON.stringify(a ?? {}) === JSON.stringify(b ?? {});

const snapshot = (): Snapshot => ({
  left: clone(get(leftInventory)),
  right: clone(get(rightInventory)),
});

const restore = (state: Snapshot) => {
  leftInventory.set(state.left);
  rightInventory.set(state.right);
};

function setInventories(left: Inventory, right: Inventory) {
  left.weight = getTotalWeight(left);
  right.weight = getTotalWeight(right);
  leftInventory.set(left);
  rightInventory.set(right);
}

function canStack(sourceSlot: Slot, targetSlot: Slot) {
  return sourceSlot.name === targetSlot.name && isEqual(sourceSlot.metadata, targetSlot.metadata);
}

function findAvailableSlot(item: SlotWithItem, data: ItemData, inv: Inventory) {
  if (data.stack) {
    const stackable = inv.items.find((target) => target.name === item.name && isEqual(target.metadata, item.metadata));
    if (stackable) return stackable;
  }

  return inv.items.find((target) => !target.name);
}

function getInventories(sourceType: string, targetType?: string) {
  const left = clone(get(leftInventory));
  const right = clone(get(rightInventory));

  return {
    left,
    right,
    sourceInventory: sourceType === InventoryType.PLAYER ? left : right,
    targetInventory: targetType
      ? targetType === InventoryType.PLAYER
        ? left
        : right
      : sourceType === InventoryType.PLAYER
        ? right
        : left,
  };
}

function getMoveCount(sourceSlot: SlotWithItem, sourceInventory: Inventory) {
  const amount = get(itemAmount);
  const shift = get(shiftPressed);

  if (shift && sourceSlot.count > 1 && sourceInventory.type !== InventoryType.SHOP) {
    return Math.floor(sourceSlot.count / 2);
  }

  if (amount === 0 || amount > sourceSlot.count) return sourceSlot.count;
  return amount;
}

function applyMove(sourceInventory: Inventory, targetInventory: Inventory, sourceSlot: SlotWithItem, targetSlot: Slot, count: number) {
  const pieceWeight = sourceSlot.weight / sourceSlot.count;
  const fromItem = sourceInventory.items[sourceSlot.slot - 1] as SlotWithItem;
  const clonedSource = clone(fromItem);

  targetInventory.items[targetSlot.slot - 1] = {
    ...clonedSource,
    count,
    weight: pieceWeight * count,
    slot: targetSlot.slot,
  };

  if (sourceInventory.type === InventoryType.SHOP || sourceInventory.type === InventoryType.CRAFTING) return;

  sourceInventory.items[sourceSlot.slot - 1] =
    sourceSlot.count - count > 0
      ? {
          ...sourceInventory.items[sourceSlot.slot - 1],
          count: sourceSlot.count - count,
          weight: pieceWeight * (sourceSlot.count - count),
        }
      : { slot: sourceSlot.slot };
}

function applyStack(sourceInventory: Inventory, targetInventory: Inventory, sourceSlot: SlotWithItem, targetSlot: SlotWithItem, count: number) {
  const pieceWeight = sourceSlot.weight / sourceSlot.count;

  targetInventory.items[targetSlot.slot - 1] = {
    ...targetInventory.items[targetSlot.slot - 1],
    count: targetSlot.count + count,
    weight: pieceWeight * (targetSlot.count + count),
  };

  if (sourceInventory.type === InventoryType.SHOP || sourceInventory.type === InventoryType.CRAFTING) return;

  sourceInventory.items[sourceSlot.slot - 1] =
    sourceSlot.count - count > 0
      ? {
          ...sourceInventory.items[sourceSlot.slot - 1],
          count: sourceSlot.count - count,
          weight: pieceWeight * (sourceSlot.count - count),
        }
      : { slot: sourceSlot.slot };
}

function applySwap(sourceInventory: Inventory, targetInventory: Inventory, sourceSlot: SlotWithItem, targetSlot: SlotWithItem) {
  const sourceIndex = sourceSlot.slot - 1;
  const targetIndex = targetSlot.slot - 1;

  [sourceInventory.items[sourceIndex], targetInventory.items[targetIndex]] = [
    { ...targetInventory.items[targetIndex], slot: sourceSlot.slot },
    { ...sourceInventory.items[sourceIndex], slot: targetSlot.slot },
  ];
}

async function validateMove(data: { fromSlot: number; fromType: string; toSlot: number; toType: string; count: number }) {
  return fetchNui<boolean | number>('swapItems', data);
}

export async function performDrop(source: DragSource, target?: DropTarget) {
  closeFloatingUi();

  const { left, right, sourceInventory, targetInventory } = getInventories(source.inventory, target?.inventory);
  const sourceSlot = sourceInventory.items[source.item.slot - 1];

  if (!isSlotWithItem(sourceSlot, true)) return false;

  if (sourceInventory.type === InventoryType.SHOP) return performBuy(source, target);
  if (sourceInventory.type === InventoryType.CRAFTING) return performCraft(source, target);

  const sourceData = get(items)[sourceSlot.name];
  if (!sourceData) return false;

  if (sourceSlot.metadata?.container && targetInventory.type === InventoryType.CONTAINER) return false;
  if (right.id === sourceSlot.metadata?.container) return false;

  const targetSlot = target
    ? targetInventory.items[target.item.slot - 1]
    : findAvailableSlot(sourceSlot, sourceData, targetInventory);

  if (!targetSlot) return false;
  if (targetSlot.metadata?.container && right.id === targetSlot.metadata.container) return false;

  const count = getMoveCount(sourceSlot, sourceInventory);
  const before = snapshot();

  if (isSlotWithItem(targetSlot, true)) {
    if (sourceData.stack && canStack(sourceSlot, targetSlot)) {
      applyStack(sourceInventory, targetInventory, sourceSlot, targetSlot, count);
    } else {
      applySwap(sourceInventory, targetInventory, sourceSlot, targetSlot);
    }
  } else {
    applyMove(sourceInventory, targetInventory, sourceSlot, targetSlot, count);
  }

  setInventories(left, right);
  isBusy.set(true);

  try {
    const response = await validateMove({
      fromSlot: sourceSlot.slot,
      fromType: sourceInventory.type,
      toSlot: targetSlot.slot,
      toType: targetInventory.type,
      count,
    });

    if (response === false) {
      restore(before);
      return false;
    }

    return true;
  } catch {
    restore(before);
    return false;
  } finally {
    isBusy.set(false);
  }
}

export async function performBuy(source: DragSource, target?: DropTarget) {
  if (!target || target.inventory !== InventoryType.PLAYER) return false;

  const state = get(rightInventory);
  const left = get(leftInventory);
  const sourceSlot = state.items[source.item.slot - 1];
  const targetSlot = left.items[target.item.slot - 1];

  if (!isSlotWithItem(sourceSlot) || !targetSlot) return false;

  const amount = get(itemAmount);
  const count = amount !== 0 ? (sourceSlot.count ? Math.min(amount, sourceSlot.count) : amount) : 1;

  isBusy.set(true);
  try {
    return await fetchNui<boolean>('buyItem', {
      fromSlot: sourceSlot.slot,
      fromType: state.type,
      toSlot: targetSlot.slot,
      toType: left.type,
      count,
    });
  } finally {
    isBusy.set(false);
  }
}

export async function performCraft(source: DragSource, target?: DropTarget) {
  if (!target || target.inventory !== InventoryType.PLAYER) return false;

  const state = get(rightInventory);
  const left = get(leftInventory);
  const sourceSlot = state.items[source.item.slot - 1];
  const targetSlot = left.items[target.item.slot - 1];

  if (!isSlotWithItem(sourceSlot) || !targetSlot) return false;

  isBusy.set(true);
  try {
    return await fetchNui<boolean>('craftItem', {
      fromSlot: sourceSlot.slot,
      fromType: state.type,
      toSlot: targetSlot.slot,
      toType: left.type,
      count: get(itemAmount) || 1,
    });
  } finally {
    isBusy.set(false);
  }
}

export function useItem(slot: Slot) {
  if (slot.name) {
    activePlayerSlot.set(slot.slot);
    void fetchNui('useItem', slot.slot);
  }
}

export function giveItem(slot: Slot) {
  if (slot.name) void fetchNui('giveItem', { slot: slot.slot, count: get(itemAmount) || 1 });
}

export async function dropItem(slot: SlotWithItem) {
  closeFloatingUi();

  const left = clone(get(leftInventory));
  const sourceSlot = left.items[slot.slot - 1];

  if (!isSlotWithItem(sourceSlot, true)) return false;

  const count = getMoveCount(sourceSlot, left);
  const before = snapshot();

  // Optimistically remove from the player inventory; the server confirms via a
  // refreshSlots update and spawns the ground drop.
  const pieceWeight = sourceSlot.weight / sourceSlot.count;
  left.items[sourceSlot.slot - 1] =
    sourceSlot.count - count > 0
      ? { ...sourceSlot, count: sourceSlot.count - count, weight: pieceWeight * (sourceSlot.count - count) }
      : { slot: sourceSlot.slot };

  setInventories(left, get(rightInventory));
  isBusy.set(true);

  try {
    // toType 'newdrop' tells the client to inject the player's coords and the
    // server to create a ground drop (modules/inventory/server.lua dropItem).
    const response = await validateMove({
      fromSlot: sourceSlot.slot,
      fromType: InventoryType.PLAYER,
      toSlot: 1,
      toType: 'newdrop',
      count,
    });

    if (response === false) {
      restore(before);
      return false;
    }

    return true;
  } catch {
    restore(before);
    return false;
  } finally {
    isBusy.set(false);
  }
}

export function throwItem(slot: SlotWithItem) {
  closeFloatingUi();
  void fetchNui('throwItem', { slot: slot.slot });
}

export function removeAmmo(slot: SlotWithItem) {
  void fetchNui('removeAmmo', slot.slot);
}

export function removeComponent(slot: SlotWithItem, component: string) {
  void fetchNui('removeComponent', { component, slot: slot.slot });
}

export function useCustomButton(slot: SlotWithItem, id: number) {
  void fetchNui('useButton', { id: id + 1, slot: slot.slot });
}

export async function lootAllDrops() {
  const right = get(rightInventory);
  if (right.type !== 'drop') return;

  let moved = 0;

  for (const sourceSlot of [...right.items]) {
    if (!isSlotWithItem(sourceSlot, true)) continue;

    const left = get(leftInventory);
    const itemData = get(items)[sourceSlot.name];
    if (!itemData) continue;

    const targetSlot = findAvailableSlot(sourceSlot, itemData, left);
    if (!targetSlot) break;

    const ok = await performDrop(
      { inventory: right.type, item: { name: sourceSlot.name, slot: sourceSlot.slot } },
      { inventory: InventoryType.PLAYER, item: { slot: targetSlot.slot } }
    );

    if (!ok) break;
    moved += 1;
  }

  const strings = get(locale);
  const lootLabel = moved
    ? strings.ui_looted_all || 'Looted all'
    : strings.ui_no_space || 'No space';

  notifications.update((current) => [
    ...current,
    {
      id: Date.now(),
      item: { slot: 0, count: moved, weight: 0, metadata: { label: lootLabel } },
      kind: moved ? 'ui_added' : 'error',
      count: moved,
    },
  ]);

  await fetchNui('lootAllComplete', { count: moved });
}

export function actionLabel(slot: Slot) {
  return slot.name ? getItemLabel(slot) : '';
}
