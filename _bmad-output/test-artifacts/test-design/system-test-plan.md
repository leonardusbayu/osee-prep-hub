# System Test Plan — OSEE Prep Hub

## 1. Ringkasan Eksekutif

Dokumen ini adalah **System-Level Test Plan** untuk platform OSEE Prep Hub. Test plan ini disusun berdasarkan:

- `BLUEPRINT.md` sebagai sumber kebenaran fungsional
- `docs/API.md`, `docs/COMMISSION.md`, `docs/AMBASSADOR.md`, `docs/DEPLOYMENT.md`, `docs/TESTING.md`
- `schema.sql` dan `wrangler.toml`
- Codebase aktual di `worker/`, `frontend-admin/`, dan `flutter/`

Tujuan dari test plan ini adalah menilai:

1. **Feature completeness** — fitur blueprint mana yang sudah diimplementasikan dan apa yang masih hilang
2. **Functional risks** — risiko logika bisnis (terutama finansial)
3. **Security risks** — auth, authorization, webhook integrity, secrets
4. **Production readiness** — test coverage, typecheck, deployment, monitoring

Dokumen ini akan diperbarui seiring bertambahnya test coverage dan penanganan risiko.

## 2. Lingkup (Scope)

### 2.1 In-Scope

- Backend API Worker (`worker/src/routes/*`, `worker/src/services/*`, `worker/src/middleware/*`)
- Admin Frontend (`frontend-admin/src/*`)
- Database schema dan RLS policies (`schema.sql`)
- Deployment configuration (`wrangler.toml`, `package.json`)
- Integrasi dengan platform eksternal **secara mock** (ibt, itp, ielts, toeic, osee, EduBot, TriPay, OpenAI, Resend)

### 2.2 Out-of-Scope

- Testing terhadap platform eksternal nyata (dengan asumsi mock-only)
- Implementasi Flutter mobile/web app (belum ada source code)
- Performance/load testing intensif (akan dicatat sebagai rekomendasi)
- Penetration testing manual (akan dicatat sebagai rekomendasi)

### 2.3 Asumsi

- External dependencies akan di-mock menggunakan request fixtures atau test doubles.
- Supabase database dapat di-reproduksi di environment test.
- Semua secrets menggunakan environment variables; tidak ada secret yang hardcoded.

## 3. Tujuan Testing

| Tujuan | Kriteria Sukses |
|---|---|
| Verifikasi fitur blueprint | Setiap fitur Critical/High memiliki setidaknya 1 test case |
| Identifikasi functional risk | Setiap risiko finansial diuji untuk idempotensi dan consistency |
| Identifikasi security risk | Setiap celah auth/webhook diuji dengan negative cases |
| Production readiness | Typecheck hijau, test suite hijau, deployment checklist lengkap |

## 4. Strategi Testing

### 4.1 Risk-Based Testing

Prioritas testing didasarkan pada **risk register** (`risk-register.md`). Area dengan severity **Critical** dan **High** diuji terlebih dahulu.

Urutan prioritas:

1. Financial logic (commission, orders, payouts, vouchers)
2. Authentication & authorization (JWT, RLS, role guards)
3. Webhook security & processing
4. AI quota & content validation
5. Database consistency & RLS
6. Admin portal & frontend
7. Operational readiness (cron, health checks, monitoring)

### 4.2 Level Test

| Level | Teknik | Tools | Scope |
|---|---|---|---|
| Unit Test | Pure function, service logic | Vitest | `worker/src/services/*.test.ts` |
| Integration Test | Route handler + mocked DB | Vitest + Hono `app.request()` | `worker/src/routes/*.test.ts` |
| API Contract Test | Endpoint request/response | Vitest + mock fetch | Semua `/api/*` routes |
| Security Test | Negative auth, invalid secrets, role escalation | Vitest | Auth, webhook, admin routes |
| E2E Frontend | Component rendering, user flow | Vitest + Testing Library | `frontend-admin/src/pages` |
| Smoke Test | Health check, deployment verification | curl / wrangler | Production environment |

### 4.3 Mocking Strategy

Karena platform eksternal di-mock, gunakan pendekatan:

- **Supabase:** stub `prepare`, `select`, `insert`, `update`, `delete` responses
- **OpenAI:** mock HTTP responses untuk GPT-4o-mini, embeddings, Whisper
- **TriPay:** mock payment creation & webhook signature
- **EduBot:** mock `/api/external/*` dengan internal secret
- **OSEE booking:** mock `booking-bridge.ts` responses
- **Practice platforms:** mock webhook payloads dengan `X-Webhook-Secret`
- **R2:** mock upload/download/presigned URLs
- **Resend:** mock email send endpoint

## 5. Lingkungan Test

### 5.1 Minimum Environment

- Node.js 20+
- Supabase local atau test project
- Cloudflare Wrangler dev environment
- Vitest test runner

### 5.2 Environment Variables (Mock)

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Service key untuk bypass RLS di worker |
| `JWT_SECRET` | JWT signing/verification |
| `OPENAI_API_KEY` | Mock OpenAI API |
| `TRIPAY_API_KEY`, `TRIPAY_PRIVATE_KEY`, `TRIPAY_MERCHANT_CODE` | Mock TriPay |
| `WEBHOOK_SECRET_*` | Mock secrets untuk masing-masing platform |
| `EDUBOT_INTERNAL_SECRET` | Mock internal secret |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHANNEL_ID` | Mock Telegram |
| `OSEE_BOOKING_API_URL`, `OSEE_BOOKING_API_SECRET` | Mock booking bridge |
| `RESEND_API_KEY` | Mock email service |

## 6. Katalog Test Case per Domain

### 6.1 Auth & SSO

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-AUTH-01 | Register dengan email valid, password kuat, role teacher/student | High | R-AUTH-01 |
| TC-AUTH-02 | Register dengan email yang sudah ada → error duplicate | High | R-AUTH-01 |
| TC-AUTH-03 | Login dengan credential valid → JWT + cookie `osee_token` | High | R-AUTH-01 |
| TC-AUTH-04 | Login dengan password salah → 401 tanpa informasi user exists | High | R-AUTH-01 |
| TC-AUTH-05 | Akses protected route tanpa token → 401 | High | R-AUTH-01 |
| TC-AUTH-06 | Akses admin route dengan role teacher → 403 | High | R-AUTH-05 |
| TC-AUTH-07 | Token expired → 401 | High | R-AUTH-04 |
| TC-AUTH-08 | Cookie flags: HttpOnly, Secure, SameSite | Medium | R-AUTH-03 |
| TC-AUTH-09 | Refresh token mengeluarkan access token baru | Medium | R-AUTH-04 |
| TC-AUTH-10 | Link Telegram dengan token valid → profile ter-link | Medium | Blueprint §3 |

### 6.2 Teacher Portal

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-TCH-01 | Teacher create classroom dengan target exam valid | High | Feature matrix |
| TC-TCH-02 | Generate join code unik | Medium | Feature matrix |
| TC-TCH-03 | Teacher melihat daftar classroom sendiri | High | R-AUTH-02 |
| TC-TCH-04 | Teacher tidak bisa melihat classroom guru lain | High | R-AUTH-02 |
| TC-TCH-05 | Syllabus CRUD: create, list, get, update, delete | High | Feature matrix |
| TC-TCH-06 | Batch save syllabus items mempertahankan order | Medium | Feature matrix |
| TC-TCH-07 | Referral code unik per teacher | Medium | Feature matrix |
| TC-TCH-08 | Material catalog filter by type/difficulty/exam | Medium | Feature matrix |
| TC-TCH-09 | Student report JSON/HTML generation | High | R-EXT-03 |
| TC-TCH-10 | Email report mengirim ke email student | High | R-EXT-03 |

### 6.3 Student Portal

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-STD-01 | Student join classroom via valid join code | High | Feature matrix |
| TC-STD-02 | Student join dengan kode tidak valid → error | Medium | Feature matrix |
| TC-STD-03 | Student melihat syllabus yang diassign | High | Feature matrix |
| TC-STD-04 | Mark syllabus item start & complete | High | Feature matrix |
| TC-STD-05 | Progress aggregation dari webhook events | High | Feature matrix |
| TC-STD-06 | Readiness gauge calculation | Medium | Feature matrix |
| TC-STD-07 | Cross-exam score map lookup | Low | Feature matrix |

### 6.4 AI Services

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-AI-01 | RAG search mengembalikan dokumen relevan | High | Feature matrix |
| TC-AI-02 | Grade writing dengan valid input → score & feedback | High | Feature matrix |
| TC-AI-03 | Grade speaking via EduBot bridge → callback result | High | Feature matrix |
| TC-AI-04 | Generate material dengan quota cukup | High | R-AI-02 |
| TC-AI-05 | Generate material dengan quota habis → QUOTA_EXCEEDED | High | R-AI-01 |
| TC-AI-06 | Content validation reject material tidak valid | High | R-AI-02 |
| TC-AI-07 | AI quota reset di awal bulan | Medium | R-AI-01 |
| TC-AI-08 | Ambassador/Pro/Partner mendapat unlimited quota | High | R-AI-01 |
| TC-AI-09 | Grading queue process pending entries | High | R-AI-03 |
| TC-AI-10 | Grading queue failure → status failed | High | R-AI-03 |

### 6.5 Commission System

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-COM-01 | First practice test → commission ledger entry Rp 10.000 | Critical | R-FIN-01 |
| TC-COM-02 | First practice test dipanggil 2× → hanya 1 ledger entry | Critical | R-FIN-01 |
| TC-COM-03 | Official booking → commission Rp 50.000 | Critical | R-FIN-01 |
| TC-COM-04 | Ambassador first test → Rp 20.000 | High | R-FIN-01 |
| TC-COM-05 | Student tanpa referral → tidak ada commission | High | R-FIN-01 |
| TC-COM-06 | Recurring premium credit bulanan | Critical | R-FIN-02 |
| TC-COM-07 | Recurring premium tidak double-credit | Critical | R-FIN-02 |
| TC-COM-08 | Payout request melebihi pending balance → ditolak | Critical | R-FIN-03 |
| TC-COM-09 | Payout request valid → pending payout created | High | R-FIN-03 |
| TC-COM-10 | Admin approve payout → status paid | High | R-FIN-03 |
| TC-COM-11 | Quota bonus +5 untuk student registered | Medium | Feature matrix |
| TC-COM-12 | Quota bonus tidak duplikat untuk event sama | High | R-AI-04 |

### 6.6 Orders & Payments

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-ORD-01 | Create order self_purchase dengan harga valid | High | R-ORD-01 |
| TC-ORD-02 | Create order voucher_resale dengan role teacher | High | R-ORD-01 |
| TC-ORD-03 | TriPay payment initiation → merchant URL | Critical | R-FIN-04 |
| TC-ORD-04 | TriPay webhook valid signature → order paid | Critical | R-FIN-04 |
| TC-ORD-05 | TriPay webhook invalid signature → rejected | Critical | R-FIN-04 |
| TC-ORD-06 | Order paid → voucher generated | High | R-ORD-01 |
| TC-ORD-07 | Order fulfilled → booking_confirmed | High | R-ORD-01 |
| TC-ORD-08 | Cancel order pending → status cancelled | Medium | R-ORD-01 |
| TC-ORD-09 | Admin mark-paid → status paid tanpa double fulfillment | High | R-ORD-02 |
| TC-ORD-10 | Bulk purchase tanpa assigned student → pending_assignment | High | R-ORD-03 |
| TC-ORD-11 | Voucher redeem → status redeemed | High | R-FIN-05 |
| TC-ORD-12 | Voucher redeem 2× → error | High | R-FIN-05 |

### 6.7 Webhooks

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-WEB-01 | Webhook ibt dengan secret valid → accepted | Critical | R-WEB-01 |
| TC-WEB-02 | Webhook ibt tanpa secret → 401 | Critical | R-WEB-01 |
| TC-WEB-03 | Webhook ibt dengan secret salah → 401 | Critical | R-WEB-01 |
| TC-WEB-04 | Webhook payload disimpan di `webhook_events` | High | Feature matrix |
| TC-WEB-05 | Cron process webhook batch → update progress & commission | High | R-WEB-02 |
| TC-WEB-06 | Webhook processing gagal → retry_count bertambah | High | R-WEB-02 |
| TC-WEB-07 | Webhook replay dengan ID sama → idempotent | High | R-WEB-02 |
| TC-WEB-08 | Webhook payload variasi per platform | Medium | R-WEB-03 |

### 6.8 Admin Portal

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-ADM-01 | Admin list users dengan role filter | High | R-AUTH-05 |
| TC-ADM-02 | Non-admin akses admin route → 403 | High | R-AUTH-05 |
| TC-ADM-03 | Set commission rates | High | R-FIN-01 |
| TC-ADM-04 | Approve/reject payout | High | R-FIN-03 |
| TC-ADM-05 | Promote/revoke ambassador | High | AMBASSADOR.md |
| TC-ADM-06 | Upload & embed knowledge base document | Medium | Feature matrix |
| TC-ADM-07 | Create video course & lesson | Medium | Feature matrix |
| TC-ADM-08 | Create live class | Medium | Feature matrix |
| TC-ADM-09 | Order management: refund, retry, cancel, mark paid | High | R-ORD-02 |

### 6.9 Partner / Institution

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-PAR-01 | Partner invite teacher by email → token generated | High | Feature matrix |
| TC-PAR-02 | Teacher accept invite → linked to partner | High | Feature matrix |
| TC-PAR-03 | Partner melihat commission aggregated teachers | Medium | Feature matrix |
| TC-PAR-04 | Partner tidak melihat teacher institusi lain | High | R-AUTH-02 |

### 6.10 Branding & White-Label

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-BRN-01 | Get branding config untuk teacher | Medium | Feature matrix |
| TC-BRN-02 | Update branding dengan logo/color | Medium | Feature matrix |
| TC-BRN-03 | Upgrade tier free → pro | Medium | Feature matrix |
| TC-BRN-04 | Cancel pro tier → free | Medium | Feature matrix |

### 6.11 Frontend Admin

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-FE-01 | Login flow: render login → set token → render dashboard | High | R-FE-01 |
| TC-FE-02 | Dashboard menampilkan stats dari API | High | R-FE-01 |
| TC-FE-03 | 401 response → redirect ke login | High | R-FE-02 |
| TC-FE-04 | Commission page: edit rates & save | Medium | R-FE-01 |
| TC-FE-05 | Orders page: refund/retry/cancel buttons | Medium | R-FE-01 |
| TC-FE-06 | Knowledge base upload & embed | Medium | R-FE-01 |

### 6.12 Production Readiness

| ID | Test Case | Prioritas | Traceability |
|---|---|---|---|
| TC-OPS-01 | `npm run typecheck` worker hijau | Critical | R-OPS-01 |
| TC-OPS-02 | `npm test` worker hijau | Critical | R-OPS-01 |
| TC-OPS-03 | Cron handler isolasi error antar job | High | R-OPS-02 |
| TC-OPS-04 | Health check memeriksa koneksi Supabase | High | R-OPS-06 |
| TC-OPS-05 | Rate limiter mengembalikan 429 saat bucket kosong | Medium | R-OPS-03 |
| TC-OPS-06 | Error handler mengembalikan INTERNAL_ERROR tanpa leak stack | Medium | R-OPS-04 |
| TC-OPS-07 | Deployment checklist lengkap (secrets, schema, DNS, webhooks) | High | docs/DEPLOYMENT.md |
| TC-OPS-08 | Rollback procedure tersedia dan teruji | High | R-DB-03 |

## 7. Traceability ke Risk Register

Setiap risiko Critical/High dari `risk-register.md` harus memiliki test case:

| Risk ID | Test Case IDs |
|---|---|
| R-FIN-01 | TC-COM-01, TC-COM-02, TC-COM-03, TC-COM-04, TC-COM-05, TC-ADM-03 |
| R-FIN-02 | TC-COM-06, TC-COM-07 |
| R-FIN-03 | TC-COM-08, TC-COM-09, TC-COM-10, TC-ADM-04 |
| R-FIN-04 | TC-ORD-03, TC-ORD-04, TC-ORD-05 |
| R-FIN-05 | TC-ORD-11, TC-ORD-12 |
| R-AUTH-01 | TC-AUTH-01, TC-AUTH-02, TC-AUTH-03, TC-AUTH-04 |
| R-AUTH-02 | TC-TCH-03, TC-TCH-04, TC-PAR-04 |
| R-AUTH-05 | TC-ADM-01, TC-ADM-02 |
| R-WEB-01 | TC-WEB-01, TC-WEB-02, TC-WEB-03 |
| R-WEB-02 | TC-WEB-05, TC-WEB-06, TC-WEB-07 |
| R-AI-01 | TC-AI-05, TC-AI-07, TC-AI-08 |
| R-AI-02 | TC-AI-04, TC-AI-06 |
| R-AI-03 | TC-AI-09, TC-AI-10 |
| R-AI-04 | TC-COM-11, TC-COM-12 |
| R-ORD-01 | TC-ORD-01, TC-ORD-02, TC-ORD-06, TC-ORD-07 |
| R-ORD-02 | TC-ORD-09, TC-ADM-09 |
| R-ORD-03 | TC-ORD-10 |
| R-OPS-01 | TC-OPS-01, TC-OPS-02 |
| R-OPS-02 | TC-OPS-03 |
| R-OPS-06 | TC-OPS-04 |
| R-EXT-01 | TC-AI-03, TC-WEB-08 |
| R-EXT-03 | TC-TCH-09, TC-TCH-10 |
| R-FE-01 | TC-FE-01, TC-FE-02, TC-FE-04, TC-FE-05, TC-FE-06 |
| R-FE-02 | TC-FE-03 |

## 8. Kriteria Masuk & Keluar

### 8.1 Entry Criteria

- [ ] Semua source code tersedia dan bisa di-build
- [ ] Test environment tersedia dengan Supabase test instance
- [ ] Mock untuk external dependencies tersedia
- [ ] Baseline test dan typecheck sudah tercatat

### 8.2 Exit Criteria (Go-Live Readiness)

- [ ] Typecheck worker dan frontend-admin hijau
- [ ] Test suite worker dan frontend-admin hijau (0 failure)
- [ ] Seluruh Critical dan High risk memiliki test case yang pass
- [ ] Commission idempotency test pass
- [ ] Order fulfillment state machine test pass
- [ ] Webhook signature verification test pass
- [ ] Auth role escalation negative test pass
- [ ] Deployment checklist di `docs/DEPLOYMENT.md` sudah dijalankan di staging
- [ ] Health check mencakup dependency readiness
- [ ] Rollback procedure sudah diuji minimal sekali
- [ ] Tidak ada hardcoded secret di source code
- [ ] Flutter app sudah diimplementasikan (jika termasuk deliverable)

## 9. Baseline Saat Ini

| Metric | Worker | Frontend-Admin |
|---|---|---|
| Typecheck | ✅ pass | ✅ pass |
| Tests | ✅ 225 passed | ✅ 14 passed |
| Build | ✅ `build:admin` berhasil | ✅ `build:admin` berhasil |
| Route test coverage | 2/18 files | N/A |
| Service test coverage | 18/35 files | N/A |
| Page test coverage | N/A | 1/11 files |

### Issue Terbuka yang Harus Ditangani

1. **Flutter implementation:** tidak ada source Flutter dalam repo (jika termasuk deliverable)
2. **Missing tests:** route-level tests untuk 16 route files, service tests untuk 17 service files
3. **Security/RLS:** worker memakai service key yang bypass RLS — semua authorization harus di route/service
4. **External integrations:** mock-only; perlu staging access untuk integration test nyata
5. **Production readiness:** health check masih static; perlu dependency checks

## 10. Edge Case Fixes Setelah Review

Berdasarkan hasil Edge Case Hunter Review, perbaikan berikut sudah diimplementasikan:

| Edge Case | File | Perbaikan |
|---|---|---|
| `user.email` kosong sebelum kirim TriPay | `worker/src/routes/orders.ts` | Validasi email, fetch `display_name`, tambah `return_url` |
| Dashboard silent catch DB error | `worker/src/routes/teacher.ts` | Log error + fallback graceful, `.trim()` display name |
| Report email 502 saat profile fetch gagal | `worker/src/routes/teacher.ts` | Fallback ke `user.email` dan tetap kirim email |
| Catalog GET unhandled rejection | `worker/src/routes/teacher.ts` | Wrap query dalam try/catch, return 500 error |
| Catalog GET `limit` NaN/negative | `worker/src/routes/teacher.ts` | Validasi limit: default 100, min 1, max 200 |
| Builtin catalog abaikan exam filter | `worker/src/routes/teacher.ts` | Terapkan exam filter pada fallback builtin |
| Catalog POST tanpa role guard | `worker/src/routes/teacher.ts` | Hanya teacher/partner/admin boleh create |
| Catalog POST item_type tidak valid | `worker/src/routes/teacher.ts` | Validasi terhadap schema enum |
| Catalog POST difficulty tidak valid | `worker/src/routes/teacher.ts` | Validasi A1-C2 regex |
| Catalog POST estimated_minutes invalid | `worker/src/routes/teacher.ts` | Validasi integer positif |
| Catalog POST tags/exam_types non-array | `worker/src/routes/teacher.ts` | Validasi array of strings |
| `buildChainById` null tanpa eq | `worker/src/routes/teacher.test.ts` | Tambah `defaultData` parameter |

## 11. Rekomendasi Lanjutan

### 10.1 Test Automation

- Tambahkan route-level tests untuk setiap file di `worker/src/routes/`
- Tambahkan E2E tests untuk frontend admin menggunakan Playwright/Cypress
- Implementasikan contract tests untuk webhook payloads dari 6 platform

### 10.2 Security

- Audit penggunaan `SUPABASE_SERVICE_KEY` vs `SUPABASE_ANON_KEY`
- Pertimbangkan rotasi webhook secrets dan EduBot internal secret
- Implementasikan structured logging dengan correlation ID
- Tambahkan CSP dan security headers untuk frontend-admin

### 10.3 Production Readiness

- Perluas health check untuk memeriksa Supabase, OpenAI, TriPay connectivity
- Implementasikan proper monitoring/alerting untuk cron failures
- Siapkan runbook incident response

### 10.4 Flutter

- Jika mobile/web app termasuk deliverable, segera implementasikan karena saat ini hanya ada README dan vendor package.

## 11. Lampiran

- `feature-gap-matrix.md` — daftar lengkap fitur vs implementasi
- `risk-register.md` — daftar lengkap risiko dan mitigation
- `docs/API.md` — API reference
- `docs/DEPLOYMENT.md` — deployment guide
- `docs/TESTING.md` — testing conventions

## 12. Approval

| Peran | Nama | Tanggal | Status |
|---|---|---|---|
| Test Architect | — | — | Draft |
| Product Owner | — | — | TBD |
| Tech Lead | — | — | TBD |

---

*Dokumen ini disusun dalam mode Build dengan tidak mengubah source code. Semua kode tetap read-only selama audit.*
