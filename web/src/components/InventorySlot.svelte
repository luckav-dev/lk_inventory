<script lang="ts">
  import { get } from 'svelte/store';
  import { performDrop, useItem } from '../lib/actions';
  import { formatCount } from '../lib/format';
  import {
    activePlayerSlot,
    contextMenu,
    dragPreview,
    getItemLabel,
    getItemUrl,
    isBusy,
    isSlotWithItem,
    selectedInventorySlot,
    selectedSlot,
    tooltip,
    inventoryLayout,
  } from '../stores/state';
  import type { Inventory, Slot, SlotWithItem } from '../types';
  import WeightBar from './WeightBar.svelte';

  export let inventory: Inventory;
  export let item: Slot;

  let tooltipTimer: number | undefined;
  let dragStart: { x: number; y: number } | null = null;
  let dragElement: HTMLElement | null = null;
  let dragOverElement: HTMLElement | null = null;
  let dragging = false;

  $: isStacked = $inventoryLayout === 'stacked-right';
  $: hasItem = isSlotWithItem(item);
  $: strictItem = isSlotWithItem(item, true) ? item : null;
  $: label = hasItem ? getItemLabel(item) : '';
  $: image = hasItem ? getItemUrl(item) : '';
  $: slotDisabled = inventory.type === 'shop' && hasItem && item.count === 0;
  $: isHotbar = inventory.type === 'player' && item.slot <= 5;
  $: isActivePlayerSlot = inventory.type === 'player' && $activePlayerSlot === item.slot;

  function source() {
    if (!strictItem) return null;
    return {
      inventory: inventory.type,
      item: {
        name: strictItem.name,
        slot: strictItem.slot,
      },
    };
  }

  function pointerDown(event: PointerEvent) {
    if (event.button !== 0 || !strictItem || get(isBusy) || slotDisabled) return;

    dragStart = { x: event.clientX, y: event.clientY };
    dragElement = event.currentTarget as HTMLElement;
    dragging = false;
    window.addEventListener('pointermove', pointerMove);
    window.addEventListener('pointerup', pointerUp, { once: true });
  }

  function clearDragOver() {
    dragOverElement?.classList.remove('drag-over');
    dragOverElement = null;
  }

  function pointerMove(event: PointerEvent) {
    if (!dragStart || !strictItem) return;

    const moved = Math.abs(event.clientX - dragStart.x) + Math.abs(event.clientY - dragStart.y);
    if (!dragging && moved < 6) return;

    dragging = true;
    contextMenu.set(null);
    tooltip.set(null);
    dragPreview.set({ item: strictItem, x: event.clientX, y: event.clientY });

    const hoveredSlot = document.elementFromPoint(event.clientX, event.clientY)?.closest<HTMLElement>('.inventory-slot');
    if (hoveredSlot && hoveredSlot !== dragElement) {
      if (dragOverElement !== hoveredSlot) {
        clearDragOver();
        dragOverElement = hoveredSlot;
        dragOverElement.classList.add('drag-over');
      }
    } else {
      clearDragOver();
    }
  }

  function pointerUp(event: PointerEvent) {
    window.removeEventListener('pointermove', pointerMove);

    const dragSource = source();
    const wasDragging = dragging;
    dragStart = null;
    dragElement = null;
    dragging = false;
    clearDragOver();
    dragPreview.set(null);

    if (!dragSource || !wasDragging) return;

    const element = document.elementFromPoint(event.clientX, event.clientY);
    const target = element?.closest<HTMLElement>('.inventory-slot');
    const targetInventory = target?.dataset.inventory;
    const targetSlot = Number(target?.dataset.slot);

    if (targetInventory && Number.isFinite(targetSlot) && targetSlot > 0) {
      void performDrop(dragSource, { inventory: targetInventory, item: { slot: targetSlot } });
      return;
    }

    void performDrop(dragSource);
  }

  function handleContext(event: MouseEvent) {
    event.preventDefault();
    if (inventory.type !== 'player' || !strictItem) return;

    const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
    const menuWidth = window.innerHeight * 0.14;
    const offset = window.innerHeight * 0.01;
    const spaceOnRight = window.innerWidth - rect.right;
    const align = spaceOnRight > menuWidth + window.innerHeight * 0.02 ? 'align-right' : 'align-left';
    const x = align === 'align-right' ? rect.right + offset : rect.left - menuWidth - offset;
    const y = rect.top + rect.height / 2 - window.innerHeight * 0.045;

    tooltip.set(null);
    contextMenu.set({ item: strictItem, x, y, align });
  }

  function handleClick(event: MouseEvent) {
    tooltip.set(null);
    if (!strictItem || dragging) {
      selectedSlot.set(null);
      selectedInventorySlot.set(null);
      return;
    }

    selectedSlot.set(strictItem);
    selectedInventorySlot.set({ inventory: inventory.type, slot: strictItem.slot });

    if (event.altKey && inventory.type === 'player') {
      useItem(strictItem);
    } else if (event.ctrlKey && inventory.type !== 'shop' && inventory.type !== 'crafting') {
      void performDrop({ inventory: inventory.type, item: { name: strictItem.name, slot: strictItem.slot } });
    }
  }

  function handleDoubleClick(event: MouseEvent) {
    event.preventDefault();
    const dragSource = source();
    if (dragSource) void performDrop(dragSource);
  }

  function handleKeyDown(event: KeyboardEvent) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleClick(event as unknown as MouseEvent);
    }
  }

  function showTooltip(event: MouseEvent) {
    if (!strictItem) return;
    if (tooltipTimer) window.clearTimeout(tooltipTimer);
    tooltipTimer = window.setTimeout(() => {
      tooltip.set({ item: strictItem as SlotWithItem, inventoryType: inventory.type, x: event.clientX, y: event.clientY });
    }, 420);
  }

  function hideTooltip() {
    if (tooltipTimer) window.clearTimeout(tooltipTimer);
    tooltip.set(null);
  }
</script>

<div
  class="inventory-slot slot"
  class:has-item={hasItem}
  class:hotbar-slot={isHotbar}
  class:item-active={isActivePlayerSlot}
  class:slot-disabled={slotDisabled}
  class:dragging
  class:selected={$selectedInventorySlot?.inventory === inventory.type && $selectedInventorySlot.slot === item.slot}
  data-inventory={inventory.type}
  data-slot={item.slot}
  role="button"
  tabindex="0"
  on:pointerdown={pointerDown}
  on:contextmenu={handleContext}
  on:click={handleClick}
  on:dblclick={handleDoubleClick}
  on:keydown={handleKeyDown}
  on:mouseenter={showTooltip}
  on:mouseleave={hideTooltip}
>
  {#if inventory.type === 'player' && item.slot <= 5 && isStacked}
    <div class="slot-hotkey-number">{item.slot}</div>
  {/if}

  {#if strictItem}
    {#if strictItem.metadata?.components?.length || strictItem.name.startsWith('WEAPON_')}
      <div class="slot-fav-dot"></div>
    {/if}

    <div class="slot-quantity">{formatCount(item.count)}</div>

    {#if inventory.type === 'shop' && item.price !== undefined}
      <div class="slot-price">{item.currency && item.currency !== 'money' ? item.currency : '$'}{item.price.toLocaleString('en-US')}</div>
    {/if}

    <div class="slot-image-wrapper">
      <img class="slot-image" src={image} alt={label} draggable="false" />
    </div>

    {#if item.durability !== undefined && inventory.type !== 'shop'}
      <WeightBar percent={item.durability} durability />
    {/if}

    <div class="slot-name">{label}</div>
  {/if}
</div>
