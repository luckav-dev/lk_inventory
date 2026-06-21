<script lang="ts">
  import { dragPreview, getItemLabel, getItemUrl } from '../stores/state';
</script>

{#if $dragPreview}
  <div class="item-drag-preview" style={`transform: translate3d(${$dragPreview.x}px, ${$dragPreview.y}px, 0) translate(-50%, -50%);`}>
    <img src={getItemUrl($dragPreview.item)} alt={getItemLabel($dragPreview.item)} />
    <span>{getItemLabel($dragPreview.item)}</span>
  </div>
{/if}
