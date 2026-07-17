const API_URL = import.meta.env.VITE_API_URL ?? '/api';

export interface ApiResult<T> {
  data?: T;
  error?: { code: string; message: string };
}

/** Get auth token from localStorage. The worker also sets an HttpOnly cookie
 *  `osee_token` on login, but that's only readable on the same domain. For
 *  cross-domain admin deployments we explicitly send `Authorization: Bearer`. */
function getToken(): string | null {
  return window.localStorage.getItem('osee_admin_token');
}

let onUnauthorized: (() => void) | null = null;

/** Register a global 401 handler — e.g. redirect to login screen. */
export function setUnauthorizedHandler(handler: () => void): void {
  onUnauthorized = handler;
}

/** Wrapper around fetch that adds auth header + JSON handling. */
export async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<ApiResult<T>> {
  const token = getToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, {
      ...options,
      headers,
      credentials: 'include',
    });
  } catch (err) {
    return {
      error: {
        code: 'NETWORK_ERROR',
        message: err instanceof Error ? err.message : 'Network error',
      },
    };
  }

  // 401 — token invalid/expired; trigger global logout
  if (response.status === 401) {
    if (onUnauthorized) onUnauthorized();
    return {
      error: {
        code: 'UNAUTHORIZED',
        message: 'Session expired. Please sign in again.',
      },
    };
  }

  // Handle non-JSON responses (e.g. Cloudflare 502 HTML pages)
  const contentType = response.headers.get('content-type') ?? '';
  if (!contentType.includes('application/json')) {
    return {
      error: {
        code: 'NON_JSON_RESPONSE',
        message: `Unexpected response (HTTP ${response.status}, ${contentType || 'no content-type'})`,
      },
    };
  }

  try {
    const data = (await response.json()) as T & { error?: { code: string; message: string } };
    if (data.error) {
      return { error: data.error };
    }
    return { data: data as T };
  } catch (err) {
    return {
      error: {
        code: 'PARSE_ERROR',
        message: err instanceof Error ? err.message : 'Failed to parse response',
      },
    };
  }
}

export async function adminLogin(email: string, password: string): Promise<ApiResult<{ jwt: string }>> {
  const result = await apiFetch<{ jwt: string }>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  if (result.data?.jwt) {
    window.localStorage.setItem('osee_admin_token', result.data.jwt);
  }
  return result;
}

export function adminLogout(): void {
  window.localStorage.removeItem('osee_admin_token');
}