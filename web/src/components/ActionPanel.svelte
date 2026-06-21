<script lang="ts">
  import { get } from 'svelte/store';
  import { giveItem, performBuy, useItem } from '../lib/actions';
  import { formatAmount, parseAmount } from '../lib/format';
  import { contextMenu, itemAmount, leftInventory, rightInventory, selectedSlot } from '../stores/state';
  import { t } from '../lib/i18n';
  import { InventoryType } from '../types';
  import giveIcon from '../../assets/Enviar@2x.png';
  import useIcon from '../../assets/Usar@2x.png';

  let inputValue = '0';

  $: inputValue = formatAmount($itemAmount);
  $: isShop = $rightInventory.type === InventoryType.SHOP;

  function onInput(event: Event) {
    const target = event.currentTarget as HTMLInputElement;
    itemAmount.set(parseAmount(target.value));
  }

  function selectedPlayerItem() {
    return get(contextMenu)?.item || get(selectedSlot) || get(leftInventory).items.find((slot) => slot.name);
  }

  function primaryAction() {
    const item = selectedPlayerItem();
    if (!item?.name) return;

    if (isShop) {
      const shopItem = get(rightInventory).items.find((slot) => slot.name);
      const emptyTarget = get(leftInventory).items.find((slot) => !slot.name) || item;
      if (shopItem?.name) {
        void performBuy({ inventory: get(rightInventory).type, item: { name: shopItem.name, slot: shopItem.slot } }, { inventory: 'player', item: { slot: emptyTarget.slot } });
      }
      return;
    }

    useItem(item);
  }

  function secondaryAction() {
    const item = selectedPlayerItem();
    if (item?.name) giveItem(item);
  }
</script>

<aside class="aes" aria-label={$t('ui_actions', 'Actions')}>
  <div class="qtd">
    <input class="quantity-input" type="text" min="0" value={inputValue} on:input={onInput} />
  </div>
  <div class="aes3">
    <button class="action-btn" type="button" on:click={primaryAction}>
      <span class="action-btn-icon" style="-webkit-mask-image: url({useIcon}); mask-image: url({useIcon});"></span>
      <span class="action-text">{(isShop ? $t('ui_buy', 'Buy') : $t('ui_use', 'Use')).toUpperCase()}</span>
    </button>
    {#if !isShop}
      <button class="action-btn" type="button" on:click={secondaryAction}>
        <span class="action-btn-icon" style="-webkit-mask-image: url({giveIcon}); mask-image: url({giveIcon});"></span>
        <span class="action-text">{$t('ui_give', 'Give').toUpperCase()}</span>
      </button>
    {/if}
  </div>
</aside>
