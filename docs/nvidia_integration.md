# NVIDIA Nemotron — Cara Kerja di Aplikasi KiKai

Dokumen ini menjelaskan **end-to-end** bagaimana model **NVIDIA Nemotron
3 Ultra 550B** dihidupkan di aplikasi Flutter KiKai — dari user tap
model "Kikai Nvidia" di composer sampai jawaban muncul streaming di
bubble chat.

Model NVIDIA **tidak** memakai jalur yang sama dengan model Claude/KiKai
Haiku (yang hit `kie.ai` langsung dari APK). Model NVIDIA di-proxy
lewat backend Vercel supaya API key `nvapi-...` **tidak ada di dalam
APK**.

---

## 1. Arsitektur Ringkas

```
┌──────────────┐   POST /api/chat  ┌─────────────────────┐   OpenAI SDK   ┌──────────────────────┐
│  KiKai APK   │ ────── JSON ────► │  nvidia-backend     │ ─── HTTPS ───► │  integrate.api       │
│  (Flutter)   │                   │  (Vercel Node.js)   │                │  .nvidia.com/v1      │
│              │ ◄── SSE stream ── │  Rotasi multi-key   │ ◄── SSE ─────  │  nemotron-3-ultra    │
└──────────────┘                   └─────────────────────┘                └──────────────────────┘
         ▲                                    ▲
         │                                    │
   `AiClientService`                   env var Vercel:
   route by provider                   NVIDIA_API_KEYS
                                       (comma-separated,
                                        rotasi otomatis)
```

**Kenapa lewat proxy, bukan langsung dari APK?**

1. **Keamanan key.** Key NVIDIA (`nvapi-...`) hidup **hanya** di env
   var Vercel. APK tidak pernah pegang key ini — reverse engineer
   `strings libapp.so | grep nvapi` = 0 hit.
2. **Rotasi key panas.** Ganti/tambah key di Vercel dashboard →
   langsung berlaku tanpa rebuild APK & rilis ulang.
3. **Kontrak SSE sederhana.** App tidak perlu SDK OpenAI/NVIDIA di
   Dart — cukup baca `data: {"type":"content","delta":"..."}`.
4. **Bisa injeksi rate-limit / metering per uid** di sisi backend
   nanti (mission-based gating, quota harian, dsb) tanpa update app.

---

## 2. Endpoint Proxy

**URL prod:** `https://nvidia-api-nine.vercel.app/api/chat`
**Method:** `POST` **saja**. Kalau di-akses dari browser (GET) balikin
`405 { "error": "Method not allowed. Gunakan POST." }` — ini **normal**,
bukan bug. Health check: `GET /api/health` → `{ ok: true, hasKeys: true, keyCount: N }`.

### Request body

```json
{
  "uid": "abc123",                 // opsional, buat log server
  "model": "nvidia-ultra",         // alias → di-resolve backend
  "messages": [
    { "role": "user", "content": "halo" }
  ],
  "stream": true,                  // default true (SSE)
  "temperature": 1,
  "top_p": 0.95,
  "max_tokens": 16384,
  "reasoning_budget": 16384,
  "enable_thinking": true
}
```

### Response — Streaming (SSE)

```
data: {"type":"reasoning","delta":"..."}   ← saat model "mikir"
data: {"type":"content","delta":"..."}     ← jawaban final
data: {"type":"done"}
data: {"type":"error","message":"..."}     ← kalau error
```

App **default hanya render** event `content`. Event `reasoning` di-skip
(bisa diaktifkan nanti untuk UI "🧠 sedang berpikir…" via param
`emitReasoning: true` di `NvidiaClientService.streamMessage`).

---

## 3. Alur di Sisi Flutter

### 3.1 Katalog model (`lib/core/constants/ai_models.dart`)

Entry `nvidia-premium-8b` di-mark dengan **provider baru** `AiProvider.nvidia`:

```dart
AiModel(
  id: 'nvidia-premium-8b',
  apiModelId: 'nvidia-ultra',              // alias backend
  label: 'Kikai Nvidia',
  provider: AiProvider.nvidia,             // ⬅ trigger routing baru
  endpointPath: '/api/chat',
  maxTokens: 16384,
  unlockKey: ModelUnlock.nvidia,           // gating mission 5.000 views
)
```

### 3.2 Routing (`lib/services/ai_client_service.dart`)

`AiClientService.streamMessage()` cek `model.provider`:

```dart
if (selected.provider == AiProvider.nvidia) {
  yield* NvidiaClientService.instance.streamMessage(
    history: history, model: selected, maxTokens: maxTokens,
  );
  return;
}
// else → jalur lama kie.ai + rotasi key --dart-define
_assertConfigured(); ...
```

Artinya untuk pemanggil di `chat_controller.dart` **tidak ada
perubahan** — masih panggil `AiClientService.instance.streamMessage(...)`.
Semua bercabang berdasarkan `provider` di dalam service.

### 3.3 Client NVIDIA (`lib/services/nvidia_client_service.dart`)

- POST JSON ke `AppConfig.nvidiaBackendUrl`.
- Baca body sebagai stream, split per baris, ambil yang prefix `data:`.
- Parse JSON, emit `delta` untuk `type == 'content'`.
- Return kalau ketemu `type == 'done'`.
- Throw `NvidiaClientException` untuk `type == 'error'`, status ≥400,
  atau timeout 120 detik.

### 3.4 Konfigurasi URL (`lib/core/constants/app_config.dart`)

```dart
static const String nvidiaBackendUrl = String.fromEnvironment(
  'NVIDIA_BACKEND_URL',
  defaultValue: 'https://nvidia-api-nine.vercel.app/api/chat',
);
```

Override saat build kalau owner deploy ulang di URL beda:

```bash
flutter build apk --release \
  --dart-define=NVIDIA_BACKEND_URL=https://xxx.vercel.app/api/chat
```

---

## 4. Alur di Sisi Backend (`nvidia-backend/`)

File utama: `api/chat.js`, `lib/apiKeys.js`, `lib/models.js`.

1. **CORS** — set `Access-Control-Allow-Origin: *` (bisa dibatasi via
   env `ALLOWED_ORIGIN`).
2. **Validasi** payload (`messages` non-empty, tiap message `role` +
   `content` valid).
3. **Model resolver** (`lib/models.js`) — translate alias
   (`nvidia-ultra`, `nvidia-premium-8b`, dst) → `nvidia/nemotron-3-ultra-550b-a55b`.
4. **Rotasi key** (`lib/apiKeys.js`) — coba key aktif, kalau NVIDIA
   balikin 401/403/429 → pindah ke key berikutnya. Sumber key (urutan
   prioritas):
   - `NVIDIA_API_KEYS` (comma-separated)
   - `NVIDIA_API_KEY_1 .. NVIDIA_API_KEY_10`
   - `NVIDIA_API_KEY` (fallback single)
5. **Panggil OpenAI SDK** ke `https://integrate.api.nvidia.com/v1`
   (NVIDIA menyediakan endpoint OpenAI-compatible).
6. **Stream SSE** ke Flutter dengan format yang sudah dijelaskan di §2.

---

## 5. Konfigurasi Env-Var di Vercel

Minimum wajib supaya `/api/chat` jalan:

| Nama | Contoh | Wajib? |
|---|---|---|
| `NVIDIA_API_KEYS` | `nvapi-aaa,nvapi-bbb,nvapi-ccc` | ✅ (atau salah satu di bawah) |
| `NVIDIA_API_KEY_1` | `nvapi-aaa` | opsional (per-slot) |
| `NVIDIA_API_KEY`   | `nvapi-aaa` | opsional (single) |
| `ALLOWED_ORIGIN`   | `*` atau `https://xxx` | opsional (default `*`) |

Verifikasi cepat sesudah deploy:

```bash
curl https://nvidia-api-nine.vercel.app/api/health
# { "ok": true, "hasKeys": true, "keyCount": 3, ... }
```

Kalau `hasKeys: false` → env `NVIDIA_API_KEY*` belum keset di project
Vercel. Buka **Project → Settings → Environment Variables**, tambahin,
lalu **redeploy** (env var baru tidak auto-live di deployment lama).

---

## 6. Test End-to-End Manual (Tanpa APK)

```bash
curl -N -X POST https://nvidia-api-nine.vercel.app/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia-ultra",
    "stream": true,
    "messages": [
      { "role": "user", "content": "Hai, jelaskan gravitasi singkat" }
    ]
  }'
```

Output normal: baris `data: {"type":"reasoning",...}` (opsional),
lalu `data: {"type":"content","delta":"..."}` streaming, ditutup
`data: {"type":"done"}`.

---

## 7. Gating Unlock (Mission 5.000 views)

Model `Kikai Nvidia` **locked by default** untuk user free. Unlock
mekanismenya sudah ada di codebase existing (`ModelUnlock.nvidia`)
dan tidak berubah — user harus dapat entitlement `nvidia_unlock` via
`CreatorMissionService` (5.000 views). Selector di composer akan
otomatis nampilin badge kunci sampai entitlement aktif.

Jadi walaupun proxy `/api/chat` bersifat publik (tanpa auth), user
tidak bisa memilih model Nvidia di UI tanpa unlock — dan
`chat_controller` selalu kirim `model` dari selector, bukan input
bebas.

Kalau nanti butuh proteksi tambahan (misal cegah user root-modif APK
yang bypass unlock), tinggal tambahin di backend:

```js
// api/chat.js — contoh future gating
if (payload.model?.startsWith("nvidia") && !isEntitledUid(uid)) {
  return res.status(403).json({ error: "Butuh entitlement Nvidia" });
}
```

---

## 8. Ringkasan File yang Terlibat

**Flutter (APK):**
- `lib/services/nvidia_client_service.dart` — client SSE proxy (baru)
- `lib/services/ai_client_service.dart` — routing by provider
- `lib/core/constants/ai_models.dart` — entry `nvidia-premium-8b`
- `lib/core/constants/app_config.dart` — `nvidiaBackendUrl`
- `lib/models/ai_model.dart` — enum `AiProvider.nvidia`

**Backend (Vercel):**
- `nvidia-backend/api/chat.js` — endpoint POST + SSE
- `nvidia-backend/api/health.js` — probe key/status
- `nvidia-backend/lib/apiKeys.js` — rotasi multi-key
- `nvidia-backend/lib/models.js` — alias → model id resolver

---

## 9. FAQ Debug

**Q: `curl` ke `/api/chat` di browser dapat 405 "Method not allowed".**
A: Normal. Endpoint POST-only, browser default GET → 405. Test dengan
`curl -X POST ...` seperti di §6.

**Q: `/api/health` return `hasKeys:false`.**
A: Env `NVIDIA_API_KEYS` (atau `_1`, atau `NVIDIA_API_KEY`) belum
tersimpan di Vercel project, atau baru diset tapi belum redeploy.

**Q: App error "Proxy NVIDIA menolak (500)".**
A: Cek Vercel log dashboard — 500 biasanya karena semua key habis
quota/expired atau NVIDIA sisi upstream error. Tambah key baru ke env
`NVIDIA_API_KEYS`, redeploy.

**Q: Stream berhenti di tengah tanpa `done`.**
A: Cek `max_tokens` — mungkin ketutup limit. Default app 16384 udah
cukup untuk kebanyakan jawaban. Kalau timeout 120s Vercel juga bisa
kena untuk jawaban super panjang — pertimbangkan turunin `max_tokens`
atau `reasoning_budget`.
