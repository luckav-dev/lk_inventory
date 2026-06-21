<script lang="ts">
  import { getItemLabel, getItemUrl, isSlotWithItem, notifications } from '../stores/state';
  import { t } from '../lib/i18n';

  function kindLabel(kind: string): string {
    if (kind === 'ui_removed') return $t('ui_removed', 'Removed');
    if (kind === 'error') return $t('ui_rejected', 'Rejected');
    return $t('ui_added', 'Added');
  }

  function hideBrokenImage(event: Event) {
    (event.currentTarget as HTMLImageElement).style.display = 'none';
  }

  function title(item: typeof $notifications[number]['item']): string {
    return item?.metadata?.label || getItemLabel(item) || $t('ui_inventory', 'Inventory');
  }
</script>

<div class="notifications">
  {#each $notifications as notification (notification.id)}
    <div class={`notification ${notification.kind}`}>
      {#if isSlotWithItem(notification.item)}
        <img src={getItemUrl(notification.item)} alt="" on:error={hideBrokenImage} />
      {/if}
      <div>
        <strong>{title(notification.item)}</strong>
        <span>{notification.count ? `${notification.count}x ` : ''}{kindLabel(notification.kind)}</span>
      </div>
    </div>
  {/each}
</div>
