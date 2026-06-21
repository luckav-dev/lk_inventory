export function hexToRgb(hex: string) {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : null;
}

export function applyThemeColor(hex: string) {
  const rgb = hexToRgb(hex);
  if (rgb) {
    document.documentElement.style.setProperty('--primary-red', hex);
    document.documentElement.style.setProperty('--primary-red-rgb', `${rgb.r}, ${rgb.g}, ${rgb.b}`);
    document.documentElement.style.setProperty('--primary-red-glow', `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.4)`);
  }
}
