# M38 — Web Search & URL Reader (KiKai v1.2)

Implementasi roadmap "SISTEM SEARCH + BACA URL KIKAI" fase 1-3.

## Fase 1 — Auto Read URL
- User kirim pesan yang mengandung URL → `chat_controller` mendeteksi
  lewat `WebToolsService.extractUrls()`.
- URL pertama di-fetch ke backend `POST {webBackendBase}/read-url` yang
  mem-proxy `r.jina.ai` (bebas API key, opsional pakai `JINA_API_KEY`).
- Konten bersih (Markdown) di-inject sebagai konteks di depan prompt
  user + instruksi wajib cantumkan sumber.
- Loading banner: "KiKai lagi buka link..." (di atas composer).

## Fase 2 — Web Search
- Tombol globe di composer → toggle `webSearchEnabled`.
- Kalau ON (dan pesan bukan URL) atau user pakai prefix `/search ` /
  `/cari `, `chat_controller` panggil `searchAndRead()`:
  1. `POST {webBackendBase}/search` (DuckDuckGo HTML, top-5).
  2. Baca paralel top-3 hasil via Jina.
  3. Semua artikel + daftar link digabung → prompt context + instruksi
     citation `[1]`, `[2]`, dst.
- Loading banner: "KiKai lagi googling...".

## Fase 3 — Optimasi
- Cache 24 jam in-memory di backend (`lib/webCache.js`) untuk Jina & DDG.
- Timeout keras 10 dtk per fetch, 12 dtk di Flutter client. Web lemot
  di-skip, jawaban fallback tetap muncul dengan disclaimer.
- Konten Jina di-cap 20.000 karakter (~5000 kata) supaya hemat token.

## Konfigurasi
- Env Vercel (opsional): `JINA_API_KEY` (rate limit lebih tinggi),
  `ALLOWED_ORIGIN` (kunci CORS).
- Flutter build:
  ```
  flutter build apk \
    --dart-define=NVIDIA_BACKEND_URL=https://xxx.vercel.app/api/chat \
    --dart-define=WEB_BACKEND_BASE=https://xxx.vercel.app/api
  ```

## Checklist Rilis v1.2
- [x] Deteksi URL di chat
- [x] Rangkum 1 URL
- [x] Tool `search`
- [x] Tool `read_url`
- [x] Sitasi / sumber di prompt LLM
- [x] Loading "KiKai lagi googling..."
- [x] Cache 24 jam
