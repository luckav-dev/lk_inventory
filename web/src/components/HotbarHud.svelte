<script lang="ts">
  import { formatCount } from '../lib/format';
  import { activePlayerSlot, getItemLabel, getItemUrl, hotbarVisible, isSlotWithItem, leftInventory } from '../stores/state';
</script>

{#if $hotbarVisible}
  <div class="hud-hotbar-container">
    {#each $leftInventory.items.slice(0, 5) as item (item.slot)}
      <div class="hud-hotbar-slot" class:has-item={isSlotWithItem(item)} class:item-active={$activePlayerSlot === item.slot && isSlotWithItem(item)}>
        <span class="hud-hotbar-key">{item.slot}</span>
        {#if isSlotWithItem(item)}
          <span class="hud-hotbar-qty">{formatCount(item.count)}</span>
          <div class="hud-hotbar-img-wrapper">
            <img class="hud-hotbar-img" src={getItemUrl(item)} alt={getItemLabel(item)} />
          </div>
          <div class="hud-hotbar-name">{getItemLabel(item)}</div>
        {/if}
      </div>
    {/each}
  </div>
{/if}
