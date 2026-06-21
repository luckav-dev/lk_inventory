<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { auditEntries, auditVisible } from '../stores/state';
  import { fetchNui } from '../lib/nui';

  function close() {
    auditVisible.set(false);
    void fetchNui('closeAudit');
  }

  function onKey(event: KeyboardEvent) {
    if (event.key === 'Escape') close();
  }

  onMount(() => window.addEventListener('keydown', onKey));
  onDestroy(() => window.removeEventListener('keydown', onKey));
</script>

{#if $auditVisible}
  <div class="lk-audit-overlay">
    <div class="lk-audit-panel">
      <div class="lk-audit-header">
        <h2>INVENTORY AUDIT</h2>
        <button class="lk-audit-close" type="button" on:click={close}>×</button>
      </div>
      <div class="lk-audit-list">
        {#if $auditEntries.length === 0}
          <p class="lk-audit-empty">No recent activity.</p>
        {/if}
        {#each $auditEntries as entry}
          <div class="lk-audit-row">
            <span class="lk-audit-time">{entry.time}</span>
            <span class={`lk-audit-cat cat-${entry.category}`}>{entry.category}</span>
            <span class="lk-audit-player">{entry.player}</span>
            <span class="lk-audit-msg">{entry.message}</span>
          </div>
        {/each}
      </div>
    </div>
  </div>
{/if}
