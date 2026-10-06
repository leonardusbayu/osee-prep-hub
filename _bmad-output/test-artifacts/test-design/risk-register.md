# Risk Register — OSEE Prep Hub

## Ringkasan Eksekutif

Risk register ini berisi risiko fungsional, keamanan, dan production readiness yang teridentifikasi dari audit `BLUEPRINT.md`, dokumentasi, dan codebase. Setiap risiko diberi severity dan likelihood untuk memprioritaskan pengujian.

## Legenda Severity

| Kode | Severity | Arti |
|---|---|---|
| **C** | Critical | Bisa menyebabkan kerugian finansial, data breach, atau platform down |
| **H** | High | Bisa merusak pengalaman pengguna atau menyebabkan bug signifikan |
| **M** | Medium | Dapat ditoleransi dalam jangka pendek tetapi harus diuji dan dimonitor |
| **L** | Low | Peningkatan kualitas, tidak blocker untuk go-live |

## Legenda Likelihood

| Kode | Likelihood | Arti |
|---|---|---|
| **A** | Almost Certain | Sangat mungkin terjadi tanpa pengujian |
| **L** | Likely | Cukup mungkin terjadi |
| **P** | Possible | Mungkin terjadi dalam kondisi tertentu |
| **U** | Unlikely | Jarang terjadi |

## Risk Register

| ID | Kategori | Risiko | Severity | Likelihood | Bukti di Kode | Mitigasi / Test yang Diperlukan | Status |
|---|---|---|---|---|---|---|---|
| **R-FIN-01** | Financial | Commission bisa di-credit dua kali untuk event yang sama karena idempotensi hanya mengandalkan `commission_ledger` duplicate key | C | L | `services/commission.ts` baris 89–98 & 121–123 | Test idempotensi: panggil `recordCommission` 2× untuk event `practice_completed` yang sama; pastikan hanya 1 ledger entry. | Open |
| **R-FIN-02** | Financial | Recurring premium commission (`premium-recurring.ts`) belum diuji; bisa double-credit bulanan jika cron berjalan lebih dari sekali | C | L | `services/premium-recurring.ts` tidak memiliki test | Test idempotensi monthly credit; verifikasi `last_premium_credit_at` diupdate atomik. | Open |
| **R-FIN-03** | Financial | Payout request tidak mengurangi saldo `commission_ledger.pending` saat dibuat; admin approve payout harus sinkron dengan ledger update | C | P | `services/commission-dashboard.ts` `requestPayout` hanya insert ke `commission_payouts` | Test: request payout > pending balance ditolak; test status flow pending → processing → paid. | Open |
| **R-FIN-04** | Financial | TriPay webhook signature belum diuji; pembayaran palsu bisa menandai order sebagai paid | C | L | `services/tripay.ts` tidak memiliki test | Test verifyWebhookSignature dengan payload valid & invalid; test replay attack. | Open |
| **R-FIN-05** | Financial | Voucher lifecycle (redeem, expiry, status) perlu diverifikasi agar tidak ada voucher yang dapat dipakai berulang kali | H | L | `services/voucher.ts`, `routes/voucher.ts` memiliki `voucher.test.ts` | Tambahkan E2E test redeem → redeem lagi harus gagal. | Open |
| **R-AUTH-01** | Security | JWT payload tidak menyimpan `display_name`, `teacher_institution`, dll; middleware hanya cek role dari token, bukan DB | M | L | `middleware/auth.ts` `userFromPayload` mengembalikan null untuk beberapa field | Test: route yang memerlukan DB-backed field (misal partner check) harus fetch ulang dari Supabase. | Open |
| **R-AUTH-02** | Security | RLS policies aktif tetapi worker menggunakan `SUPABASE_SERVICE_KEY`, sehingga mem-bypass semua RLS | C | A | `services/supabase.ts` `getSupabase` menggunakan service key; `schema.sql` RLS enabled | Verifikasi tidak ada route yang mengandalkan RLS untuk authorization; semua authorization harus di route/service. | Open |
| **R-AUTH-03** | Security | Cookie `osee_token` dikirim dengan domain `.osee.co.id`; tidak ada flag `SameSite=Strict` eksplisit di kode | H | P | `services/cookie.ts` perlu diperiksa | Test cookie flags: HttpOnly, Secure, SameSite di production; verifikasi tidak ada XSS leakage. | Open |
| **R-AUTH-04** | Security | Role guard hanya mengecek string role; tidak memverifikasi role masih aktif/valid dari DB | M | L | `middleware/auth.ts` `requireRole` | Test: role yang diubah di DB harus tidak berlaku untuk token lama (token expiry strategy). | Open |
| **R-AUTH-05** | Security | Admin endpoints (`/api/admin/*`) terbuka untuk setiap user dengan `role='admin'`. Tidak ada MFA atau audit log | H | P | `routes/admin.ts` | Test: admin action harus tercatat; non-admin harus selalu 403. | Open |
| **R-WEB-01** | Security | Webhook secrets adalah shared secret statis; jika leaked, attacker bisa mengirim event palsu | C | P | `middleware/webhook-auth.ts` membandingkan `X-Webhook-Secret` plaintext | Rotasi secret; test invalid secret, missing header, replay attack. | Open |
| **R-WEB-02** | Functional | Webhook processing tidak memiliki retry mechanism yang jelas; failed events hanya ditandai | H | P | `services/webhook-processor.ts` | Test: event gagal harus meningkatkan `retry_count` dan tidak menghilang; dead letter queue. | Open |
| **R-WEB-03** | Functional | Webhook payload shape dari platform eksternal tidak dikontrak; mock harus merepresentasikan variasi | M | L | `docs/API.md` hanya contoh payload | Buat mock payloads untuk masing-masing 6 platform dengan edge cases. | Open |
| **R-AI-01** | Functional | AI quota menghitung usage dari `ai_grading_queue` & `ai_generation_queue` dengan fallback `student_id` untuk grading; bisa tidak akurat | M | L | `services/quota.ts` baris 164–178 | Test: teacher mengsubmit 1 essay → usage = 1; student mengsubmit sendiri → usage tetap tercatat. | Open |
| **R-AI-02** | Functional | AI generated content belum selalu divalidasi sebelum disimpan | H | L | `services/ai-generation.ts` | Test: `content-validator.ts` harus selalu dipanggil; fail validation harus reject. | Open |
| **R-AI-03** | Operational | OpenAI API failure tidak selalu graceful; queue entry bisa stuck di `processing` | H | L | `services/grading-queue.ts`, `services/ai-grading.ts` | Test: timeout/gagal OpenAI harus update status `failed` + `error_message`. | Open |
| **R-AI-04** | Financial | Quota bonus tidak dibatasi; teacher bisa mendapat unlimited bonus dari fake referrals | H | P | `services/quota.ts` `awardQuotaBonus` | Test: bonus hanya diberikan untuk event valid dan tidak duplikat. | Open |
| **R-ORD-01** | Financial | Order fulfillment status memiliki banyak states (`pending`, `voucher_generated`, `booking_confirmed`, dll); transisi tidak dijamin konsisten | C | L | `schema.sql` `order_items.fulfillment_status`; `services/orders.ts` | State machine test untuk setiap item type dan transisi. | Open |
| **R-ORD-02** | Financial | Admin `mark-paid` bypass pembayaran TriPay; perlu audit trail kuat | H | P | `routes/admin.ts` admin orders actions | Test: `mark-paid` hanya boleh admin, tercatat di order, dan tidak memicu double fulfillment. | Open |
| **R-ORD-03** | Functional | Bulk purchase / book_for_student bisa memiliki assigned_student_id null; fulfillment harus menanganinya | H | P | `schema.sql` `order_items.assigned_student_id` nullable | Test: create order tanpa assigned student → fulfillment status `pending_assignment`. | Open |
| **R-DB-01** | Security | `is_admin()` SECURITY DEFINER function bypass RLS; jika anon key bisa memanggilnya, privilege escalation | C | P | `schema.sql` baris 1150–1156 | Verifikasi `is_admin()` tidak diekspos ke API dan hanya dipakai oleh policies. | Open |
| **R-DB-02** | Functional | `schema.sql` tidak dapat diaplikasikan ulang ke database yang sudah ada karena beberapa CREATE POLICY tidak memiliki IF NOT EXISTS | H | P | `schema.sql` section 17b | Catat dalam deployment runbook: re-apply memerlukan drop policy terlebih dahulu. | Open |
| **R-DB-03** | Operational | Database migration strategy adalah forward-only; rollback memerlukan perbaikan manual | H | P | `docs/DEPLOYMENT.md` bagian Rollback | Test plan harus mencakup migration test dan rollback procedure. | Open |
| **R-OPS-01** | Production Readiness | Worker typecheck memiliki 3 error dan 3 test gagal; tidak bisa dianggap production-ready | C | A | `npm run typecheck` dan `npm test` worker | Perbaiki typecheck error dan test failure sebelum go-live; catat dalam readiness gate. | **Resolved** — typecheck & test worker hijau (225 passed) |
| **R-OPS-02** | Production Readiness | Cron trigger menjalankan 3 jobs setiap menit; failure di salah satu tidak boleh menghentikan yang lain | H | L | `worker/src/index.ts` `scheduledHandler` | Test: cron handler isolasi error antara webhook batch, class reminder, dan premium recurring. | Open |
| **R-OPS-03** | Production Readiness | Rate limiter in-memory tidak akurat across worker isolates; DoS masih mungkin | H | L | `middleware/rate-limit.ts` | Sarankan Cloudflare Rate Limiting Rules sebagai defense utama; test sebagai defense-in-depth. | Open |
| **R-OPS-04** | Production Readiness | Logging hanya `console.error`; tidak ada structured logging atau correlation ID | M | L | `worker/src/index.ts` `app.onError` | Test: setiap error response harus memiliki requestId atau traceable ID. | Open |
| **R-OPS-05** | Production Readiness | Flutter app tidak diimplementasikan; jika mobile/web app diperlukan, ini adalah deliverable yang hilang | H | A | `flutter/` hanya README.md dan vendor | Jadikan go-live blocker tergantung requirement; uji admin frontend sebagai pengganti sementara. | Open |
| **R-OPS-06** | Production Readiness | Health check hanya mengembalikan static JSON; tidak memeriksa koneksi Supabase, OpenAI, atau TriPay | H | L | `worker/src/index.ts` `/api/health` | Tambahkan health check dependency readiness. | Open |
| **R-EXT-01** | Integration | EduBot bridge (`/api/external/*`) hanya mengandalkan `X-Internal-Secret`; secret leaked = full access | C | P | `routes/external.ts` | Test secret rotation, invalid secret, dan principle of least privilege. | Open |
| **R-EXT-02** | Integration | OSEE booking bridge (`services/booking-bridge.ts`) belum diuji; official test booking bisa gagal | H | P | `services/booking-bridge.ts` tanpa test | Mock test untuk success/failure/t timeout. | Open |
| **R-EXT-03** | Integration | Email service (Resend) belum diuji; report delivery dan teacher invitation gagal silently | H | L | `services/email.ts` memiliki `email.test.ts` | Test `sendReportEmail` menghasilkan 502 di `teacher.test.ts`; perlu diperbaiki. | **Resolved** — report email route 502 sudah diperbaiki; profile fetch fallback ke user.email |
| **R-FE-01** | Frontend | Frontend-admin hanya memiliki 1 test file untuk 11 pages; banyak UI paths tidak tercover | H | L | `frontend-admin/src/pages.test.tsx` | Perluas test per page dan interaksi CRUD. | Open |
| **R-FE-02** | Frontend | `apiFetch` menyimpan token di `localStorage` dan `credentials: 'include'`; XSS risk jika tidak ada CSP | M | L | `frontend-admin/src/api/client.ts` | Audit security headers dan CSP. | Open |
| **R-FE-03** | Frontend | Build warning tentang `esbuild` option deprecated; bisa jadi error di vite upgrade | L | U | `frontend-admin` build warnings | Perbarui konfigurasi Vite. | Open |

## Ringkasan Risiko per Kategori

| Kategori | Critical | High | Medium | Low | Total |
|---|---:|---:|---:|---:|---:|
| Financial | 4 | 1 | 0 | 0 | 5 |
| Security | 2 | 3 | 1 | 0 | 6 |
| Webhook | 1 | 2 | 1 | 0 | 4 |
| AI / Quota | 0 | 3 | 1 | 0 | 4 |
| Orders | 1 | 2 | 0 | 0 | 3 |
| Database | 1 | 1 | 0 | 0 | 2 |
| Production Readiness | 1 | 3 | 1 | 1 | 6 |
| Integration | 1 | 2 | 0 | 0 | 3 |
| Frontend | 0 | 2 | 1 | 1 | 4 |
| **Total** | **11** | **17** | **5** | **2** | **35** |

## Risiko Prioritas Tertinggi (Blocker Go-Live)

1. **R-FIN-01** — Commission double-credit
2. **R-FIN-02** — Recurring premium double-credit
3. **R-FIN-04** — TriPay webhook signature bypass
4. **R-AUTH-02** — RLS bypass via service key
5. **R-WEB-01** — Webhook shared secret leak
6. **R-ORD-01** — Order fulfillment state inconsistency
7. **R-EXT-01** — EduBot bridge secret leaked

## Risiko yang Sudah Ditangani

- **R-OPS-01** — Typecheck error dan test failure worker ✅ (225 passed, typecheck hijau)
- **R-EXT-03** — Report email 502 error ✅ (sudah diperbaiki dengan profile fetch fallback)

## Kesimpulan

Mayoritas risiko kritis terkonsentrasi pada **logic finansial** (commission, orders, payouts) dan **keamanan** (RLS bypass, shared secrets, webhook integrity). Untuk go-live, pengujian harus memprioritaskan area-area tersebut dengan mock external dependencies.
