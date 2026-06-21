<script lang="ts">
  import { fetchNui } from '../lib/nui';
  import { pinState, pinUnlocks, rightInventory } from '../stores/state';
  import { t } from '../lib/i18n';

  let pin = '';
  let busy = false;

  $: dots = Array.from({ length: 4 }, (_, index) => index < pin.length);

  function press(value: string) {
    pinState.update((state) => (state ? { ...state, error: undefined } : state));

    if (value === 'del') {
      pin = pin.slice(0, -1);
      return;
    }

    if (value === 'enter') {
      void unlock();
      return;
    }

    if (pin.length < 4) pin += value;
  }

  async function unlock() {
    if (!$pinState || pin.length < 4 || busy) return;

    busy = true;

    try {
      const response = await fetchNui<boolean | { success?: boolean; error?: string }>('lk_inventory:unlockStashPin', {
        stash: $rightInventory.id,
        pin,
      });
      const success = typeof response === 'boolean' ? response : response?.success === true;

      if (success) {
        pinUnlocks.update((current) => ({ ...current, [$rightInventory.id]: true }));
        pinState.set({ inventoryId: $rightInventory.id, required: true, unlocked: true });
        pin = '';
      } else {
        pin = '';
        pinState.update((state) => (state ? { ...state, error: (typeof response === 'object' && response.error) || $t('ui_pin_incorrect', 'Incorrect PIN') } : state));
      }
    } finally {
      busy = false;
    }
  }
</script>

{#if $pinState?.required && !$pinState.unlocked}
  <div class="stash-pin-overlay-fullscreen">
    <div class="pin-lock-screen-wrapper">
      <div class="pin-left-panel">
        <svg class="lock-icon animated" xmlns="http://www.w3.org/2000/svg" fill="var(--primary-red)" viewBox="0 0 24 24">
          <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" />
        </svg>
        <h2>{$t('ui_security_system', 'Security System')}</h2>
        <h1>{$t('ui_encrypted_access', 'Encrypted Access')}</h1>
        <p class="pin-sub">{$t('ui_pin_prompt', 'Enter the 4-digit PIN code to authorize unlocking the stash.')}</p>
      </div>

      <div class="pin-right-panel">
        <div class="pin-display">
          <div class="pin-dots">
            {#each dots as filled}
              <div class="pin-dot" class:filled></div>
            {/each}
          </div>
        </div>

        <div class="pin-keyboard">
          {#each ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'del', '0', 'enter'] as key}
            <button class:delete-key={key === 'del'} class:enter-key={key === 'enter'} class="pin-key" type="button" on:click={() => press(key)} disabled={busy}>
              {key === 'del' ? '<' : key === 'enter' ? 'OK' : key}
            </button>
          {/each}
        </div>

        {#if $pinState.error}
          <div class="pin-error visible">{$pinState.error}</div>
        {/if}
      </div>
    </div>
  </div>
{/if}
