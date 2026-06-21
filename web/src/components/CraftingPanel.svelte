<script lang="ts">
  import { onDestroy } from 'svelte';
  import { performCraft } from '../lib/actions';
  import { fetchNui } from '../lib/nui';
  import { getItemLabel, getItemUrl, inventoryVisible, isSlotWithItem, items, leftInventory, rightInventory } from '../stores/state';
  import { t } from '../lib/i18n';
  import type { SlotWithItem } from '../types';
  import backpackIcon from '../../assets/Icon2@2x.png';

  let selected: SlotWithItem | undefined;
  let crafting = false;
  let progress = 0;
  let progressTimer: number | undefined;

  $: recipes = $rightInventory.items.filter((slot): slot is SlotWithItem => isSlotWithItem(slot, true));
  $: selected = selected && recipes.find((recipe) => recipe.slot === selected?.slot) ? selected : recipes[0];
  $: ingredients = selected?.ingredients ? Object.entries(selected.ingredients) : [];
  $: canCraft = selected ? ingredients.every(([name, count]) => count < 1 || (($items[name]?.count || 0) >= count)) : false;

  function formatDuration(duration = 3000) {
    return `${(duration / 1000).toFixed(1)}s`;
  }

  function stopProgress() {
    if (progressTimer) window.clearInterval(progressTimer);
    progressTimer = undefined;
    crafting = false;
  }

  async function craft() {
    if (!selected || crafting) return;
    const target = $leftInventory.items.find((slot) => !slot.name) || $leftInventory.items[0];
    if (!target) return;

    const duration = selected.duration ?? 3000;
    const started = Date.now();
    progress = 0;
    crafting = true;

    progressTimer = window.setInterval(() => {
      progress = Math.min(100, ((Date.now() - started) / duration) * 100);
      if (progress >= 100 && progressTimer) window.clearInterval(progressTimer);
    }, 100);

    try {
      await performCraft({ inventory: $rightInventory.type, item: { name: selected.name, slot: selected.slot } }, { inventory: 'player', item: { slot: target.slot } });
      progress = 100;
    } finally {
      window.setTimeout(() => {
        stopProgress();
        progress = 0;
      }, 350);
    }
  }

  function closeCrafting() {
    inventoryVisible.set(false);
    void fetchNui('exit');
  }

  onDestroy(stopProgress);
</script>

{#if $rightInventory.type === 'crafting'}
  <section class="crafting-panel-standalone">
    <div class="crafting-standalone-header">
      <div class="crafting-header-title">
          <span class="crafting-backpack-icon" style="-webkit-mask-image: url({backpackIcon}); mask-image: url({backpackIcon});"></span>
        <div class="crafting-header-text">
          <h2>{$rightInventory.label || $t('ui_crafting_title', 'Crafting & Processing Bench')}</h2>
          <span>{$t('ui_crafting_subtitle', 'Create and assemble new items with your materials')}</span>
        </div>
      </div>
      <button class="close-crafting-btn" type="button" on:click={closeCrafting}>X</button>
    </div>

    <div class="crafting-standalone-body">
      <div class="crafting-standalone-left">
        <span class="section-title">{$t('ui_available_recipes', 'Available Recipes')}</span>
        <div class="recipe-list">
          {#each recipes as recipe}
            <button class="recipe-item" class:active={selected?.slot === recipe.slot} type="button" on:click={() => (selected = recipe)}>
              <img src={getItemUrl(recipe)} alt="" />
              <div>
                <span class="recipe-item-name">{getItemLabel(recipe)}</span>
                <span class="recipe-item-time">{formatDuration(recipe.duration)}</span>
              </div>
            </button>
          {/each}
        </div>
      </div>

      <div class="crafting-standalone-right">
        {#if selected}
          <div class="recipe-card-preview">
            <div class="recipe-card-title-row">
              <h3>{getItemLabel(selected)}</h3>
              <span class="recipe-time-badge">{formatDuration(selected.duration)}</span>
            </div>
            <p>{selected.metadata?.description || $items[selected.name]?.description || $t('ui_recipe_available', 'Recipe available to craft.')}</p>
          </div>

          <div class="materials-section">
            <span class="section-title">{$t('ui_required_materials', 'Required Materials')}</span>
            <div class="materials-list">
              {#each ingredients as [name, count]}
                <div class="material-row">
                  <div class="material-info">
                    <img src={getItemUrl(name)} alt="" />
                    <span class="material-name">{$items[name]?.label || name}</span>
                  </div>
                  <div class="material-status">
                    <span class:insufficient={($items[name]?.count || 0) < count} class:sufficient={($items[name]?.count || 0) >= count} class="material-qty">
                      {$items[name]?.count || 0}/{count}
                    </span>
                    <div class="status-icon" class:check={($items[name]?.count || 0) >= count} class:cross={($items[name]?.count || 0) < count}>
                      {($items[name]?.count || 0) >= count ? '✓' : '×'}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <div class="crafting-action-area">
            <div class="crafting-progress-wrapper" style={`opacity: ${crafting ? 1 : 0};`}>
              <div class="crafting-progress-bar">
                <div class="crafting-progress-fill" style={`width: ${progress}%;`}></div>
              </div>
              <span id="crafting-progress-text">{$t('ui_crafting_progress', 'Crafting...')} {Math.floor(progress)}%</span>
            </div>
            <button class="craft-btn" type="button" disabled={!canCraft || crafting} on:click={craft}>{$t('ui_start_assembly', 'Start Assembly').toUpperCase()}</button>
          </div>
        {/if}
      </div>
    </div>
  </section>
{/if}
