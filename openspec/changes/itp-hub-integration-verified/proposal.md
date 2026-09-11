## Why

Integrasi ITP (test.osee.co.id) ↔ OSEE Prep Hub ternyata sudah dibangun lengkap di sesi-sesi sebelumnya (SSO, webhook sender, processor), tapi status live-nya tidak diketahui dan tidak terdokumentasi. Saat dieksplorasi, database Supabase terbukti sedang pause (penyebab "koneksi mati" yang diam-diam), dan rantai E2E belum pernah diverifikasi secara nyata. Eksplorasi 2026-09-11 memverifikasi seluruh rantai end-to-end dengan data nyata — perlu dicapture agar state terverifikasi dan sisa pekerjaan produksi tidak hilang.

## What Changes

- **Tidak ada kode baru** — integrasi ITP↔Hub terverifikasi 100% lengkap di 3 sisi (hub worker, ITP PHP lokal, Flutter student portal).
- Verifikasi E2E terdokumentasi: webhook `POST /api/webhook/itp` (202) → cron processor → `student_progress_unified` terisi (`itp_latest_score=513`, section scores, practice_count).
- Checklist produksi tersisa diproduksi: secrets Cloudflare + env Railway ITP.
- Keputusan operasional diambil: mitigasi risiko auto-pause Supabase free tier.
- Sisa antrian: 1 event test (`smoke-final`) akan terproses cron berikutnya — bersihkan atau biarkan.

## Capabilities

### New Capabilities

(none — verifikasi + operasional, tidak ada perubahan perilaku spec-level; integrasi sudah ada di kode)

### Modified Capabilities

(none)

## Impact

- `worker/.dev.vars` — sudah benar, menunjuk project Supabase `prxzxecxwjsayeueijla`.
- Cloudflare secrets (prod) — perlu verifikasi/set: `WEBHOOK_SECRET_ITP` (dan platform lain), `EDUBOT_INTERNAL_SECRET`.
- Railway env ITP (prod) — perlu set: `HUB_API_URL=https://prep.osee.co.id`, `WEBHOOK_SECRET_ITP=<secret sama>`.
- Supabase project free tier — risiko pause ~7 hari idle; webhook diam-diam gagal saat pause.
- Catatan lingkungan: egress HTTPS dari mesin dev ke `*.supabase.co` diblokir di sandbox agent (bukan di jaringan pengguna) — verifikasi runtime agent-side tidak mungkin, dilakukan dari terminal pengguna.