import { Hono } from 'hono';
import type { Env, ContextVars, User, UserRole } from '../types';
import { signJwt, verifyJwt, isValidRole } from '../services/jwt';
import { hashPassword, verifyPassword } from '../services/password';
import { buildAuthCookie, buildClearAuthCookie, COOKIE_NAME } from '../services/cookie';
import { getSupabase } from '../services/supabase';
import { autoEnrollReferredStudent } from '../services/classroom';

export const authRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// ---------- Validation helpers ----------

interface RegisterBody {
  email: string;
  password: string;
  name: string;
  role: UserRole;
  phone?: string;
  referral_code?: string;
  institution_name?: string; // required if role=partner
}

interface LoginBody {
  email: string;
  password: string;
}

const EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

function validateEmail(email: unknown): email is string {
  return typeof email === 'string' && EMAIL_REGEX.test(email);
}

function validatePassword(password: unknown): password is string {
  // Min 8 chars, at least 1 letter and 1 number
  return (
    typeof password === 'string' &&
    password.length >= 8 &&
    /[A-Za-z]/.test(password) &&
    /\d/.test(password)
  );
}

// ---------- Register ----------

authRoutes.post('/register', async (c) => {
  let body: RegisterBody;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON body' } }, 400);
  }

  const { email, password, name, role, phone, referral_code, institution_name } = body;

  // Validate required fields
  if (!validateEmail(email)) {
    return c.json({ error: { code: 'INVALID_EMAIL', message: 'Valid email required' } }, 400);
  }
  if (!validatePassword(password)) {
    return c.json(
      {
        error: {
          code: 'WEAK_PASSWORD',
          message: 'Password must be at least 8 chars with 1 letter and 1 number',
        },
      },
      400
    );
  }
  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_NAME', message: 'Name required' } }, 400);
  }
  if (!isValidRole(role)) {
    return c.json(
      { error: { code: 'INVALID_ROLE', message: 'Role must be student, teacher, partner, or admin' } },
      400
    );
  }
  if (role === 'partner' && (!institution_name || institution_name.trim().length === 0)) {
    return c.json(
      { error: { code: 'INSTITUTION_NAME_REQUIRED', message: 'Partner role requires institution_name' } },
      400
    );
  }

  const supabase = getSupabase(c.env);

  // Check for existing user
  const { data: existing } = await supabase.from('unified_profiles').select('id').eq('email', email.toLowerCase()).maybeSingle();
  if (existing) {
    return c.json({ error: { code: 'EMAIL_EXISTS', message: 'Email already registered' } }, 409);
  }

  // Validate referral code if provided
  let referredBy: string | null = null;
  if (referral_code) {
    const { data: referrer } = await supabase
      .from('teacher_profiles')
      .select('user_id, referral_code_active')
      .eq('referral_code', referral_code.toUpperCase())
      .maybeSingle();
    if (!referrer || !referrer.referral_code_active) {
      return c.json({ error: { code: 'INVALID_REFERRAL', message: 'Invalid or inactive referral code' } }, 400);
    }
    referredBy = referrer.user_id as string;
    // Prevent self-referral
    if (referredBy === email) {
      return c.json({ error: { code: 'SELF_REFERRAL', message: 'Cannot refer yourself' } }, 400);
    }
  }

  // Hash password
  const passwordHash = await hashPassword(password);

  // Create user record
  const insertPayload: Record<string, unknown> = {
    email: email.toLowerCase(),
    password_hash: passwordHash,
    display_name: name.trim(),
    role,
    phone: phone ?? null,
  };
  if (role === 'partner') {
    insertPayload.teacher_institution = institution_name;
  }
  if (referredBy) {
    insertPayload.referred_by = referredBy;
  }

  const { data: newUser, error: insertError } = await supabase
    .from('unified_profiles')
    .insert(insertPayload)
    .select()
    .single();

  if (insertError || !newUser) {
    console.error('Register insert failed:', insertError);
    return c.json({ error: { code: 'REGISTER_FAILED', message: 'Failed to create user' } }, 500);
  }

  // If teacher, create teacher_profiles row with referral code
  if (role === 'teacher') {
    const referralCode = await generateUniqueReferralCode(supabase);
    await supabase.from('teacher_profiles').insert({
      user_id: newUser.id,
      referral_code: referralCode,
      referral_code_active: true,
    });
  }

  // If student signed up with a referral code, auto-enroll them in the teacher's classroom
  let autoEnrolled: { classroom_id: string; classroom_name: string; created_default: boolean } | null = null;
  if (referredBy && role === 'student' && referral_code) {
    try {
      autoEnrolled = await autoEnrollReferredStudent(c.env, referredBy, newUser.id, referral_code.toUpperCase());
    } catch (err) {
      // Non-fatal — student can still join a classroom later via join code
      console.error('Auto-enroll failed (non-fatal):', err);
    }
  }

  // Issue JWT
  const token = await signJwt(c.env, {
    sub: newUser.id,
    email: newUser.email,
    role: newUser.role as UserRole,
  });

  // Build user response (omit password_hash)
  const userResponse: User = {
    id: newUser.id,
    email: newUser.email,
    display_name: newUser.display_name,
    role: newUser.role as UserRole,
    avatar_url: newUser.avatar_url ?? null,
    telegram_id: newUser.telegram_id ?? null,
    target_exam: newUser.target_exam ?? null,
    target_score: newUser.target_score ?? null,
    current_level: newUser.current_level ?? null,
    created_at: newUser.created_at,
    updated_at: newUser.updated_at,
  };

  // Set cookie + return
  c.header('Set-Cookie', buildAuthCookie(token));
  const response: Record<string, unknown> = { jwt: token, user: userResponse };
  if (autoEnrolled) {
    response.auto_enrolled = autoEnrolled;
  }
  return c.json(response, 201);
});

// ---------- Login ----------

authRoutes.post('/login', async (c) => {
  let body: LoginBody;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON body' } }, 400);
  }

  const { email, password } = body;
  if (!validateEmail(email) || typeof password !== 'string') {
    return c.json({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' } }, 400);
  }

  const supabase = getSupabase(c.env);
  const { data: user, error } = await supabase
    .from('unified_profiles')
    .select('*')
    .eq('email', email.toLowerCase())
    .maybeSingle();

  if (error || !user || !user.password_hash) {
    return c.json({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' } }, 401);
  }

  const valid = await verifyPassword(password, user.password_hash);
  if (!valid) {
    return c.json({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' } }, 401);
  }

  const token = await signJwt(c.env, {
    sub: user.id,
    email: user.email,
    role: user.role as UserRole,
  });

  const userResponse: User = {
    id: user.id,
    email: user.email,
    display_name: user.display_name,
    role: user.role as UserRole,
    avatar_url: user.avatar_url ?? null,
    telegram_id: user.telegram_id ?? null,
    target_exam: user.target_exam ?? null,
    target_score: user.target_score ?? null,
    current_level: user.current_level ?? null,
    created_at: user.created_at,
    updated_at: user.updated_at,
  };

  c.header('Set-Cookie', buildAuthCookie(token));
  return c.json({ jwt: token, user: userResponse });
});

// ---------- Verify ----------

authRoutes.post('/verify', async (c) => {
  // Read JWT from cookie or Authorization header
  const authHeader = c.req.header('Authorization');
  let token: string | null = null;
  if (authHeader) {
    const match = /^Bearer\s+(.+)$/i.exec(authHeader);
    if (match) token = match[1].trim();
  }
  if (!token) {
    const cookieHeader = c.req.header('Cookie');
    if (cookieHeader) {
      for (const part of cookieHeader.split(';')) {
        const [name, ...valueParts] = part.trim().split('=');
        if (name === COOKIE_NAME) {
          token = valueParts.join('=').trim();
          break;
        }
      }
    }
  }

  if (!token) {
    return c.json({ valid: false, error: { code: 'NO_TOKEN', message: 'No token provided' } }, 401);
  }

  try {
    const payload = await verifyJwt(c.env, token);
    const supabase = getSupabase(c.env);
    const { data: user, error } = await supabase
      .from('unified_profiles')
      .select('*')
      .eq('id', payload.sub)
      .maybeSingle();
    if (error || !user) {
      return c.json({ valid: false, error: { code: 'USER_NOT_FOUND', message: 'User not found' } }, 401);
    }

    const userResponse: User = {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      role: user.role as UserRole,
      avatar_url: user.avatar_url ?? null,
      telegram_id: user.telegram_id ?? null,
      target_exam: user.target_exam ?? null,
      target_score: user.target_score ?? null,
      current_level: user.current_level ?? null,
      created_at: user.created_at,
      updated_at: user.updated_at,
    };

    return c.json({ valid: true, user: userResponse });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Invalid token';
    return c.json({ valid: false, error: { code: 'INVALID_TOKEN', message } }, 401);
  }
});

// ---------- Refresh ----------

authRoutes.post('/refresh', async (c) => {
  // Read JWT from cookie or Authorization header
  const authHeader = c.req.header('Authorization');
  let token: string | null = null;
  if (authHeader) {
    const match = /^Bearer\s+(.+)$/i.exec(authHeader);
    if (match) token = match[1].trim();
  }
  if (!token) {
    const cookieHeader = c.req.header('Cookie');
    if (cookieHeader) {
      for (const part of cookieHeader.split(';')) {
        const [name, ...valueParts] = part.trim().split('=');
        if (name === COOKIE_NAME) {
          token = valueParts.join('=').trim();
          break;
        }
      }
    }
  }

  if (!token) {
    return c.json({ error: { code: 'NO_TOKEN', message: 'No token provided' } }, 401);
  }

  try {
    const payload = await verifyJwt(c.env, token);
    const supabase = getSupabase(c.env);
    const { data: user, error } = await supabase
      .from('unified_profiles')
      .select('id, email, role')
      .eq('id', payload.sub)
      .maybeSingle();
    if (error || !user) {
      return c.json({ error: { code: 'USER_NOT_FOUND', message: 'User not found' } }, 401);
    }

    const newToken = await signJwt(c.env, {
      sub: user.id,
      email: user.email,
      role: user.role as UserRole,
    });

    c.header('Set-Cookie', buildAuthCookie(newToken));
    return c.json({ jwt: newToken });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Invalid token';
    return c.json({ error: { code: 'INVALID_TOKEN', message } }, 401);
  }
});

// ---------- Logout ----------

authRoutes.post('/logout', async (c) => {
  c.header('Set-Cookie', buildClearAuthCookie());
  return c.json({ success: true });
});

// ---------- Helpers ----------

/** Generate a unique 8-char referral code (e.g. "MRSARI24"). */
async function generateUniqueReferralCode(
  supabase: import('@supabase/supabase-js').SupabaseClient
): Promise<string> {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I, O, 0, 1
  for (let attempt = 0; attempt < 10; attempt++) {
    let code = '';
    for (let i = 0; i < 8; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }
    const { data } = await supabase
      .from('teacher_profiles')
      .select('referral_code')
      .eq('referral_code', code)
      .maybeSingle();
    if (!data) return code;
  }
  throw new Error('Failed to generate unique referral code after 10 attempts');
}