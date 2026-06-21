<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { SvelteUIProvider } from '@svelteuidev/core';
  import ActionPanel from './components/ActionPanel.svelte';
  import ContextMenu from './components/ContextMenu.svelte';
  import CraftingPanel from './components/CraftingPanel.svelte';
  import DebugSelector from './components/DebugSelector.svelte';
  import DragPreview from './components/DragPreview.svelte';
  import HotbarHud from './components/HotbarHud.svelte';
  import InventoryGrid from './components/InventoryGrid.svelte';
  import Notifications from './components/Notifications.svelte';
  import PinOverlay from './components/PinOverlay.svelte';
  import Tooltip from './components/Tooltip.svelte';
  import WeaponModal from './components/WeaponModal.svelte';
  import ConfigPanel from './components/ConfigPanel.svelte';
  import Toasts from './components/Toasts.svelte';
  import AuditPanel from './components/AuditPanel.svelte';
  import { fetchNui, isEnvBrowser } from './lib/nui';
  import { applyThemeColor } from './lib/theme';
  import { playSound } from './lib/audio';
  import {
    activePlayerSlot,
    addNotification,
    closeFloatingUi,
    configVisible,
    hotbarVisible,
    initInventory,
    inventoryVisible,
    leftInventory,
    mergeAdditionalMetadata,
    auditEntries,
    auditVisible,
    pinState,
    pushToast,
    refreshSlots,
    rightInventory,
    setupInventories,
    shiftPressed,
    showHotbar,
    weaponModal,
    inventoryLayout,
  } from './stores/state';
  import type { Inventory, ItemData, NuiMessage, RefreshPayload, Slot } from './types';

  type InitPayload = {
    locale?: Record<string, string>;
    items?: Record<string, ItemData>;
    leftInventory?: Inventory;
    imagepath?: string;
  };

  async function syncPinState() {
    const right = $rightInventory;

    if (right.type !== 'stash' && right.type !== 'temp') {
      pinState.set(null);
      return;
    }

    const response = await fetchNui<boolean | { required?: boolean; unlocked?: boolean }>('lk_inventory:checkStashPin', {
      stash: right.id,
    }).catch(() => ({ required: false, unlocked: true }));

    if (typeof response === 'boolean') {
      pinState.set({ inventoryId: right.id, required: response, unlocked: !response });
    } else {
      pinState.set({
        inventoryId: right.id,
        required: response.required === true,
        unlocked: response.unlocked === true || response.required !== true,
      });
    }
  }

  function handleMessage(event: MessageEvent<NuiMessage>) {
    const { action, data } = event.data || {};

    switch (action) {
      case 'init':
        initInventory(data as InitPayload);
        break;
      case 'setupInventory':
        setupInventories(data as { leftInventory?: Inventory; rightInventory?: Inventory });
        inventoryVisible.set(true);
        closeFloatingUi();
        void syncPinState();
        break;
      case 'refreshSlots':
        refreshSlots(data as RefreshPayload);
        break;
      case 'displayMetadata':
        mergeAdditionalMetadata(data as Array<{ metadata: string; value: string }>);
        break;
      case 'itemNotify':
        addNotification(data as [Slot, string, number?]);
        break;
      case 'notify':
        pushToast(data as { title?: string; description: string; type?: string });
        break;
      case 'playSound':
        playSound((data as { name: string })?.name);
        break;
      case 'openAudit':
        auditEntries.set((data as { entries?: unknown[] })?.entries as never[] || []);
        auditVisible.set(true);
        break;
      case 'toggleHotbar':
        if (typeof data === 'number') activePlayerSlot.set(data);
        showHotbar();
        break;
      case 'setCurrentWeapon':
      case 'setActiveHotbarSlot':
        activePlayerSlot.set(typeof data === 'number' && data > 0 ? data : null);
        break;
      case 'setInventoryVisible':
        inventoryVisible.set(Boolean(data));
        break;
      case 'closeInventory':
        inventoryVisible.set(false);
        closeFloatingUi();
        weaponModal.set(null);
        configVisible.set(false);
        break;
      case 'openConfig':
        configVisible.set(true);
        inventoryVisible.set(true);
        break;
    }
  }

  function closeInventory() {
    if ($weaponModal) {
      weaponModal.set(null);
      return;
    }

    if ($configVisible) {
      configVisible.set(false);
      inventoryVisible.set(false);
      closeFloatingUi();
      void fetchNui('closeConfig');
      return;
    }

    inventoryVisible.set(false);
    closeFloatingUi();
    void fetchNui('exit');
  }

  function keyDown(event: KeyboardEvent) {
    if (event.key === 'Shift') shiftPressed.set(true);

    // The audit panel handles its own Escape; don't also fire the inventory exit.
    if ((event.key === 'Escape' || event.key === 'Backspace') && document.activeElement?.tagName !== 'INPUT' && !$auditVisible) {
      event.preventDefault();
      closeInventory();
    }

    if (isEnvBrowser() && event.key === 'Tab') {
      event.preventDefault();
      showHotbar();
    }
  }

  function keyUp(event: KeyboardEvent) {
    if (event.key === 'Shift') shiftPressed.set(false);
  }

  function dispatchDebugData() {
    const itemData: Record<string, ItemData> = {
      WEAPON_PISTOL: { name: 'WEAPON_PISTOL', label: 'Pistola', stack: false, usable: true, close: true, count: 1, weapon: true },
      WEAPON_CARBINERIFLE: { name: 'WEAPON_CARBINERIFLE', label: 'Carabina', stack: false, usable: true, close: true, count: 1, weapon: true },
      WEAPON_SMG: { name: 'WEAPON_SMG', label: 'Subfusil', stack: false, usable: true, close: true, count: 1, weapon: true },
      WEAPON_KNIFE: { name: 'WEAPON_KNIFE', label: 'Cuchillo', stack: false, usable: true, close: true, count: 1, weapon: true },
      WEAPON_GRENADE: { name: 'WEAPON_GRENADE', label: 'Granada', stack: true, usable: true, close: true, count: 1, weapon: true },
      at_suppressor: { name: 'at_suppressor', label: 'Silenciador', stack: true, usable: true, close: true, count: 1, component: true, type: 'muzzle' },
      at_flashlight: { name: 'at_flashlight', label: 'Linterna', stack: true, usable: true, close: true, count: 1, component: true, type: 'flashlight' },
      at_scope_holo: { name: 'at_scope_holo', label: 'Mira Red Dot', stack: true, usable: true, close: true, count: 1, component: true, type: 'optic' },
      ammo_rifle: { name: 'ammo_rifle', label: 'M. Fusil', stack: true, usable: true, close: true, count: 150, ammo: true },
      ammo_9: { name: 'ammo_9', label: 'M. 9mm', stack: true, usable: true, close: true, count: 200, ammo: true },
      water: { name: 'water', label: 'Agua', stack: true, usable: true, close: false, count: 8 },
      sprunk: { name: 'sprunk', label: 'Sprunk', stack: true, usable: true, close: false, count: 5 },
      burger: { name: 'burger', label: 'Hamburguesa', stack: true, usable: true, close: false, count: 2 },
      bandage: { name: 'bandage', label: 'Vendas', stack: true, usable: true, close: false, count: 5 },
      medikit: { name: 'medikit', label: 'Botiquin', stack: true, usable: true, close: false, count: 2 },
      lockpick: { name: 'lockpick', label: 'Ganzua', stack: true, usable: true, close: true, count: 2 },
      phone: { name: 'phone', label: 'Telefono', stack: false, usable: true, close: true, count: 1 },
      radio: { name: 'radio', label: 'Radio', stack: false, usable: true, close: true, count: 1 },
      scrapmetal: { name: 'scrapmetal', label: 'Chatarra', stack: true, usable: false, close: false, count: 18 },
      carkey: { name: 'carkey', label: 'Llave', stack: false, usable: true, close: true, count: 1 },
      weed: { name: 'weed', label: 'Marihuana', stack: true, usable: false, close: false, count: 8 },
      black_money: { name: 'black_money', label: 'Dinero Negro', stack: true, usable: false, close: false, count: 12500 },
      card_id: { name: 'card_id', label: 'DNI', stack: false, usable: true, close: true, count: 1 },
      card_bank: { name: 'card_bank', label: 'Tarjeta', stack: false, usable: true, close: true, count: 1 },
      money: { name: 'money', label: 'Dinero', stack: true, usable: false, close: false, count: 2000 },
    };

    const debugLeft: Inventory = {
      id: 65,
      type: 'player',
      slots: 50,
      weight: 17400,
      maxWeight: 50000,
      label: 'Luckav',
      items: [
        { slot: 1, name: 'WEAPON_PISTOL', count: 1, weight: 1200, metadata: { ammo: 12, serial: 'LK-65-001', components: ['at_suppressor'] } },
        { slot: 2, name: 'sprunk', count: 5, weight: 1000 },
        { slot: 3, name: 'phone', count: 1, weight: 200 },
        { slot: 4, name: 'burger', count: 2, weight: 700 },
        { slot: 5, name: 'radio', count: 1, weight: 350 },
        { slot: 6, name: 'WEAPON_CARBINERIFLE', count: 1, weight: 3200, metadata: { ammo: 30, components: ['at_flashlight'] } },
        { slot: 7, name: 'ammo_rifle', count: 150, weight: 1500, metadata: { image: 'ammo-rifle' } },
        { slot: 8, name: 'bandage', count: 10, weight: 1000 },
        { slot: 9, name: 'medikit', count: 2, weight: 800 },
        { slot: 10, name: 'at_suppressor', count: 1, weight: 100 },
        { slot: 11, name: 'at_scope_holo', count: 1, weight: 100 },
        { slot: 12, name: 'lockpick', count: 4, weight: 400 },
        { slot: 13, name: 'money', count: 5000, weight: 0 },
        { slot: 14, name: 'card_id', count: 1, weight: 0 },
        { slot: 15, name: 'card_bank', count: 1, weight: 0 },
        { slot: 16, name: 'at_flashlight', count: 1, weight: 100 },
        { slot: 18, name: 'WEAPON_GRENADE', count: 3, weight: 900 },
        { slot: 21, name: 'scrapmetal', count: 18, weight: 1800 },
        { slot: 22, name: 'carkey', count: 1, weight: 50 },
        { slot: 23, name: 'weed', count: 8, weight: 800 },
        { slot: 35, name: 'weed', count: 10, weight: 1000 },
        { slot: 42, name: 'burger', count: 3, weight: 1050 },
        { slot: 48, name: 'water', count: 6, weight: 2400 },
      ],
    };

    const debugRight: Inventory = {
      id: 'drop-1',
      type: 'drop',
      slots: 40,
      weight: 15000,
      maxWeight: 50000,
      label: 'SUELO',
      items: [
        { slot: 1, name: 'water', count: 4, weight: 1600 },
        { slot: 2, name: 'WEAPON_KNIFE', count: 1, weight: 500 },
        { slot: 3, name: 'WEAPON_SMG', count: 1, weight: 2500 },
        { slot: 4, name: 'ammo_9', count: 200, weight: 1000, metadata: { image: 'ammo-9' } },
        { slot: 7, name: 'sprunk', count: 12, weight: 2400 },
        { slot: 8, name: 'burger', count: 5, weight: 1750 },
        { slot: 11, name: 'black_money', count: 12500, weight: 0 },
        { slot: 16, name: 'weed', count: 15, weight: 1500 },
        { slot: 28, name: 'water', count: 2, weight: 800 },
        { slot: 35, name: 'burger', count: 4, weight: 1400 },
      ],
    };

    window.dispatchEvent(
      new MessageEvent('message', {
        data: {
          action: 'init',
          data: {
            locale: {},
            items: itemData,
            imagepath: '/images',
            leftInventory: debugLeft,
          },
        },
      })
    );

    window.dispatchEvent(
      new MessageEvent('message', {
        data: {
          action: 'setupInventory',
          data: {
            leftInventory: debugLeft,
            rightInventory: debugRight,
          },
        },
      })
    );
  }

  onMount(() => {
    if (isEnvBrowser()) document.body.classList.add('is-browser');

    const savedColor = localStorage.getItem('inventory-accent') || '#e42a2d';
    applyThemeColor(savedColor);

    window.addEventListener('message', handleMessage as EventListener);
    window.addEventListener('keydown', keyDown);
    window.addEventListener('keyup', keyUp);
    void fetchNui('uiLoaded', {});

    if (isEnvBrowser()) window.setTimeout(dispatchDebugData, 250);
  });

  onDestroy(() => {
    if (isEnvBrowser()) document.body.classList.remove('is-browser');
    window.removeEventListener('message', handleMessage as EventListener);
    window.removeEventListener('keydown', keyDown);
    window.removeEventListener('keyup', keyUp);
  });
</script>

<SvelteUIProvider>
  <main id="inventory-container" class:active={$inventoryVisible} class:hotbar-active={$hotbarVisible && !$inventoryVisible} class:layout-stacked-right={$inventoryLayout === 'stacked-right'}>
    <div class="bg-blur-container" aria-hidden="true"></div>
    <div class="dark-overlay" aria-hidden="true"></div>

    <svg viewBox="0 0 200 200" class="screen-accent top-right" aria-hidden="true">
      <path d="M 50,0 L 150,100 L 200,100" fill="none" stroke="var(--primary-red)" stroke-width="1.5" opacity="0.4" />
      <path d="M 100,0 L 170,70 L 200,70" fill="none" stroke="var(--primary-red)" stroke-width="2.5" />
    </svg>
    <svg viewBox="0 0 200 200" class="screen-accent bottom-left" aria-hidden="true">
      <path d="M 150,200 L 50,100 L 0,100" fill="none" stroke="var(--primary-red)" stroke-width="1.5" opacity="0.4" />
      <path d="M 100,200 L 30,130 L 0,130" fill="none" stroke="var(--primary-red)" stroke-width="2.5" />
    </svg>

    {#if $inventoryVisible}
      {#if $configVisible}
        <ConfigPanel />
      {:else if $rightInventory.type === 'crafting'}
        <CraftingPanel />
      {:else}
        <div class="nui-design-inventrio" class:layout-stacked-right={$inventoryLayout === 'stacked-right'} class:security-locked={$pinState?.required && !$pinState.unlocked}>
          <InventoryGrid inventory={$leftInventory} side="left" />
          <ActionPanel />
          <InventoryGrid inventory={$rightInventory} side="right" />
        </div>
      {/if}
    {/if}

    <PinOverlay />
    <WeaponModal />
    <ContextMenu />
    <Tooltip />
    <DragPreview />
    <HotbarHud />
    <Notifications />
    <DebugSelector />
  </main>

  <!-- Always-visible notification toasts (shown even when the inventory is closed). -->
  <Toasts />
  <AuditPanel />
</SvelteUIProvider>
