<script lang="ts">
  import { get } from 'svelte/store';
  import { isEnvBrowser } from '../lib/nui';
  import { addNotification, inventoryVisible, leftInventory, normalizeInventory, pinState, pushToast, rightInventory, weaponModal, configVisible } from '../stores/state';
  import type { Inventory } from '../types';

  const modes = [
    { type: 'drop', label: 'Suelo (Drops)' },
    { type: 'trunk', label: 'Maletero (Trunk)' },
    { type: 'glovebox', label: 'Guantera (Glovebox)' },
    { type: 'shop', label: 'Tienda (Shop)' },
    { type: 'stash', label: 'Almacen PIN (Stash)' },
    { type: 'crafting', label: 'Crafteo (Crafting)' },
  ];

  let active = 'drop';

  function rightData(type: string): Inventory {
    const base = {
      id: type,
      type,
      slots: type === 'glovebox' ? 5 : 25,
      weight: 12000,
      maxWeight: type === 'trunk' ? 80000 : type === 'glovebox' ? 8000 : type === 'stash' ? 120000 : 50000,
      label: 'SUELO',
      items: [],
    } satisfies Inventory;

    if (type === 'trunk') {
      return {
        ...base,
        id: 'trunk-LUCK65',
        label: 'MALETERO (DOMINATOR | LUCK65)',
        items: [
          { slot: 1, name: 'water', count: 12, weight: 4800 },
          { slot: 2, name: 'scrapmetal', count: 25, weight: 2500 },
          { slot: 6, name: 'WEAPON_SMG', count: 1, weight: 2500 },
        ],
      };
    }

    if (type === 'glovebox') {
      return {
        ...base,
        id: 'glovebox-LUCK65',
        label: 'GUANTERA (COPILOTO)',
        items: [
          { slot: 1, name: 'phone', count: 1, weight: 200 },
          { slot: 2, name: 'lockpick', count: 2, weight: 200 },
        ],
      };
    }

    if (type === 'shop') {
      return {
        ...base,
        id: 'shop-24-7',
        label: 'TIENDA / MERCADO',
        weight: 0,
        maxWeight: 0,
        items: [
          { slot: 1, name: 'water', count: 50, weight: 500, price: 10, currency: 'money' },
          { slot: 2, name: 'burger', count: 50, weight: 350, price: 20, currency: 'money' },
          { slot: 3, name: 'sprunk', count: 50, weight: 200, price: 15, currency: 'money' },
          { slot: 4, name: 'lockpick', count: 10, weight: 100, price: 80, currency: 'money' },
        ],
      };
    }

    if (type === 'stash') {
      return {
        ...base,
        id: 'police_armory',
        label: 'ALMACEN POLICIA',
        groups: { police: 2 },
        items: [
          { slot: 1, name: 'WEAPON_CARBINERIFLE', count: 1, weight: 3200, metadata: { ammo: 30 } },
          { slot: 2, name: 'ammo_rifle', count: 250, weight: 2500, metadata: { image: 'ammo-rifle' } },
          { slot: 3, name: 'bandage', count: 20, weight: 2000 },
        ],
      };
    }

    if (type === 'crafting') {
      return {
        ...base,
        id: 'crafting-bench',
        type: 'crafting',
        label: 'MESA DE CRAFTEO Y PROCESADO',
        slots: 3,
        items: [
          { slot: 1, name: 'lockpick', count: 1, weight: 100, duration: 3000, ingredients: { scrapmetal: 2 }, metadata: { description: 'Herramienta utilizada para abrir cerraduras simples.' } },
          { slot: 2, name: 'medikit', count: 1, weight: 400, duration: 5000, ingredients: { bandage: 2, scrapmetal: 1 }, metadata: { description: 'Kit medico avanzado para emergencias.' } },
          { slot: 3, name: 'WEAPON_KNIFE', count: 1, weight: 500, duration: 8000, ingredients: { scrapmetal: 10 }, metadata: { description: 'Arma blanca corta de combate.' } },
        ],
      };
    }

    return {
      ...base,
      id: 'drop-1',
      label: 'SUELO',
      items: [
        { slot: 1, name: 'water', count: 4, weight: 1600 },
        { slot: 2, name: 'WEAPON_KNIFE', count: 1, weight: 500 },
        { slot: 3, name: 'WEAPON_SMG', count: 1, weight: 2500 },
        { slot: 4, name: 'ammo_9', count: 200, weight: 1000, metadata: { image: 'ammo-9' } },
        { slot: 7, name: 'sprunk', count: 12, weight: 2400 },
        { slot: 8, name: 'burger', count: 5, weight: 1750 },
      ],
    };
  }

  function switchMode(type: string) {
    active = type;
    const left = get(leftInventory);
    const right = rightData(type);

    weaponModal.set(null);
    rightInventory.set(normalizeInventory(right));
    leftInventory.set(normalizeInventory(left));
    inventoryVisible.set(true);
    configVisible.set(false);

    if (type === 'stash') {
      pinState.set({ inventoryId: right.id, required: true, unlocked: false });
    } else {
      pinState.set(null);
    }
  }

  function openDebugConfig() {
    configVisible.set(true);
    inventoryVisible.set(true);
  }

  // ---- Notifications preview (our built-in toast system) ----
  function toast(type: 'success' | 'error' | 'inform') {
    const samples = {
      success: { title: 'Comprado', description: 'Has comprado 2x Agua' },
      error: { title: 'Sin espacio', description: 'No te cabe ese objeto' },
      inform: { title: 'Inventario', description: 'Pulsa TAB para la hotbar' },
    } as const;
    pushToast({ ...samples[type], type });
  }

  // ---- Item slide-in notifications ----
  function itemNotify(kind: 'ui_added' | 'ui_removed') {
    addNotification([{ slot: 1, name: 'water', count: 2, weight: 1000 }, kind, 2]);
  }

  // ---- Open the weapon modification modal directly ----
  function openWeaponModal() {
    inventoryVisible.set(true);
    weaponModal.set({
      item: { slot: 1, name: 'WEAPON_PISTOL', count: 1, weight: 1200, metadata: { ammo: 12, durability: 80, components: [] } },
      slot: 1,
    });
  }
</script>

{#if isEnvBrowser()}
  <div id="debug-view-selector" class="debug-view-selector">
    <h3>CONTROLES DE PRUEBA</h3>
    <div class="debug-btn-group">
      {#each modes as mode}
        <button class="debug-switch-btn" class:active={active === mode.type} type="button" on:click={() => switchMode(mode.type)}>
          {mode.label}
        </button>
      {/each}
      <button class="debug-switch-btn" class:active={$configVisible} type="button" on:click={openDebugConfig}>
        Configurar Tema
      </button>
      <button class="debug-switch-btn" type="button" on:click={openWeaponModal}>
        Modal de Arma
      </button>
    </div>

    <h3>NOTIFICACIONES</h3>
    <div class="debug-btn-group">
      <button class="debug-switch-btn" type="button" on:click={() => toast('success')}>Toast Éxito</button>
      <button class="debug-switch-btn" type="button" on:click={() => toast('error')}>Toast Error</button>
      <button class="debug-switch-btn" type="button" on:click={() => toast('inform')}>Toast Info</button>
      <button class="debug-switch-btn" type="button" on:click={() => itemNotify('ui_added')}>Item +</button>
      <button class="debug-switch-btn" type="button" on:click={() => itemNotify('ui_removed')}>Item −</button>
    </div>

    <div class="debug-instructions">
      <p>Usa click derecho en un arma para probar <strong>Accesorios de Armas</strong>.</p>
      <p>Pulsa <strong>Tab</strong> para ver el <strong>HUD Hotbar</strong>.</p>
    </div>
  </div>
{/if}
