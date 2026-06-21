export enum InventoryType {
  PLAYER = 'player',
  SHOP = 'shop',
  CONTAINER = 'container',
  CRAFTING = 'crafting',
}

export type Slot = {
  slot: number;
  name?: string;
  count?: number;
  weight?: number;
  metadata?: Record<string, any>;
  durability?: number;
  price?: number;
  currency?: string;
  ingredients?: Record<string, number>;
  duration?: number;
  image?: string;
  grade?: number | number[];
};

export type SlotWithItem = Slot & {
  name: string;
  count: number;
  weight: number;
};

export type Inventory = {
  id: string | number;
  type: string;
  slots: number;
  items: Slot[];
  maxWeight?: number;
  weight?: number;
  label?: string;
  groups?: Record<string, number>;
  coords?: unknown;
  distance?: number;
  instance?: string | number;
};

export type ItemData = {
  name: string;
  label: string;
  stack: boolean;
  usable: boolean;
  close: boolean;
  count: number;
  description?: string;
  buttons?: Array<string | { label: string; group?: string }>;
  ammoName?: string;
  image?: string;
  type?: string;
  component?: boolean;
  weapon?: boolean;
  ammo?: boolean;
  client?: {
    component?: string[];
  };
};

export type DragSource = {
  inventory: string;
  item: Pick<SlotWithItem, 'slot' | 'name'>;
};

export type DropTarget = {
  inventory: string;
  item: Pick<Slot, 'slot'>;
};

export type RefreshSlotPayload = {
  item: Slot;
  inventory?: string | number;
};

export type RefreshPayload = {
  items?: RefreshSlotPayload | RefreshSlotPayload[];
  itemCount?: Record<string, number>;
  weightData?: { inventoryId: string | number; maxWeight: number };
  slotsData?: { inventoryId: string | number; slots: number };
};

export type NuiMessage<T = unknown> = {
  action: string;
  data: T;
};

export type ItemNotification = {
  id: number;
  item: Slot;
  kind: string;
  count?: number;
};
