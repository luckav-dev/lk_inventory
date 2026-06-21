<script lang="ts">
  import { fetchNui } from '../lib/nui';
  import { t } from '../lib/i18n';

  let activeStates: Record<string, boolean> = {
    hat: true,
    mask: true,
    glasses: true,
    ear: true,
    neck: true,
    torso: true,
    vest: true,
    bag: true,
    pants: true,
    shoes: true,
    watch: true,
    bracelets: true
  };

  function toggle(type: string) {
    activeStates[type] = !activeStates[type];
    void fetchNui('toggleClothing', { type, active: activeStates[type] });
  }
</script>

<div class="clothing-sidebar" role="toolbar" aria-label={$t('ui_clothing', 'Clothing')}>
  <button class="clothing-btn" class:active={activeStates.hat} on:click={() => toggle('hat')} title={$t('ui_clothing_hat', 'Hat / Helmet')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2a9 9 0 0 0-9 9h18a9 9 0 0 0-9-9z" />
      <path d="M2 11c0 4.4 3.6 8 8 8h4c4.4 0 8-3.6 8-8" />
      {#if !activeStates.hat}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.mask} on:click={() => toggle('mask')} title={$t('ui_clothing_mask', 'Mask')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2a10 10 0 0 0-10 10c0 5.5 4.5 10 10 10s10-4.5 10-10A10 10 0 0 0 12 2z" />
      <path d="M9 11a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z" />
      <path d="M15 11a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z" />
      <path d="M12 17a3 3 0 0 0-3-3h6a3 3 0 0 0-3 3z" />
      {#if !activeStates.mask}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.glasses} on:click={() => toggle('glasses')} title={$t('ui_clothing_glasses', 'Glasses')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="6" cy="12" r="3" />
      <circle cx="18" cy="12" r="3" />
      <path d="M9 12h6" />
      <path d="M3 12V9a3 3 0 0 1 3-3" />
      <path d="M21 12V9a3 3 0 0 0-3-3" />
      {#if !activeStates.glasses}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.ear} on:click={() => toggle('ear')} title={$t('ui_clothing_ear', 'Ears / Earrings')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M6 8a6 6 0 0 1 12 0c0 4-3 6-3 10a3 3 0 0 1-6 0c0-1.5-1.5-3-3-5" />
      <circle cx="12" cy="18" r="1" />
      {#if !activeStates.ear}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.neck} on:click={() => toggle('neck')} title={$t('ui_clothing_neck', 'Neck Accessories')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M6 3h12l-2 6H8L6 3z" />
      <path d="M12 9v12" />
      <path d="M8 15l4 6 4-6" />
      {#if !activeStates.neck}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.torso} on:click={() => toggle('torso')} title={$t('ui_clothing_torso', 'Torso / Shirt')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M20.38 3.46 16 6V4a2 2 0 0 0-2-2H10a2 2 0 0 0-2 2v2L3.62 3.46a2 2 0 0 0-2.41.69l-1 1.5a2 2 0 0 0 .37 2.65L5 12v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8l4.42-4.7a2 2 0 0 0 .37-2.65l-1-1.5a2 2 0 0 0-2.41-.69z" />
      {#if !activeStates.torso}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.vest} on:click={() => toggle('vest')} title={$t('ui_clothing_vest', 'Vest')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      {#if !activeStates.vest}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.bag} on:click={() => toggle('bag')} title={$t('ui_clothing_bag', 'Backpack')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <rect x="4" y="4" width="16" height="16" rx="2" />
      <path d="M9 20V4" />
      <path d="M15 20V4" />
      <path d="M12 2v2" />
      {#if !activeStates.bag}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.pants} on:click={() => toggle('pants')} title={$t('ui_clothing_pants', 'Pants')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M4 2h16v8l-2 10H14l-2-6-2 6H6L4 10z" />
      {#if !activeStates.pants}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.shoes} on:click={() => toggle('shoes')} title={$t('ui_clothing_shoes', 'Shoes')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M3 17V6a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v8h7a2 2 0 0 1 2 2v2H3z" />
      {#if !activeStates.shoes}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.watch} on:click={() => toggle('watch')} title={$t('ui_clothing_watch', 'Watch')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="7" />
      <polyline points="12 9 12 12 14 12" />
      <path d="M12 5V1" />
      <path d="M12 19v4" />
      {#if !activeStates.watch}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>

  <button class="clothing-btn" class:active={activeStates.bracelets} on:click={() => toggle('bracelets')} title={$t('ui_clothing_bracelets', 'Bracelets')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <ellipse cx="12" cy="10" rx="9" ry="4" />
      <ellipse cx="12" cy="14" rx="9" ry="4" opacity="0.6" />
      {#if !activeStates.bracelets}
        <line x1="3" y1="21" x2="21" y2="3" stroke="var(--primary-red)" stroke-width="2.5" />
      {/if}
    </svg>
  </button>
</div>
