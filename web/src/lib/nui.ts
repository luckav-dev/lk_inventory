export const isEnvBrowser = () => typeof window.GetParentResourceName !== 'function';

const resourceName = () => window.GetParentResourceName?.() || 'lk-inventory';

export async function fetchNui<T = unknown>(eventName: string, data?: unknown): Promise<T> {
  if (isEnvBrowser()) {
    console.debug(`[LK Inventory mock] ${eventName}`, data);
    return true as T;
  }

  const response = await fetch(`https://${resourceName()}/${eventName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(data ?? {}),
  });

  return (await response.json()) as T;
}
