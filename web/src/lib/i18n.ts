import { derived } from 'svelte/store';
import { locale } from '../stores/state';

/**
 * Reactive translation helper. Returns a function `t(key, fallback)` that reads
 * the current locale map, falling back to an English default when the key is
 * missing (e.g. a locale file that hasn't translated it yet, or the browser
 * mockup where no locale is loaded).
 *
 * Usage in a component:
 *   import { t } from '../lib/i18n';
 *   {$t('ui_use', 'Use')}
 */
export const t = derived(locale, ($locale) => {
  return (key: string, fallback: string): string => $locale[key] || fallback;
});
