import type { Env } from '../types';

/**
 * TriPay payment service — Task 15.x.
 *
 * TriPay is an Indonesian payment gateway (VA bank transfer, e-wallet, QRIS).
 * Docs: https://tripay.co.id/developer
 *
 * Sandbox: https://tripay.co.id/api-sandbox
 * Production: https://tripay.co.id/api
 */

const TRIPAY_BASE = 'https://tripay.co.id/api';

export interface PaymentRequest {
  payment_method: string; // 'BCVA', 'BRIVA', 'MANDIRIVA', 'QRIS', 'OVOPAY' etc.
  merchant_ref: string;   // our order_id
  amount: number;         // in IDR
  customer_name: string;
  customer_email: string;
  customer_phone?: string;
  order_items: Array<{
    name: string;
    price: number;
    quantity: number;
  }>;
  return_url?: string;
  expired_time?: number;   // Unix timestamp
}

export interface PaymentResponse {
  reference: string;       // TriPay reference
  payment_url?: string;
  pay_code?: string;        // VA number or QRIS code
  amount: number;
  status: string;
  fee: number;
  expired_time?: number;
  raw: Record<string, unknown>;
}

/** Build TriPay signature for transaction request. */
function buildSignature(env: Env, merchantRef: string, amount: number, expiredTime?: number): string {
  // TriPay signature: MD5(private_key + merchant_code + merchant_ref + amount + expired_time)
  const data = env.TRIPAY_MERCHANT_CODE + merchantRef + amount + (expiredTime ?? '');
  // Cloudflare Workers support crypto.subtle for SHA, but MD5 is not in WebCrypto.
  // TriPay accepts MD5 — implement via a small pure-JS MD5 (or use the official Node-like API).
  // For now, we use a pure-JS md5 implementation.
  return md5(env.TRIPAY_PRIVATE_KEY + data);
}

/** Build TriPay signature for webhook callback verification. */
export function buildWebhookSignature(env: Env, merchantRef: string, status: string, amount: number): string {
  // TriPay callback signature: MD5(merchant_ref + status + amount + private_key)
  return md5(merchantRef + status + amount + env.TRIPAY_PRIVATE_KEY);
}

/** Initiate a payment with TriPay. */
export async function createPayment(env: Env, request: PaymentRequest): Promise<PaymentResponse> {
  const expiredTime = request.expired_time ?? Math.floor(Date.now() / 1000) + 3600; // 1 hour default
  const signature = buildSignature(env, request.merchant_ref, request.amount, expiredTime);

  const body: Record<string, unknown> = {
    method: request.payment_method,
    merchant_ref: request.merchant_ref,
    amount: request.amount,
    customer_name: request.customer_name,
    customer_email: request.customer_email,
    customer_phone: request.customer_phone ?? '',
    order_items: request.order_items,
    signature,
    expired_time: expiredTime,
    return_url: request.return_url,
  };

  const url = `${TRIPAY_BASE}${env.ENVIRONMENT === 'production' ? '' : '-sandbox'}/transaction/create`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.TRIPAY_API_KEY}`,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`TriPay create error ${res.status}: ${errText}`);
  }

  const json = (await res.json()) as { success: boolean; data?: Record<string, unknown>; message?: string };
  if (!json.success || !json.data) {
    throw new Error(`TriPay create failed: ${json.message ?? 'unknown'}`);
  }
  const data = json.data;
  return {
    reference: String(data.reference ?? ''),
    payment_url: data.payment_url as string | undefined,
    pay_code: data.pay_code as string | undefined,
    amount: Number(data.amount ?? request.amount),
    status: String(data.status ?? 'UNPAID'),
    fee: Number(data.fee ?? 0),
    expired_time: data.expired_time as number | undefined,
    raw: data,
  };
}

/** Verify TriPay webhook signature (Task: payment security). */
export function verifyWebhookSignature(
  env: Env,
  merchantRef: string,
  status: string,
  amount: number,
  callbackSignature: string
): boolean {
  const expected = buildWebhookSignature(env, merchantRef, status, amount);
  return expected === callbackSignature;
}

/** Get payment status from TriPay. */
export async function getPaymentStatus(env: Env, reference: string): Promise<{ status: string; amount: number; raw: Record<string, unknown> }> {
  const url = `${TRIPAY_BASE}${env.ENVIRONMENT === 'production' ? '' : '-sandbox'}/transaction/detail?reference=${encodeURIComponent(reference)}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${env.TRIPAY_API_KEY}`,
    },
  });
  if (!res.ok) {
    throw new Error(`TriPay detail error ${res.status}`);
  }
  const json = (await res.json()) as { success: boolean; data?: Record<string, unknown>; message?: string };
  if (!json.success || !json.data) {
    throw new Error(`TriPay detail failed: ${json.message ?? 'unknown'}`);
  }
  return {
    status: String(json.data.status ?? 'UNPAID'),
    amount: Number(json.data.amount ?? 0),
    raw: json.data,
  };
}

// ---------- Pure-JS MD5 (small implementation for signature) ----------

/* eslint-disable */
// Compact MD5 implementation — required because WebCrypto doesn't support MD5.
function md5(input: string): string {
  function toBytes(s: string): number[] {
    const out: number[] = [];
    for (let i = 0; i < s.length; i++) {
      const c = s.charCodeAt(i);
      if (c < 128) out.push(c);
      else if (c < 2048) { out.push(0xc0 | (c >> 6)); out.push(0x80 | (c & 0x3f)); }
      else { out.push(0xe0 | (c >> 12)); out.push(0x80 | ((c >> 6) & 0x3f)); out.push(0x80 | (c & 0x3f)); }
    }
    return out;
  }

  function add32(a: number, b: number): number { return (a + b) & 0xffffffff; }
  function cmn(q: number, a: number, b: number, x: number, s: number, t: number): number {
    a = add32(add32(a, q), add32(x, t));
    return add32((a << s) | (a >>> (32 - s)), b);
  }
  function ff(a:number,b:number,c:number,d:number,x:number,s:number,t:number){return cmn((b&c)|((~b)&d),a,b,x,s,t);}
  function gg(a:number,b:number,c:number,d:number,x:number,s:number,t:number){return cmn((b&d)|(c&(~d)),a,b,x,s,t);}
  function hh(a:number,b:number,c:number,d:number,x:number,s:number,t:number){return cmn(b^c^d,a,b,x,s,t);}
  function ii(a:number,b:number,c:number,d:number,x:number,s:number,t:number){return cmn(c^(b|(~d)),a,b,x,s,t);}

  const x = toBytes(input);
  const len = x.length;
  x.push(0x80);
  let bits = len * 8;
  while ((x.length % 64) !== 56) x.push(0);
  // Append length (64-bit big-endian, but MD5 uses little-endian)
  for (let i = 0; i < 8; i++) x.push((bits >>> (8 * i)) & 0xff);

  let a = 0x67452301, b = 0xefcdab89, c = 0x98badcfe, d = 0x10325476;
  for (let i = 0; i < x.length; i += 64) {
    const blk = x.slice(i, i + 64);
    const X: number[] = new Array(16);
    for (let j = 0; j < 16; j++) X[j] = blk[j*4] | (blk[j*4+1]<<8) | (blk[j*4+2]<<16) | (blk[j*4+3]<<24);

    const aa = a, bb = b, cc = c, dd = d;

    // Round 1
    a=ff(a,b,c,d,X[0],7,-680876936);d=ff(d,a,b,c,X[1],12,-389564586);c=ff(c,d,a,b,X[2],17,606105819);b=ff(b,c,d,a,X[3],22,-1044525330);
    a=ff(a,b,c,d,X[4],7,-176418897);d=ff(d,a,b,c,X[5],12,1200080426);c=ff(c,d,a,b,X[6],17,-1473231341);b=ff(b,c,d,a,X[7],22,-45705983);
    a=ff(a,b,c,d,X[8],7,1770035416);d=ff(d,a,b,c,X[9],12,-1958414417);c=ff(c,d,a,b,X[10],17,-42063);b=ff(b,c,d,a,X[11],22,-1990404162);
    a=ff(a,b,c,d,X[12],7,1804603682);d=ff(d,a,b,c,X[13],12,-40341101);c=ff(c,d,a,b,X[14],17,-1502002290);b=ff(b,c,d,a,X[15],22,1236535329);
    // Round 2
    a=gg(a,b,c,d,X[1],5,-165796510);d=gg(d,a,b,c,X[6],9,-1069501632);c=gg(c,d,a,b,X[11],14,643717713);b=gg(b,c,d,a,X[0],20,-373897302);
    a=gg(a,b,c,d,X[5],5,-701558691);d=gg(d,a,b,c,X[10],9,38016083);c=gg(c,d,a,b,X[15],14,-660478335);b=gg(b,c,d,a,X[4],20,-405537848);
    a=gg(a,b,c,d,X[9],5,568446438);d=gg(d,a,b,c,X[14],9,-1019803690);c=gg(c,d,a,b,X[3],14,-187363961);b=gg(b,c,d,a,X[8],20,1163531501);
    a=gg(a,b,c,d,X[13],5,-1444681467);d=gg(d,a,b,c,X[2],9,-51403784);c=gg(c,d,a,b,X[7],14,1735328473);b=gg(b,c,d,a,X[12],20,-1926607734);
    // Round 3
    a=hh(a,b,c,d,X[5],4,-378558);d=hh(d,a,b,c,X[8],11,-2022574463);c=hh(c,d,a,b,X[11],16,1839030562);b=hh(b,c,d,a,X[14],23,-35309556);
    a=hh(a,b,c,d,X[1],4,-1530992060);d=hh(d,a,b,c,X[4],11,1272893353);c=hh(c,d,a,b,X[7],16,-155497632);b=hh(b,c,d,a,X[10],23,-1094730640);
    a=hh(a,b,c,d,X[13],4,681279174);d=hh(d,a,b,c,X[0],11,-358537222);c=hh(c,d,a,b,X[3],16,-722521979);b=hh(b,c,d,a,X[6],23,76029189);
    a=hh(a,b,c,d,X[9],4,-640364487);d=hh(d,a,b,c,X[12],11,-421815835);c=hh(c,d,a,b,X[15],16,530742520);b=hh(b,c,d,a,X[2],23,-995338651);
    // Round 4
    a=ii(a,b,c,d,X[0],6,-198630844);d=ii(d,a,b,c,X[7],10,1126891415);c=ii(c,d,a,b,X[14],15,-1416354905);b=ii(b,c,d,a,X[5],21,-57434055);
    a=ii(a,b,c,d,X[12],6,1700485571);d=ii(d,a,b,c,X[3],10,-1894986606);c=ii(c,d,a,b,X[10],15,-1051523);b=ii(b,c,d,a,X[1],21,-2054922799);
    a=ii(a,b,c,d,X[8],6,1873313359);d=ii(d,a,b,c,X[15],10,-30611744);c=ii(c,d,a,b,X[6],15,-1560198380);b=ii(b,c,d,a,X[13],21,1309151649);
    a=ii(a,b,c,d,X[4],6,-145523070);d=ii(d,a,b,c,X[11],10,-1120210379);c=ii(c,d,a,b,X[2],15,718787259);b=ii(b,c,d,a,X[9],21,-343485551);

    a = add32(a, aa); b = add32(b, bb); c = add32(c, cc); d = add32(d, dd);
  }

  function toHex(n: number): string {
    let s = '';
    for (let i = 0; i < 4; i++) {
      const byte = (n >>> (8 * i)) & 0xff;
      s += (byte < 16 ? '0' : '') + byte.toString(16);
    }
    return s;
  }
  return toHex(a) + toHex(b) + toHex(c) + toHex(d);
}
/* eslint-enable */