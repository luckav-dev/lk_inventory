<script lang="ts">
  import { clampPercent } from '../lib/format';

  export let percent = 0;
  export let durability = false;

  $: safePercent = clampPercent(percent);
  $: hue = durability ? Math.round((safePercent / 100) * 120) : Math.round(120 - (safePercent / 100) * 120);
  $: color = `hsl(${hue}, 72%, 50%)`;
</script>

<div class:durability-bar={durability} class:weight-bar={!durability}>
  <div style={`width: ${safePercent}%; background: ${color}; opacity: ${safePercent > 0 ? 1 : 0};`}></div>
</div>
