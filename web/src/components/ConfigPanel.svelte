<script lang="ts">
  import { configVisible, inventoryVisible, inventoryLayout } from '../stores/state';
  import { fetchNui } from '../lib/nui';
  import { applyThemeColor } from '../lib/theme';
  import { t } from '../lib/i18n';

  $: presets = [
    { name: `${$t('ui_color_red', 'Red')} (${$t('ui_default', 'Default')})`, color: '#e42a2d' },
    { name: $t('ui_color_orange', 'Orange'), color: '#ea580c' },
    { name: $t('ui_color_yellow', 'Yellow'), color: '#eab308' },
    { name: $t('ui_color_green', 'Green'), color: '#16a34a' },
    { name: $t('ui_color_cyan', 'Cyan'), color: '#0891b2' },
    { name: $t('ui_color_blue', 'Blue'), color: '#2563eb' },
    { name: $t('ui_color_purple', 'Purple'), color: '#7c3aed' },
    { name: $t('ui_color_pink', 'Pink'), color: '#db2777' },
  ];

  let selectedColor = localStorage.getItem('inventory-accent') || '#e42a2d';
  let selectedLayout = $inventoryLayout;

  function selectColor(color: string) {
    selectedColor = color;
    applyThemeColor(color);
  }

  function selectLayout(layout: 'classic' | 'stacked-right') {
    selectedLayout = layout;
    inventoryLayout.set(layout);
  }

  function saveAndClose() {
    localStorage.setItem('inventory-accent', selectedColor);
    localStorage.setItem('inventory-layout', selectedLayout);
    configVisible.set(false);
    inventoryVisible.set(false);
    void fetchNui('closeConfig');
  }
</script>

<div class="config-modal-backdrop">
  <div class="config-modal-container">
    <div class="config-modal-header">
      <h2>{$t('ui_theme_config', 'Theme Configuration')}</h2>
      <p>{$t('ui_theme_subtitle', 'Customize your interface accent color')}</p>
    </div>

    <div class="config-modal-body">
      <div class="color-section">
        <h3>{$t('ui_preset_colors', 'Preset Colors')}</h3>
        <div class="color-presets-grid">
          {#each presets as preset}
            <button
              class="preset-btn"
              class:active={selectedColor.toLowerCase() === preset.color.toLowerCase()}
              style:background-color={preset.color}
              type="button"
              on:click={() => selectColor(preset.color)}
              aria-label={preset.name}
            >
              {#if selectedColor.toLowerCase() === preset.color.toLowerCase()}
                <span class="check-mark">✓</span>
              {/if}
            </button>
          {/each}
        </div>
      </div>

      <div class="custom-color-section">
        <h3>{$t('ui_custom_color', 'Custom Color')}</h3>
        <div class="custom-color-input-wrapper">
          <input
            type="color"
            id="custom-color-picker"
            value={selectedColor}
            on:input={(e) => selectColor(e.currentTarget.value)}
          />
          <input
            type="text"
            class="hex-text-input"
            value={selectedColor.toUpperCase()}
            on:input={(e) => selectColor(e.currentTarget.value)}
            maxlength="7"
          />
        </div>
      </div>

      <div class="layout-section">
        <h3>{$t('ui_layout', 'Interface Layout')}</h3>
        <div class="layout-options">
          <button
            class="layout-option-btn"
            class:active={selectedLayout === 'classic'}
            type="button"
            on:click={() => selectLayout('classic')}
          >
            {$t('ui_layout_classic', 'Classic').toUpperCase()}
          </button>
          <button
            class="layout-option-btn"
            class:active={selectedLayout === 'stacked-right'}
            type="button"
            on:click={() => selectLayout('stacked-right')}
          >
            {$t('ui_layout_compact', 'Compact').toUpperCase()}
          </button>
        </div>
      </div>
    </div>

    <div class="config-modal-footer">
      <button class="save-btn" type="button" on:click={saveAndClose}>
        {$t('ui_save_close', 'Save & Close')}
      </button>
    </div>
  </div>
</div>
