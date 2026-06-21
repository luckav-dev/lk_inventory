export function formatWeight(weight = 0) {
  if (weight >= 1000) {
    return `${(weight / 1000).toLocaleString('en-US', { maximumFractionDigits: 2 })}kg`;
  }

  return weight > 0 ? `${Math.floor(weight).toLocaleString('en-US')}g` : '';
}

export function formatCount(count?: number) {
  return count && count > 0 ? `${count.toLocaleString('en-US')}x` : '';
}

export function clampPercent(value: number) {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, value));
}

export function formatAmount(value: number) {
  return value > 0 ? value.toLocaleString('en-US') : '0';
}

export function parseAmount(value: string) {
  return parseInt(value.replace(/\D/g, ''), 10) || 0;
}
