# Feature Gap Matrix — OSEE Prep Hub

## Ringkasan Eksekutif

Dokumen ini memetakan setiap fitur utama yang disebutkan dalam `BLUEPRINT.md` dan dokumen pendamping terhadap implementasi aktual di codebase. Tujuannya adalah mengidentifikasi fitur yang sudah lengkap, sebagian, atau belum tersedia, sebagai dasar untuk perencanaan pengujian sistem.

## Sumber yang Digunakan

- `BLUEPRINT.md` (semua section)
- `docs/API.md`
- `docs/COMMISSION.md`
- `docs/AMBASSADOR.md`
- `docs/DEPLOYMENT.md`
- `docs/TESTING.md`
- `schema.sql`
- `worker/src/index.ts`
- `worker/src/routes/*.ts` (18 route files)
- `worker/src/services/*.ts` (35 service files)
- `frontend-admin/src/pages/*.tsx` (11 pages)

## Status Umum

| Komponen | Total | Memiliki Test | Coverage Test |
|---|---:|---:|---:|
| Worker route files | 18 | 2 | 11% |
| Worker service files | 35 | 18 | 51% |
| Frontend-admin pages | 11 | 1 | 9% |

## Matriks Fitur

| Domain | Fitur | Referensi Blueprint | Status Implementasi | Lokasi Kode | Test | Catatan Gap |
|---|---|---|---|---|---|---|
| **1. Auth & SSO** | Register email/password | Blueprint §5, API §Auth | Implemented | `worker/src/routes/auth.ts` | `auth.test.ts` | — |
| | Login + JWT issuance | Blueprint §3, API §Auth | Implemented | `worker/src/routes/auth.ts`, `services/jwt.ts`, `services/cookie.ts` | `jwt.test.ts` | Cookie domain `.osee.co.id` belum diverifikasi konfigurasi production. |
| | Verify JWT | API §Auth | Implemented | `worker/src/routes/auth.ts` | `auth.test.ts` | — |
| | Refresh token | API §Auth | Implemented | `worker/src/routes/auth.ts` | Partial | Perlu verifikasi expiry/rotation. |
| | Logout / clear cookie | API §Auth | Implemented | `worker/src/routes/auth.ts`, `services/cookie.ts` | No | — |
| | Link Telegram (EduBot bridge) | Blueprint §3, API §Auth | Implemented | `worker/src/routes/auth.ts` | No | — |
| | SSO across *.osee.co.id | Blueprint §3 | Partial | `services/cookie.ts` | No | Cross-domain cookie logic ada tapi belum diuji E2E. |
| **2. Teacher Portal** | Dashboard stats | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/teacher.ts` | No | — |
| | Create/list classrooms | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/classroom.ts` | `classroom.test.ts` | — |
| | Classroom detail + students | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/classroom.ts` | No | — |
| | Add students by email | API §Teacher | Implemented | `worker/src/routes/teacher.ts` | No | — |
| | Referral code | API §Teacher | Implemented | `worker/src/routes/teacher.ts` | No | — |
| | Syllabus CRUD | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/syllabus.ts` | `syllabus.test.ts` | — |
| | Syllabus item batch save | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/syllabus.ts` | No | — |
| | Material catalog | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/catalog.ts` | No | — |
| | Student report (JSON/HTML) | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/reports.ts`, `services/pdf.ts` | `reports.test.ts` | Email report route mengembalikan 502 di test. |
| | Classroom report | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/reports.ts` | No | — |
| | Batch report | API §Teacher | Implemented | `worker/src/routes/teacher.ts` | No | — |
| | Teacher effectiveness | API §Teacher | Implemented | `worker/src/routes/teacher.ts` | No | — |
| | Teacher pricing | API §Teacher | Implemented | `worker/src/routes/teacher.ts`, `services/pricing.ts` | `pricing.test.ts` | — |
| **3. Student Portal** | Dashboard | API §Student | Implemented | `worker/src/routes/student.ts` | No | — |
| | Progress across platforms | API §Student | Implemented | `worker/src/routes/student.ts`, `services/student-progress.ts` | No | — |
| | Join classroom via code | API §Student | Implemented | `worker/src/routes/student.ts`, `services/classroom.ts` | No | — |
| | Syllabus assigned + start/complete item | API §Student | Implemented | `worker/src/routes/student.ts` | No | — |
| | Readiness gauge | API §Student | Implemented | `worker/src/routes/student.ts`, `services/readiness.ts` | No | — |
| | Cross-exam score map | API §Student | Implemented | `worker/src/routes/student.ts` | No | View & seed data ada. |
| | Book test CTA | API §Student | Implemented | `worker/src/routes/student.ts` | No | Deep link only. |
| **4. AI Services** | RAG search | API §AI, Blueprint §7 | Implemented | `worker/src/routes/ai.ts`, `services/rag-search.ts` | `rag-search.test.ts` | — |
| | RAG upload to KB | API §AI | Implemented | `worker/src/routes/ai.ts`, `services/knowledge-base.ts` | No | — |
| | Grade writing | API §AI, Blueprint §8 | Implemented | `worker/src/routes/ai.ts`, `services/ai-grading.ts` | `ai-grading.test.ts` | — |
| | Grade speaking (EduBot bridge) | API §AI, Blueprint §8 | Implemented | `worker/src/routes/ai.ts`, `services/speaking-bridge.ts` | `speaking-bridge.test.ts` | — |
| | Generate material | API §AI, Blueprint §8 | Implemented | `worker/src/routes/ai.ts`, `services/ai-generation.ts` | `ai-generation.test.ts` | — |
| | Grading queue + cron processing | API §AI | Implemented | `worker/src/routes/ai.ts`, `services/grading-queue.ts` | No | Queue processing belum memiliki test. |
| | Quota status/check | API §AI, Blueprint §6 | Implemented | `worker/src/routes/ai.ts`, `services/quota.ts` | `quota.test.ts` | Logic hitung quota memiliki fallback yang tidak deterministik. |
| | Content validation | Blueprint §8 | Implemented | `services/content-validator.ts` | `content-validator.test.ts` | — |
| **5. Commission System** | Record commission from webhooks | Blueprint §9, COMMISSION.md | Implemented | `worker/src/services/commission.ts`, `services/webhook-processor.ts` | `webhook-processor.test.ts` | Idempotensi dasar ada; recurring premium terpisah. |
| | Teacher commission dashboard | API §Commission | Implemented | `worker/src/routes/commission.ts`, `services/commission-dashboard.ts` | No | — |
| | Payout request | API §Commission | Implemented | `worker/src/routes/commission.ts`, `services/commission-dashboard.ts` | No | Payout tidak mengurangi pending amount saat create request (hanya verifikasi). |
| | Payout history | API §Commission | Implemented | `worker/src/routes/commission.ts`, `services/commission-dashboard.ts` | No | — |
| | Admin commission summary | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/admin-stats.ts` | `admin-stats.test.ts` | — |
| | Admin commission rates | API §Admin | Implemented | `worker/src/routes/admin.ts` | No | — |
| | Recurring premium commission | COMMISSION.md | Implemented | `worker/src/services/premium-recurring.ts` | No | Belum ada test. |
| | Quota bonus for referrals | COMMISSION.md | Implemented | `worker/src/services/quota.ts` | No | Bonus logic ada tapi perlu verifikasi end-to-end. |
| **6. Orders & Payments** | Create order | API §Orders | Implemented | `worker/src/routes/orders.ts`, `services/orders.ts` | `orders.test.ts` | — |
| | List/order detail | API §Orders | Implemented | `worker/src/routes/orders.ts`, `services/orders.ts` | No | — |
| | Cancel order | API §Orders | Implemented | `worker/src/routes/orders.ts`, `services/orders.ts` | No | — |
| | Initiate TriPay payment | API §Orders | Implemented | `worker/src/routes/orders.ts`, `services/tripay.ts` | No | — |
| | TriPay webhook | API §Orders | Implemented | `worker/src/routes/orders.ts`, `services/tripay.ts` | No | Webhook signature verification perlu diuji. |
| | Voucher validation/redeem | API §Vouchers | Implemented | `worker/src/routes/voucher.ts`, `services/voucher.ts` | `voucher.test.ts` | — |
| | Pricing config | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/pricing.ts` | `pricing.test.ts` | — |
| | Booking bridge (osee.co.id) | Blueprint §3 | Implemented | `worker/src/services/booking-bridge.ts` | No | Belum ada test; mock-only. |
| **7. Webhooks** | ibt webhook | API §Webhook | Implemented | `worker/src/routes/webhook.ts` | No | Mock-only. |
| | itp webhook | API §Webhook | Implemented | `worker/src/routes/webhook.ts` | No | Mock-only. |
| | ielts webhook | API §Webhook | Implemented | `worker/src/routes/webhook.ts` | No | Mock-only. |
| | toeic webhook | API §Webhook | Implemented | `worker/src/routes/webhook.ts` | No | Mock-only. |
| | booking webhook | API §Webhook | Implemented | `worker/src/routes/webhook.ts` | No | Mock-only. |
| | edubot webhook | API §Webhook | Implemented | `worker/src/routes/webhook.ts` | No | Mock-only. |
| | Webhook batch processing | Blueprint §3 | Implemented | `worker/src/services/webhook-processor.ts` | `webhook-processor.test.ts` | Ada test failure karena shape return berubah. |
| | Webhook auth (secret) | API §Webhook | Implemented | `worker/src/middleware/webhook-auth.ts` | `webhook-auth.test.ts` | — |
| **8. Video Content** | List courses | API §Video | Implemented | `worker/src/routes/video.ts`, `services/video.ts` | No | — |
| | Course detail + lessons | API §Video | Implemented | `worker/src/routes/video.ts`, `services/video.ts` | No | — |
| | Lesson progress | API §Video | Implemented | `worker/src/routes/video.ts`, `services/video.ts` | No | — |
| | Admin CRUD courses/lessons | API §Video | Implemented | `worker/src/routes/video.ts` | No | — |
| | R2 upload video | API §Upload | Implemented | `worker/src/routes/upload.ts`, `services/r2.ts` | `r2.test.ts` | — |
| **9. Live Classes** | Upcoming classes | API §Classes | Implemented | `worker/src/routes/classes.ts`, `services/live-class.ts` | No | — |
| | Class registration | API §Classes | Implemented | `worker/src/routes/classes.ts`, `services/live-class.ts` | No | — |
| | Admin create/update/cancel | API §Classes | Implemented | `worker/src/routes/classes.ts`, `services/live-class.ts` | No | — |
| | Cron reminders | API §Classes | Implemented | `worker/src/services/live-class.ts` | No | — |
| | Telegram notifications | Blueprint §11 | Partial | `worker/src/services/live-class.ts` | No | Logic ada tapi belum diuji. |
| **10. Admin Portal** | Admin stats | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/admin-stats.ts` | `admin-stats.test.ts` | — |
| | Admin analytics | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/admin-stats.ts` | No | — |
| | Users/Teachers/Students list | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/admin-stats.ts` | No | — |
| | Pricing management | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/pricing.ts` | No | — |
| | Commission rates & payouts | API §Admin | Implemented | `worker/src/routes/admin.ts` | No | — |
| | Ambassador promote/revoke | API §Admin, AMBASSADOR.md | Implemented | `worker/src/routes/admin.ts`, `services/ambassador.ts` | No | — |
| | Orders management | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/orders.ts` | No | — |
| | Material catalog management | API §Admin | Implemented | `worker/src/routes/admin.ts` | No | — |
| | Knowledge base upload/embed | API §Admin | Implemented | `worker/src/routes/admin.ts`, `services/knowledge-base.ts` | No | — |
| **11. Partner/Institution** | Partner dashboard | API §Partner | Implemented | `worker/src/routes/partner.ts`, `services/partner.ts` | No | — |
| | Teacher invitations | API §Partner | Implemented | `worker/src/routes/partner.ts`, `services/teacher-invitations.ts` | `teacher-invitations.test.ts` | — |
| | Partner commission | API §Partner | Implemented | `worker/src/routes/partner.ts`, `services/commission-dashboard.ts` | No | — |
| **12. Branding & White-Label** | Get branding config | API §Branding | Implemented | `worker/src/routes/branding.ts`, `services/branding.ts` | No | — |
| | Update branding | API §Branding | Implemented | `worker/src/routes/branding.ts`, `services/branding.ts` | No | — |
| | Upgrade/cancel tier | API §Branding | Implemented | `worker/src/routes/branding.ts`, `services/branding.ts` | No | — |
| **13. Ambassador** | Ambassador dashboard | AMBASSADOR.md | Implemented | `worker/src/routes/ambassador.ts`, `services/ambassador.ts` | No | — |
| | Proposal document | AMBASSADOR.md | Implemented | `worker/src/services/ambassador.ts` | No | — |
| **14. Reports** | Student report | Blueprint §8 | Implemented | `worker/src/routes/reports.ts`, `services/reports.ts`, `services/pdf.ts` | `reports.test.ts` | Email route 502 di test. |
| | Classroom report | Blueprint §8 | Implemented | `worker/src/routes/reports.ts`, `services/reports.ts` | No | — |
| | Batch student reports | Blueprint §8 | Implemented | `worker/src/routes/teacher.ts`, `services/reports.ts` | No | — |
| **15. External/EduBot Bridge** | Verify student | API §External | Implemented | `worker/src/routes/external.ts`, `services/edubot-bridge.ts` | No | — |
| | Receive student progress | API §External | Implemented | `worker/src/routes/external.ts`, `services/edubot-bridge.ts` | No | — |
| | Teacher syllabus deep links | API §External | Implemented | `worker/src/routes/external.ts`, `services/edubot-bridge.ts` | No | — |
| | Student deep links | API §External | Implemented | `worker/src/routes/external.ts`, `services/edubot-bridge.ts` | No | — |
| **16. Frontend Admin** | Dashboard | — | Implemented | `frontend-admin/src/pages/Dashboard.tsx` | `pages.test.tsx` | — |
| | Analytics | — | Implemented | `frontend-admin/src/pages/Analytics.tsx` | No | — |
| | Users | — | Implemented | `frontend-admin/src/pages/Users.tsx` | No | — |
| | Teachers | — | Implemented | `frontend-admin/src/pages/Teachers.tsx` | No | — |
| | Students | — | Implemented | `frontend-admin/src/pages/Students.tsx` | No | — |
| | Commission | — | Implemented | `frontend-admin/src/pages/Commission.tsx` | No | — |
| | Orders | — | Implemented | `frontend-admin/src/pages/Orders.tsx` | No | — |
| | Pricing | — | Implemented | `frontend-admin/src/pages/Pricing.tsx` | No | — |
| | Materials | — | Implemented | `frontend-admin/src/pages/Materials.tsx` | No | — |
| | Knowledge Base | — | Implemented | `frontend-admin/src/pages/KnowledgeBase.tsx` | No | — |
| | Ambassadors | — | Implemented | `frontend-admin/src/pages/Ambassadors.tsx` | No | — |
| | Login/auth flow | — | Implemented | `frontend-admin/src/api/client.ts` | `pages.test.tsx` | — |
| **17. Flutter** | Mobile/web app | Blueprint §6 | Not Implemented | — | — | Tidak ada source Flutter yang diimplementasikan dalam repo ini (hanya `flutter/README.md` dan vendor). |

## Kesimpulan Feature Completeness

- **Backend Worker:** Mayoritas endpoint blueprint telah diimplementasikan. Area yang belum memiliki test cukup banyak: route-level tests hanya 2 dari 18 file. Service-level tests lebih baik (18/35) tapi masih ada service kritis tanpa test: `commission-dashboard.ts`, `commission.ts`, `premium-recurring.ts`, `tripay.ts`, `branding.ts`, `live-class.ts`, `video.ts`, `partner.ts`, `grading-queue.ts`, `student-progress.ts`, `edubot-bridge.ts`, `booking-bridge.ts`, `pdf.ts`.
- **Frontend Admin:** Semua 11 halaman admin telah diimplementasikan. Test coverage sangat rendah (1 file test untuk seluruh pages).
- **Flutter:** Tidak ada implementasi Flutter dalam repo ini (hanya README dan package vendor). Ini adalah gap besar jika mobile/web app dianggap bagian dari deliverable.
- **External integrations:** Semua webhook dari platform eksternal hanya dapat diuji dengan mock.

## Baseline Typecheck & Test

| Komponen | Typecheck | Test |
|---|---|---|
| Worker | ❌ 3 errors | ❌ 3 failed, 222 passed |
| Frontend-admin | ✅ pass | ✅ pass (dengan warning) |

### Worker Typecheck Errors (RESOLVED)

Setelah perbaikan, semua typecheck error worker sudah terselesaikan:

- `src/routes/orders.ts(155,12)`: removed unused `profileResult` destructuring
- `src/routes/teacher.ts(347,20)` & `(353,23)`: restructured to fetch profile before sending email (menghindari TDZ / `any` type)

### Worker Test Failures (RESOLVED)

Setelah perbaikan, semua test worker sudah pass:

- `src/routes/teacher.test.ts` — POST `/students/:id/report/email` sekarang mengembalikan 200 (happy path & email override). Penyebab: temporal dead zone `profileResult` yang sekarang sudah diperbaiki di route.
- `src/services/webhook-processor.test.ts` — ekspektasi return shape sudah diupdate untuk menyertakan field `dead`.
