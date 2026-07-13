const API_URL = '/api';

export interface ApiResult<T> {
  data?: T;
  error?: { code: string; message: string };
}

/** Get auth token from cookie (set by worker via domain=.osee.co.id). */
function getToken(): string | null {
  const stored = window.localStorage.getItem('osee_admin_token');
  if (stored) return stored;
  const match = document.cookie.match(/osee_token=([^;]+)/);
  return match ? match[1] : null;
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

  try {
    const response = await fetch(`${API_URL}${path}`, {
      ...options,
      headers,
      credentials: 'include',
    });
    const data = (await response.json()) as T & { error?: { code: string; message: string } };
    if (data.error) {
      return { error: data.error };
    }
    return { data: data as T };
  } catch (err) {
    return {
      error: {
        code: 'NETWORK_ERROR',
        message: err instanceof Error ? err.message : 'Network error',
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

export function adminLogout() {
  window.localStorage.removeItem('osee_admin_token');
}
