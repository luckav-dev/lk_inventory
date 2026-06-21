<script lang="ts">
  import { removeComponent, useItem } from '../lib/actions';
  import { getItemLabel, getItemUrl, isSlotWithItem, items, leftInventory, weaponModal } from '../stores/state';
  import { t } from '../lib/i18n';

  $: modal = $weaponModal;
  $: components = (modal?.item.metadata?.components || []) as string[];
  $: availableComponents = $leftInventory.items.filter((slot) => isSlotWithItem(slot, true) && $items[slot.name]?.component);

  $: socketRows = [
    { key: 'optic', label: `${$t('ui_socket_optic', 'Optic')} (OPTIC)`, column: 'left' },
    { key: 'muzzle', label: `${$t('ui_socket_muzzle', 'Muzzle')} (MUZZLE)`, column: 'left' },
    { key: 'flashlight', label: `${$t('ui_socket_flashlight', 'Flashlight')} (FLASHLIGHT)`, column: 'right' },
    { key: 'magazine', label: `${$t('ui_socket_magazine', 'Magazine')} (CLIP)`, column: 'right' },
  ];

  function componentSocket(component: string) {
    const data = $items[component];
    const raw = `${data?.type || ''} ${data?.client?.component?.join(' ') || ''} ${component}`.toLowerCase();

    if (raw.includes('scope') || raw.includes('optic') || raw.includes('sight')) return 'optic';
    if (raw.includes('suppressor') || raw.includes('muzzle') || raw.includes('barrel')) return 'muzzle';
    if (raw.includes('flashlight') || raw.includes('flash')) return 'flashlight';
    if (raw.includes('clip') || raw.includes('magazine') || raw.includes('extended') || raw.includes('drum')) return 'magazine';
    return 'muzzle';
  }

  function buildInstalledBySocket(list: string[]) {
    const result: Record<string, string> = {};
    for (const component of list) result[componentSocket(component)] = component;
    return result;
  }

  $: installedBySocket = buildInstalledBySocket(components);

  function socketItem(key: string) {
    return installedBySocket[key];
  }
</script>

{#if modal}
  <div class="weapon-modification-overlay">
    <div class="weapon-mod-container">
      <div class="weapon-mod-header">
        <div class="header-title-group">
          <h3>{$t('ui_weapon_modification', 'Weapon Modification').toUpperCase()}</h3>
          <span class="weapon-mod-sub">{getItemLabel(modal.item)}</span>
        </div>
        <button class="close-mod-btn" type="button" on:click={() => weaponModal.set(null)}>X</button>
      </div>

      <div class="weapon-mod-content-tactical">
        <div class="weapon-mod-column sockets-column">
          <span class="column-title">{$t('ui_top_sockets', 'Top Sockets').toUpperCase()}</span>
          <div class="socket-stack">
            {#each socketRows.filter((row) => row.column === 'left') as row}
              {@const component = socketItem(row.key)}
              <div class="socket-slot" data-socket={row.key}>
                <div class="socket-header-row">
                  <span class="socket-label">{row.label}</span>
                  <span class="socket-status-dot" class:filled={!!component} class:empty={!component}></span>
                </div>
                {#if component}
                  <button class="socket-item has-attachment" type="button" on:click={() => removeComponent(modal.item, component)}>
                    <img class="slot-image" src={getItemUrl(component)} alt="" />
                    <span class="slot-name">{$items[component]?.label || component}</span>
                  </button>
                {:else}
                  <div class="socket-item empty"><span class="empty-socket-placeholder">{$t('ui_empty_socket', 'Empty Socket').toUpperCase()}</span></div>
                {/if}
              </div>
            {/each}
          </div>
        </div>

        <div class="weapon-mod-column preview-column">
          <div class="tactical-scanner-frame">
            <div class="radar-circle"></div>
            <div class="radar-scan-line"></div>
            <div class="crosshair-marker"></div>
            <img src={getItemUrl(modal.item)} alt={getItemLabel(modal.item)} />
          </div>
        </div>

        <div class="weapon-mod-column stats-column">
          <span class="column-title">{$t('ui_extra_attachments', 'Extra Attachments').toUpperCase()}</span>
          <div class="socket-stack">
            {#each socketRows.filter((row) => row.column === 'right') as row}
              {@const component = socketItem(row.key)}
              <div class="socket-slot" data-socket={row.key}>
                <div class="socket-header-row">
                  <span class="socket-label">{row.label}</span>
                  <span class="socket-status-dot" class:filled={!!component} class:empty={!component}></span>
                </div>
                {#if component}
                  <button class="socket-item has-attachment" type="button" on:click={() => removeComponent(modal.item, component)}>
                    <img class="slot-image" src={getItemUrl(component)} alt="" />
                    <span class="slot-name">{$items[component]?.label || component}</span>
                  </button>
                {:else}
                  <div class="socket-item empty"><span class="empty-socket-placeholder">{$t('ui_empty_socket', 'Empty Socket').toUpperCase()}</span></div>
                {/if}
              </div>
            {/each}
          </div>

          {#if availableComponents.length}
            <div class="inventory-components-panel">
              <span class="column-title inventory-components-title">{$t('ui_in_inventory', 'In Inventory').toUpperCase()}</span>
              <div class="inventory-components-list">
                {#each availableComponents as component}
                  {#if isSlotWithItem(component, true)}
                    <button class="socket-item inventory-component" type="button" on:click={() => useItem(component)}>
                      <img class="slot-image" src={getItemUrl(component)} alt="" />
                      <span class="slot-name">{getItemLabel(component)}</span>
                    </button>
                  {/if}
                {/each}
              </div>
            </div>
          {/if}
        </div>
      </div>

      <div class="weapon-mod-footer">
        <p>{$t('ui_weapon_mod_hint', 'Use a compatible attachment to install it. Click a socket to unequip.')}</p>
      </div>
    </div>
  </div>
{/if}
