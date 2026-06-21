<script lang="ts">
  import { toasts } from '../stores/state';
</script>

<div class="lk-toasts" aria-live="polite">
  {#each $toasts as toast (toast.id)}
    <div class={`lk-toast ${toast.type}`}>
      <span class="lk-toast-accent"></span>
      <div class="lk-toast-body">
        {#if toast.title}<strong class="lk-toast-title">{toast.title}</strong>{/if}
        <span class="lk-toast-desc">{toast.description}</span>
      </div>
    </div>
  {/each}
</div>
