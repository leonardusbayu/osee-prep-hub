## Context

Integrasi ITP↔Hub sudah terbangun sebelum eksplorasi ini (jejak: test users di kedua DB, migration SQL, `.sisyphus` plans). Eksplorasi 2026-09-11 memverifikasi seluruh komponen hidup dan terhubung. Dokumen ini mencapture arsitektur terverifikasi + keputusan operasional yang muncul dari verifikasi.

Arsitektur terverifikasi (3 sisi):

```
prep.osee.co.id (Hub, Cloudflare Worker)
  ├─ POST /api/webhook/itp      X-Webhook-Secret → webhook_events → cron processor
  │                               → updateStudentProgress → itp_latest_score dll.
  │                               → commission + quota + readiness + EduBot notify
  └─ POST /api/auth/verify      → { valid, user{email, display_name} }

test.osee.co.id (ITP, PHP)
  ├─ sso.php + includes/sso_helper.php     (cookie osee_token | ?osee_token=)
  ├─ includes/hub_webhook.php              (notifyHubTestCompletion, exam-only)
  └─ user/result.php:117                   (wiring titik panggil)

Flutter student portal
  └─ platform_links_page.dart:142 — append ?osee_token= ke URL yang mengandung "sso"
```

Kontrak payload webhook (cocok 100%, diverifikasi live):
`{event_type: "test_completed", user_email, data: {score, total_score, section_scores{listening,structure,reading}, test_session, duration_minutes, timestamp}}`

## Goals / Non-Goals

**Goals:**
- Membuat state terverifikasi + checklist produksi durable (dokumen ini + tasks.md).
- Keputusan mitigasi risiko pause Supabase.

**Non-Goals:**
- Menulis kode integrasi baru — tidak ada yang perlu ditulis.
- Replikasi pola ke IBT/IELTS/TOEIC — diulang nanti per platform, di luar change ini.
- Perubahan skema DB — tidak ada.

## Decisions

1. **`skip_specs: true`** — tidak ada perubahan perilaku spec-level; kode integrasi sudah ada dan terverifikasi. Alternatif (menulis spec retroaktif untuk webhook/SSO) ditunda sampai replikasi ke platform berikutnya, saat akan lebih bernilai.
2. **Mitigasi pause Supabase: sadari + monitor, jangan upgrade sekarang** — free tier pause setelah ~7 hari idle; webhook gagal diam-diam saat pause (gejala: `STORE_FAILED internal error`). Upgrade tier hanya jika frekuensi pause mengganggu produksi nyata. Alternatif: cron ping eksternal (belum dibutuhkan).
3. **Secret dev `dev-itp-webhook-secret` tetap default lokal** — sudah match antara `worker/.dev.vars` dan default `includes/config.php` ITP. Untuk prod, secret harus diganti dan disamakan via env (Cloudflare secret + Railway env).
4. **Verifikasi runtime dari terminal pengguna, bukan agent** — egress HTTPS mesin ke `*.supabase.co` diblokir lapisan sandbox (DNS+TCP 443 hang; terbukti bukan masalah Supabase karena pause+restore cycle tidak mengubah perilaku dan direct-DB via MCP sukses). Worker lokal + `wrangler dev` di mesin pengguna berjalan normal.

## Risks / Trade-offs

- [Supabase auto-pause (free tier)] → produksi diam-diam gagal saat pause; deteksi: dashboard/status; mitigasi jangka panjang: upgrade plan atau keep-alive job — diputuskan belakangan.
- [Deploy prod status tidak diketahui] → DB sempat pause mengindikasikan belum ada trafik prod yang menjaganya; verifikasi `prep.osee.co.id` di luar change ini.
- [Rencana IBT nanti] → pola sama bisa direplikasi; IBT pakai Supabase auth sendiri sehingga SSO-nya lebih kompleks dari ITP (PHP cookie). Ditunda.

## Migration Plan

Tidak ada migrasi kode/schema. Sisa operasional ada di tasks.md (set secrets/env prod, test SSO di browser, kebersihan antrian test).

## Open Questions

- Status deploy aktual `prep.osee.co.id` (ada/tidak, project Supabase mana yang dipakai) — diverifikasi terpisah.