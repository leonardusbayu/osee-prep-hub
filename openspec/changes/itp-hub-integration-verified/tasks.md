## 1. Verifikasi produksi

- [x] 1.1 Cek status deploy `prep.osee.co.id` (Cloudflare dashboard / `npx wrangler deployments list`) — konfirmasi worker prod ada dan project Supabase mana yang dipakai
- [x] 1.2 Verifikasi/set secrets Cloudflare prod: `WEBHOOK_SECRET_ITP`, `EDUBOT_INTERNAL_SECRET`, `JWT_SECRET`, `SUPABASE_*` (nilai sama dengan yang dipakai DB aktif)
- [ ] 1.3 Set env Railway ITP (prod): `HUB_API_URL=https://prep.osee.co.id`, `WEBHOOK_SECRET_ITP=<nilai sama dengan Cloudflare>`
- [ ] 1.4 Test SSO prod di browser: login di prep.osee.co.id → klik link "OSEE ITP Practice" → harus auto-login tanpa login kedua

## 2. Kebersihan & operasional

- [x] 2.1 Trigger cron sekali lagi (`curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*/1+*+*+*+*"`) untuk memproses sisa event `smoke-final` — lalu konfirmasi `webhook_events` kosong (processed semua) → hasil: semua processed, practice_count=2, skor 513
- [x] 2.2 (Opsional) Bersihkan data smoke test: reset `itp_latest_score` demo.student ke null atau biarkan sebagai jejak test → diputuskan: biarkan sebagai jejak test
- [x] 2.3 Putuskan mitigasi pause Supabase: monitor saja, atau upgrade plan — revisit saat trafik prod nyata → diputuskan: monitor saja (design decision #2)
- [ ] 2.4 Commit capture ini (proposal/design/tasks) ke repo

## 3. Replikasi berikutnya (di luar change ini — jangan eksekusi di change ini)

- [ ] 3.1 (Opsional, nanti) Replikasi pola SSO + webhook ke IBT (Next.js — perlu bridge Supabase auth ↔ osee_token)
- [ ] 3.2 (Opsional, nanti) Tulis spec retroaktif `platform-webhooks` saat replikasi platform ke-2 dimulai