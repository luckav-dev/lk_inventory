<script lang="ts">
  import DOMPurify from 'dompurify';
  import { marked } from 'marked';
  import { formatWeight } from '../lib/format';
  import { additionalMetadata, getItemLabel, getItemUrl, items, tooltip } from '../stores/state';
  import { t } from '../lib/i18n';

  $: tip = $tooltip;
  $: item = tip?.item;
  $: itemData = item?.name ? $items[item.name] : undefined;
  $: description = item?.metadata?.description || itemData?.description || '';
  $: descriptionHtml = description ? DOMPurify.sanitize(marked.parse(description) as string) : '';
  $: ingredients = item?.ingredients ? Object.entries(item.ingredients).sort((a, b) => a[1] - b[1]) : [];
  $: componentLabels = item?.metadata?.components
    ? item.metadata.components.map((component: string) => $items[component]?.label || component).join(', ')
    : '';
</script>

{#if tip && item}
  <div class="inventory-tooltip" style={`left: ${tip.x + 14}px; top: ${tip.y + 14}px;`}>
    <div class="tooltip-title-row">
      <span class="tooltip-title">{getItemLabel(item)}</span>
      {#if tip.inventoryType === 'crafting'}
        <span class="tooltip-chip">{((item.duration ?? 3000) / 1000).toFixed(1)}S</span>
      {:else if item.metadata?.type}
        <span class="tooltip-chip">{item.metadata.type}</span>
      {/if}
    </div>

    {#if descriptionHtml}
      <div class="tooltip-desc">{@html descriptionHtml}</div>
    {/if}

    <div class="tooltip-meta">
      {#if item.weight}
        <p>{$t('ui_weight', 'Weight')}: {formatWeight(item.weight)}</p>
      {/if}
      {#if item.durability !== undefined}
        <p>{$t('ui_durability', 'Durability')}: {Math.trunc(item.durability)}%</p>
      {/if}
      {#if item.metadata?.ammo !== undefined}
        <p>{$t('ui_ammo', 'Ammo')}: {item.metadata.ammo}</p>
      {/if}
      {#if itemData?.ammoName && $items[itemData.ammoName]}
        <p>{$t('ui_type', 'Type')}: {$items[itemData.ammoName]?.label}</p>
      {/if}
      {#if item.metadata?.serial}
        <p>{$t('ui_serial', 'Serial number')}: {item.metadata.serial}</p>
      {/if}
      {#if item.metadata?.components?.length}
        <p>{$t('ui_components', 'Components')}: {componentLabels}</p>
      {/if}
      {#each $additionalMetadata as meta}
        {#if item.metadata?.[meta.metadata]}
          <p>{meta.value}: {item.metadata[meta.metadata]}</p>
        {/if}
      {/each}
    </div>

    {#if tip.inventoryType === 'crafting' && ingredients.length}
      <div class="tooltip-ingredients">
        {#each ingredients as [name, count]}
          <div class="tooltip-ingredient">
            <img src={getItemUrl(name)} alt="" />
            <span>{count >= 1 ? `${count}x` : count === 0 ? '' : `${count * 100}%`} {$items[name]?.label || name}</span>
          </div>
        {/each}
      </div>
    {/if}
  </div>
{/if}
