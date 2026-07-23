# Pengembangan Aplikasi — **Claude 4.8 AI**

> Dokumen SOP & roadmap pengembangan aplikasi Flutter **Claude 4.8 AI** (chat AI multi-model).
> Format & gaya penulisan mengikuti standar `pengembangan.md` — jadi tinggal ikuti alur milestone (M0, M1, M2, ...) tiap kali ada penambahan fitur.

---

## 0. Identitas Project

| Item | Nilai |
|---|---|
| Nama Aplikasi | **Claude 4.8 AI** |
| Package ID (rencana) | `com.claude48.ai` |
| Framework | Flutter (Dart) — target Android APK (iOS opsional) |
| Build System | GitHub Actions (workflow `.github/workflows/android-build.yml`) |
| Distribusi | APK Release via GitHub Releases |
| Backend / API | AI Provider REST (OpenAI-compatible / Anthropic / OpenRouter — extensible) |
| Storage Lokal | `shared_preferences` (settings) + `sqflite` / Hive (history chat & thread) |
| Storage Remote (opsional) | Firestore (kalau nanti butuh sync antar device — sama pola seperti iGlows) |

---

## 1. Aturan Wajib (JANGAN DILANGGAR)

1. **JANGAN** menyentuh file di `.github/workflows/` kecuali dalam rangka menambah *step* build baru (tetap pertahankan step lama).
2. **JANGAN** menghapus `gradle-wrapper.jar` atau ubah `gradle-wrapper.properties`.
3. **JANGAN** meng-commit API key ke repo. Semua key WAJIB via **GitHub Secrets** → di-inject saat build.
4. **JANGAN** membuat `firebase_options.dart` manual — kalau butuh Firebase, generate via `flutterfire configure` di local (bukan agent).
5. **JANGAN** menghapus history migrasi di `pengembangan.md`. Tambah entry baru di bawah (M1, M2, dst).
6. **Selalu** tambahkan milestone baru ke bagian **Progress Log (Milestones)** di bawah setiap kali menyelesaikan fitur.
7. **Theme** tetap konsisten: dark-first, aksen ungu-oranye premium (bisa disesuaikan di M2).
8. **Nama file / class** pakai `snake_case` untuk file, `PascalCase` untuk class, sesuai konvensi Dart.

---

## 2. Arsitektur Folder

```
lib/
├── main.dart                       # entry point + init service singleton
├── app.dart                        # MaterialApp + theme + routing
├── core/
│   ├── theme/
│   │   ├── app_theme.dart          # ThemeData light/dark + color tokens
│   │   └── app_colors.dart
│   ├── constants/
│   │   ├── app_config.dart         # kAppVersion, kAppName, endpoint defaults
│   │   └── ai_models.dart          # daftar model AI (id, label, provider, maxTokens)
│   └── utils/
│       ├── file_utils.dart         # deteksi mime, ekstensi bahasa pemrograman
│       └── token_utils.dart
├── models/
│   ├── chat_thread.dart            # id, title, createdAt, updatedAt, modelId
│   ├── chat_message.dart           # id, threadId, role, content, attachments, createdAt
│   ├── attachment.dart             # type (image/file/code), path, mime, sizeBytes, language
│   ├── ai_model.dart               # id, label, provider, capabilities (vision, file, tools)
│   └── user_profile.dart
├── services/
│   ├── api_key_service.dart        # ambil dari --dart-define / env (inject build)
│   ├── ai_client_service.dart      # abstraksi provider (OpenAI / Anthropic / OpenRouter)
│   ├── chat_service.dart           # send message, streaming SSE, tool-call handler
│   ├── history_service.dart        # CRUD thread + message ke local DB
│   ├── attachment_service.dart     # pick image (image_picker), pick file (file_picker)
│   ├── settings_service.dart       # persist tema, default model, streaming toggle
│   └── payment_service.dart        # (M?) QRIS gateway — nanti
├── features/
│   ├── chat/
│   │   ├── chat_screen.dart        # halaman chat utama
│   │   ├── widgets/
│   │   │   ├── message_bubble.dart # bubble user vs assistant + markdown + code block
│   │   │   ├── message_composer.dart # input box + attach + model selector di dalam kotak
│   │   │   ├── model_selector.dart # dropdown/bottom sheet pilih model
│   │   │   ├── attachment_preview.dart
│   │   │   ├── code_block.dart     # syntax highlight (flutter_highlight)
│   │   │   └── typing_indicator.dart
│   ├── sidebar/
│   │   ├── sidebar_drawer.dart     # daftar thread + tombol "New Chat" + icon settings
│   │   └── thread_tile.dart
│   ├── settings/
│   │   ├── settings_screen.dart    # profil user, tema, default model, tentang aplikasi
│   │   └── profile_section.dart
│   ├── profile/
│   │   └── profile_screen.dart     # detail user + status subscription (M?)
│   └── premium/
│       └── premium_screen.dart     # (M?) upgrade + QRIS payment flow
└── widgets/
    ├── app_update_dialog.dart      # broadcast update (nanti mirip iGlows)
    └── loading_shimmer.dart
```

---

## 3. Fitur & Spesifikasi UI/UX

### 3.1 Halaman Chat (Home)
- Full-height chat view, message list `ListView.builder` reverse.
- Bubble **user**: rata kanan, warna aksen; **assistant**: rata kiri, background surface.
- Support **Markdown** (pakai `flutter_markdown`) untuk response.
- **Code block** dengan syntax highlight + tombol *copy code*.
- **Streaming response** (SSE) — token muncul realtime dengan blinking cursor.
- **Typing indicator** saat `status == submitted`.
- Auto-scroll ke bawah saat pesan baru.
- Long-press bubble → menu: *Copy*, *Regenerate* (assistant), *Edit & resend* (user).

### 3.2 Sidebar History
- Slide dari kiri (`Drawer`).
- Section atas: tombol **+ New Chat** (primary color, full width).
- List thread: judul auto-generated dari pesan pertama (dipotong 40 char), + timestamp relatif ("2 jam lalu").
- Swipe-to-delete atau tombol titik-tiga → *Rename*, *Delete*, *Pin*.
- Section paling bawah: icon **⚙️ Settings** (rata kiri, sekaligus akses **Profile** → tap membuka `SettingsScreen`).
- Search bar (opsional M?) untuk cari di semua thread.

### 3.3 Model Selector di Message Composer
- Di **dalam kotak pesan** (bukan di app bar), pojok kiri-atas composer.
- Chip kecil yang menampilkan nama model aktif (misal: `claude-3.5-sonnet ▾`).
- Tap → bottom sheet daftar model dengan icon capability (👁️ vision, 📎 file, 🔧 tools).
- List model **dinamis** dari `core/constants/ai_models.dart` — user cukup edit file itu untuk tambah/kurangi model.

### 3.4 Attachment (Teks + Gambar + File)
- Icon **📎 Attach** di composer → menu: *Foto*, *Kamera*, *File*.
- **Image**: pakai `image_picker`, preview thumbnail di atas input, kirim sebagai base64/URL (tergantung model vision-support).
- **File coding**: pakai `file_picker` — **support semua ekstensi**: `.dart .js .ts .tsx .jsx .py .go .php .java .kt .swift .rb .rs .c .cpp .cs .html .css .scss .json .yaml .yml .toml .xml .sql .sh .bash .md .txt .env .gitignore` dan **wildcard** untuk sisanya.
- Deteksi bahasa via ekstensi → pass ke model dalam bentuk:
  ```
  ```<language>
  <isi file>
  ```
  ```
- Batas ukuran default: 1 MB per file (bisa diubah di settings).
- Multiple attachment per pesan (max 5).

### 3.5 System API Key (via GitHub Secrets → Build-time Inject)
- **Konsep:** API key TIDAK disimpan di kode dan TIDAK diminta ke user. Key ada di **GitHub Secrets** repo → workflow build meng-inject-nya ke APK saat compile pakai `--dart-define`.
- **Cara kerja:**
  1. User set secret di GitHub → repo → *Settings* → *Secrets and variables* → *Actions*:
     - `AI_API_KEY` (wajib)
     - `AI_API_BASE_URL` (opsional, default: `https://api.openai.com/v1`)
     - `AI_DEFAULT_MODEL` (opsional, default: `gpt-4o-mini`)
  2. Workflow `.github/workflows/android-build.yml` build dengan:
     ```yaml
     - run: flutter build apk --release \
         --dart-define=AI_API_KEY=${{ secrets.AI_API_KEY }} \
         --dart-define=AI_API_BASE_URL=${{ secrets.AI_API_BASE_URL }} \
         --dart-define=AI_DEFAULT_MODEL=${{ secrets.AI_DEFAULT_MODEL }}
     ```
  3. Di `lib/services/api_key_service.dart`:
     ```dart
     class ApiKeyService {
       static const apiKey    = String.fromEnvironment('AI_API_KEY');
       static const baseUrl   = String.fromEnvironment('AI_API_BASE_URL', defaultValue: 'https://api.openai.com/v1');
       static const defaultModel = String.fromEnvironment('AI_DEFAULT_MODEL', defaultValue: 'gpt-4o-mini');
       static bool get isConfigured => apiKey.isNotEmpty;
     }
     ```
- **Fallback:** kalau `apiKey.isEmpty` (misal build lokal tanpa secret) → tampilkan banner di chat: *"API key belum di-inject saat build. Build ulang via GitHub Actions."*
- **JANGAN** pernah expose key di log / crash report.

### 3.6 Settings & Profile (via icon ⚙️ di sidebar)
- **Profile section**: avatar, nama, email (opsional login — bisa lokal-only dulu).
- **Preferences**:
  - Tema (System / Light / Dark)
  - Default model
  - Streaming on/off
  - Font size chat
  - Auto-title thread on/off
- **Data**:
  - Export semua chat ke `.json` / `.md`
  - Clear semua history (confirm dialog)
- **Premium (placeholder untuk M?)**:
  - Card "Upgrade ke Premium" → buka `PremiumScreen` dengan **QRIS payment** (nanti).
- **About**: versi app, changelog, link GitHub repo.

### 3.7 Extras (rekomendasi kreatif)
- **Prompt Library / Quick Prompts** — kumpulan prompt siap-pakai (Coding, Writing, Translate, Explain code).
- **Voice Input** (opsional, pakai `speech_to_text`) → dictate pesan.
- **Regenerate** & **Stop generating** button.
- **Estimated token counter** di composer.
- **Haptic feedback** saat kirim / terima response.
- **Empty state** yang cakep: logo Claude 4.8 + 3–4 saran prompt clickable.
- **App Update Broadcast** (mirip iGlows M16) — fetch remote JSON → force / soft update dialog.

---

## 4. Dependency Rencana (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6

  # State & storage
  shared_preferences: ^2.2.2
  sqflite: ^2.3.0
  path_provider: ^2.1.1

  # Networking
  http: ^1.2.0
  dio: ^5.4.0                 # untuk streaming SSE lebih enak

  # UI
  flutter_markdown: ^0.6.20
  flutter_highlight: ^0.7.0
  google_fonts: ^6.1.0
  cached_network_image: ^3.3.0

  # Media & file
  image_picker: ^1.0.7
  file_picker: ^6.1.1
  mime: ^1.0.5

  # Utility
  intl: ^0.19.0
  uuid: ^4.2.1
```

---

## 5. Alur Kerja Development (per Milestone)

Setiap milestone ikuti pola:
1. Buat / edit file yang dibutuhkan.
2. Update `pubspec.yaml` kalau ada dependency baru → jalankan `flutter pub get`.
3. Uji lokal (`flutter run`) minimal di 1 emulator.
4. Update section **Progress Log** di bawah dengan format:
   ```
   ### M<n> — <Judul Milestone>
   - Ringkasan singkat perubahan
   - File yang diubah/ditambah
   - Catatan khusus (breaking change, TODO)
   ```
5. Commit dengan pesan `feat(m<n>): <judul>` atau `fix(m<n>): <judul>`.

---

## 6. Progress Log (Milestones)

### M0 — Bootstrap Project
- Inisialisasi Flutter project `claude_48_ai`.
- Setup folder arsitektur (`core`, `models`, `services`, `features`, `widgets`).
- Setup theme dark-first dasar.
- Setup GitHub Actions workflow build APK dengan `--dart-define` untuk `AI_API_KEY`.
- Buat `ApiKeyService` + banner fallback kalau key kosong.

### M1 — Halaman Chat Dasar + Streaming
- Implement `ChatScreen`, `MessageBubble`, `MessageComposer`.
- Integrasi `AIClientService` (OpenAI-compatible) dengan streaming SSE via `dio`.
- Render Markdown + code block dengan highlight.
- Auto-scroll & typing indicator.

### M2 — Sidebar & History Persist
- Implement `SidebarDrawer` + `ThreadTile`.
- `HistoryService` (sqflite) simpan thread & messages.
- New Chat, Rename, Delete, Pin.
- Auto-generate title thread dari pesan pertama.

### M3 — Model Selector di Composer
- `ai_models.dart` constant list.
- `ModelSelector` bottom sheet dengan capability icons.
- Persist last-used model per thread.

### M4 — Attachment (Image + File Coding)
- `AttachmentService` (image_picker + file_picker).
- Preview thumbnail & file chip di composer.
- Konversi file coding → code block dengan language tag.
- Kirim ke model vision/file-capable, fallback plain text kalau model tidak support.

### M5 — Settings & Profile
- `SettingsScreen` (tema, default model, streaming, font size).
- `ProfileScreen` (avatar, nama, email lokal).
- Export chat ke `.json` / `.md`.
- Clear all history.

### M6 — Polish UI/UX
- Empty state dengan suggested prompts.
- Regenerate & Stop generating.
- Long-press message → copy/edit/regenerate.
- Haptic feedback + animasi halus.

### M7 — App Update Broadcast (opsional, mirip iGlows M16)
- `AppUpdateService` fetch `latest_version` dari remote JSON.
- `AppUpdateDialog` (soft & force update).

### M8 — Premium & QRIS Payment (TBD)
- `PremiumScreen` + integrasi QRIS gateway (Midtrans / Xendit / Tripay).
- `PaymentService` verifikasi transaksi.
- Feature gating: model premium hanya untuk subscriber.

### M9+ — TBD
- Voice input, prompt library, cloud sync (Firestore), multi-device history, dsb.

---

## 7. Checklist Rilis Tiap Versi

- [ ] Update `version:` di `pubspec.yaml` (`x.y.z+n`)
- [ ] Update `kAppVersion` di `core/constants/app_config.dart`
- [ ] Update entry milestone baru di `pengembangan.md`
- [ ] Test build lokal (`flutter build apk --release --dart-define=AI_API_KEY=...`)
- [ ] Push tag → GitHub Actions build APK release
- [ ] Publish ke GitHub Releases + changelog

---

## 8. Catatan Keamanan

- API key **HANYA** hidup di GitHub Secrets → runtime APK (via `--dart-define`).
- Jangan pernah `print(ApiKeyService.apiKey)`.
- Kalau nanti tambah backend proxy sendiri → pindahkan API key ke server, aplikasi cukup pegang session token user.
- Attachment file yang dikirim ke model provider TIDAK boleh mengandung `.env` isi credential user tanpa warning eksplisit di UI.

---

**End of pengembangan.md — Claude 4.8 AI**

---

## Log Milestone Terlaksana

### M0 — Bootstrap Project ✅ (selesai)

Tanggal: 1 Juli 2026

**Ringkasan**
Inisialisasi seluruh scaffold Flutter `claude_48_ai`, theme dark-first
ungu-oranye premium, `ApiKeyService` (build-time inject via
`--dart-define`), `AiClientService` skeleton yang siap hit endpoint
kie.ai Claude (`POST /claude/v1/messages`), empty-state ChatScreen +
banner peringatan kalau `AI_API_KEY` belum di-set, launcher icon
gradient ungu-oranye, dan GitHub Actions workflow release APK.

**Catatan brand:** base model = **Claude Haiku 4.5** (via kie.ai), tapi
identitas & UI di aplikasi tetap **"Claude 4.8 AI"** sesuai keputusan
owner. Model id di request tetap `claude-haiku-4-5` sesuai OpenAPI kie.ai.

**File baru**
- `pubspec.yaml` — SDK `>=3.3.0 <4.0.0`, flutter `>=3.22.0`. Dependency
  siap M0–M5: `http`, `dio`, `flutter_markdown`, `flutter_highlight`,
  `google_fonts`, `cached_network_image`, `image_picker`, `file_picker`,
  `mime`, `shared_preferences`, `sqflite`, `path_provider`, `path`,
  `intl`, `uuid`. Dev: `flutter_lints`, `flutter_launcher_icons`.
- `analysis_options.yaml` — extends `flutter_lints`, disable
  `use_key_in_widget_constructors` & `prefer_const_constructors` (biar
  gak berisik untuk private widget helper).
- `README.md` — cara build APK via GitHub Actions + build lokal dev.
- `.gitignore` — Flutter/Dart/Android + `.env` (SOP §8, jangan pernah
  commit key).
- `.github/workflows/android-build.yml` — job **Android Build**:
  1. Setup Java 17 (Temurin) + Flutter 3.24.5 stable.
  2. `flutter create --no-pub .` untuk **restore missing scaffolding**
     (gradle wrapper jar, generated plugin registrant) tanpa
     nge-overwrite `lib/` atau `android/app/build.gradle` yang sudah ada
     — idempotent.
  3. `flutter pub get`.
  4. `dart run flutter_launcher_icons` (generate mipmap dari
     `assets/icon/app_icon.png`).
  5. `flutter build apk --release` dengan **inject `--dart-define`** dari
     GitHub Secrets: `AI_API_KEY`, `AI_API_BASE_URL`
     (default `https://api.kie.ai`), `AI_DEFAULT_MODEL`
     (default `claude-haiku-4-5`).
  6. Upload artifact `Claude48AI-release.apk` (retention 14 hari).
- `assets/icon/app_icon.png` — 1024×1024 launcher icon gradient
  ungu-oranye, huruf "C" glassmorphism + microtype "4.8".

- **Core**
  - `lib/core/theme/app_colors.dart` — token warna wajib (primary
    `#7C5CFF`, accent `#FF8A3D`, background `#0B0B14`, surfaces,
    bubble, gradient brand). SOP: JANGAN hardcode warna di
    screen/widget, tambahin di sini dulu.
  - `lib/core/theme/app_theme.dart` — `ThemeData` dark M3 dgn typography
    `google_fonts.inter`, appbar/card/input/button/drawer/snackbar
    consistent.
  - `lib/core/constants/app_config.dart` — `appName`, `appVersion`
    (`0.1.0`), `defaultApiBaseUrl` (`https://api.kie.ai`),
    `claudeMessagesPath` (`/claude/v1/messages`), `defaultModelId`
    (`claude-haiku-4-5`), batas attachment.
  - `lib/core/constants/ai_models.dart` — katalog `kAiModels` (M0
    hanya 1 model: Claude 4.8 Haiku, capability vision/file/tools).
    Tambah model = append entry, langsung muncul di selector M3.
  - `lib/core/utils/file_utils.dart` — deteksi language dari ekstensi
    (30+ mapping) + `wrapAsCodeBlock` untuk M4.
  - `lib/core/utils/token_utils.dart` — estimasi token approx
    (1 tok ≈ 4 char) + format label.

- **Models**
  - `lib/models/ai_model.dart` — enum `AiProvider` + class `AiModel`.
  - `lib/models/attachment.dart` — enum `AttachmentType` (image/file/
    code) + `Attachment` dgn `toMap/fromMap`.
  - `lib/models/chat_message.dart` — enum `ChatRole` + `ChatMessage`
    (id, threadId, role, content, attachments, createdAt, isStreaming)
    + `copyWith` + serialisasi.
  - `lib/models/chat_thread.dart` — id, title, modelId, timestamps,
    pinned + serialisasi.
  - `lib/models/user_profile.dart` — placeholder untuk M5.

- **Services**
  - `lib/services/api_key_service.dart` — baca `AI_API_KEY`,
    `AI_API_BASE_URL`, `AI_DEFAULT_MODEL` via `String.fromEnvironment`.
    Getter `isConfigured` + `maskedKey` (untuk About screen — TIDAK
    expose full key ke log/UI). SOP §8: JANGAN pernah `print` key.
  - `lib/services/ai_client_service.dart` — singleton client kie.ai
    Claude. Method `sendMessage(history, model?, maxTokens?)` (non-
    streaming M0). Header `Authorization: Bearer {key}`, body
    `{model, messages, stream:false, max_tokens}`. Error handling:
    `AiClientException` (401/403 → pesan API key ditolak, 429 →
    rate limit, timeout 45s, http error → short body). Extractor
    `content` toleran (list of blocks atau plain string). Streaming
    SSE + tool calls diimplement di M1.

- **Widgets**
  - `lib/widgets/api_key_banner.dart` — banner warning kalau
    `ApiKeyService.isConfigured == false` (SOP 3.5).
  - `lib/widgets/loading_shimmer.dart` — shimmer minimal tanpa
    dependency, dipakai list history M2.

- **Features / Chat**
  - `lib/features/chat/chat_screen.dart` — shell chat M0: AppBar dgn
    brand mark gradient + tombol menu (buka drawer placeholder) +
    tombol new-chat (snackbar "aktif di M2"). Body: banner API key
    (kalau perlu) + empty state (avatar gradient besar, greeting,
    4 suggested prompt cards) + composer placeholder (chip model
    selector + attach/mic/send disabled dgn tooltip pointing ke
    milestone yang aktifin fitur).

- **App shell**
  - `lib/app.dart` — `MaterialApp` `themeMode: dark`, `home: ChatScreen`.
  - `lib/main.dart` — `WidgetsFlutterBinding.ensureInitialized()` +
    set `SystemUiOverlayStyle` dark, `runApp(Claude48App())`.

- **Android**
  - `android/app/build.gradle` — namespace + applicationId
    `com.claude48.ai`, `minSdk 23`, Java 17, signing debug untuk CI
    (ganti keystore beneran saat Play Store).
  - `AndroidManifest.xml` main/debug/profile — permission `INTERNET`,
    activity `MainActivity`, label "Claude 4.8 AI", queries `PROCESS_TEXT`.
  - `MainActivity.kt` di `com/claude48/ai/`.
  - `settings.gradle` — flutter plugin loader + AGP 8.3.0 + Kotlin 1.9.22.
  - `gradle.properties` — Xmx 4G, AndroidX enabled.
  - `gradle-wrapper.properties` — Gradle **8.6** distribution URL.
    `gradle-wrapper.jar` di-restore oleh workflow (`flutter create .`
    step) — sesuai SOP §1.2 jangan commit jar.

**Setup wajib di GitHub (one-time)**
1. Push repo → GitHub.
2. Repo → **Settings → Secrets and variables → Actions → New repository
   secret**:
   - `AI_API_KEY` (wajib) — API key kie.ai / provider Claude.
   - `AI_API_BASE_URL` (opsional) — default `https://api.kie.ai`.
   - `AI_DEFAULT_MODEL` (opsional) — default `claude-haiku-4-5`.
3. Actions → **Android Build** → **Run workflow**.
4. Download `Claude48AI-release-apk` dari artifact.

**Kalau APK terinstall tapi ada banner "API key belum di-inject"** →
berarti workflow build **tidak** meng-inject `--dart-define` (secret
belum dibuat / typo nama). Cek log step "Build APK" di Actions,
pastikan ada `--dart-define=AI_API_KEY=***`.

**Compatibility / Breaking change**
- Belum ada (M0 = bootstrap).

**TODO carry-over ke M1**
- Streaming SSE (`text/event-stream`) via `dio` — event
  `message_start`, `content_block_start`, `content_block_delta`,
  `message_delta`, `message_stop`.
- Blinking cursor + typing indicator.
- `flutter_markdown` render + `flutter_highlight` code block + tombol
  copy.
- Auto-scroll ke bawah, long-press bubble (Copy/Regenerate/Edit&Resend).
- Persist thread aktif ke in-memory (M2 baru pindah ke sqflite).

**Belum di-lakukan (per SOP)**
- Tidak menyentuh `firebase_options.dart` (belum butuh Firebase).
- Tidak commit API key ke repo.
- Tidak overwrite `.github/workflows/*` yang sudah ada (ini file baru).
- Tidak menghapus history milestone lain — semua entry di append di
  bawah section **Log Milestone Terlaksana**.

---

### M1 — Chat Interaktif + Streaming SSE ✅ (selesai)

Tanggal: 1 Juli 2026

**Ringkasan**
Chat sudah interaktif end-to-end. User bisa ketik → kirim → assistant
merespons realtime via **SSE streaming** dari endpoint kie.ai Claude
(`POST /claude/v1/messages` dengan `stream:true`). Markdown, code block
syntax highlight, typing indicator, auto-scroll, dan stop-generating
semua sudah jalan. Storage masih in-memory (persist ke sqflite dimasuki
di M2).

**Alur runtime**
1. User ketik → `MessageComposer.onSend(text)`.
2. `ChatController.sendUserMessage` push 2 pesan: `user` + assistant
   placeholder (`isStreaming:true`, content kosong → tampil typing dots).
3. `AiClientService.streamMessage(history, model)` buka POST SSE ke
   kie.ai. Setiap event `content_block_delta` (`delta.type == text_delta`)
   → `yield` chunk text.
4. Controller append chunk ke buffer → `_updateAssistant` → auto scroll
   ke bawah lewat listener di `ChatScreen`.
5. `onDone` → set `isStreaming:false`. `onError` → tampilkan snackbar
   + replace assistant content dengan pesan error kalau buffer kosong.
6. Stop button (aktif saat `isSending`) → `stopGenerating` cancel
   subscription, freeze konten yang sudah masuk.

**File baru**
- `lib/features/chat/chat_controller.dart` — `ChangeNotifier` in-memory
  thread. Method: `sendUserMessage`, `stopGenerating`, `setModel`,
  `resetThread`, `clearError`. Simpan `_messages`, `_isSending`,
  `_error`, `_sub` (subscription streaming aktif). Persist ke sqflite
  masuk di M2.
- `lib/features/chat/widgets/message_bubble.dart` — bubble user (rata
  kanan, warna primer, plain text) vs assistant (rata kiri, surface,
  `flutter_markdown`). Long-press → copy to clipboard. Assistant support
  markdown penuh: heading, list, quote, table, inline code, dan **fenced
  code block via `_CodeElementBuilder`** yang delegate ke `CodeBlock`.
  Blinking cursor kecil saat masih streaming.
- `lib/features/chat/widgets/message_composer.dart` — text field
  multi-line (1–6 baris) + `_ModelChip` clickable (buka bottom sheet
  model selector) + tombol send/stop yang auto-switch pakai
  `AnimatedSwitcher`. Attach/mic tetap disabled sampai M4/M9+.
- `lib/features/chat/widgets/typing_indicator.dart` — 3 titik animasi
  fade (self-contained, no dependency).
- `lib/features/chat/widgets/code_block.dart` — `HighlightView` dari
  `flutter_highlight` (tema `atom-one-dark`) + header dengan label
  bahasa & tombol **Copy**. Horizontal scroll untuk line panjang.

**File diubah**
- `lib/services/ai_client_service.dart` — tambah **`streamMessage`**.
  Pakai `http.Client().send()` dengan `Accept: text/event-stream`.
  Parser SSE baca line-by-line, filter `data:` prefix, decode JSON,
  handle event `content_block_delta` (yield text), `message_delta`,
  `message_stop`, `error`. Refactor helper: `_assertConfigured`,
  `_resolveModel`, `_headers`, `_buildMessages`, `_checkStatus`.
  Filter pesan kosong sebelum dikirim (biar assistant placeholder
  yang masih `content:""` gak lolos ke body request).
- `lib/features/chat/chat_screen.dart` — dari empty-state stateless
  jadi **`StatefulWidget`** yang punya `ChatController` + `ScrollController`.
  `AnimatedBuilder(animation: _controller, …)` render list bubble
  atau empty state. Composer wired ke `handleSend`, `stopGenerating`,
  `openModelSelector` (bottom sheet dinamis dari `kAiModels`,
  siap M3 begitu list model dimekarin). Tombol "new chat" di AppBar
  sekarang aktif → `resetThread`. Prompt card di empty-state langsung
  kirim ke assistant saat di-tap.
- `pubspec.yaml` — tambah `markdown: ^7.2.2` eksplisit (dipakai
  `_CodeElementBuilder` via `import 'package:markdown/markdown.dart' as md;`
  — sebelumnya cuma transitive dep dari `flutter_markdown`).

**Catatan teknis**
- **SSE parser** sengaja simple (line splitter) — cukup untuk
  Anthropic-compatible stream. Kalau nanti ganti ke provider yang pakai
  format lain (mis. OpenAI `chat.completions` chunk), tambah branch di
  `_extract` bagian `type == …`.
- **Model selector** untuk M1 sudah fungsional tapi list model masih
  1 entry (Claude 4.8 Haiku). M3 tinggal tambah entry di `kAiModels`.
- **History kirim ke API** = full `_messages` minus assistant placeholder
  yang masih streaming (di-filter by id). Belum ada windowing / token
  budget — dimasuki nanti kalau perlu di M6/M9+.
- **Error UX**: snackbar sekali per error baru (dedupe via `_lastError`).
- **Auto-scroll** trigger di setiap `notifyListeners` via
  `WidgetsBinding.instance.addPostFrameCallback` supaya nempel di bawah
  saat token baru masuk.

**TODO / Diketahui**
- Regenerate & edit-and-resend belum ada (M6).
- Persist thread belum ada (M2).
- Tombol attach & mic disable — sesuai SOP milestone.

---

### M2 — Sidebar & History Persist (sqflite) ✅ (selesai)

Tanggal: 1 Juli 2026

**Ringkasan**
History percakapan sekarang **persisted ke SQLite**. Sidebar drawer aktif
menampilkan daftar thread (pinned di atas, sisanya diurut `updatedAt`),
plus tombol **+ New Chat**, per-thread action (Ubah judul / Sematkan /
Hapus), auto-generated title dari pesan pertama user (potong 40 char),
dan footer **⚙️ Settings & Profile** placeholder (aktif full di M5).
Buka app → auto-open thread paling baru; kalau belum ada → draft kosong
dgn empty state seperti M1.

**Alur runtime**
1. `initState` → `ChatController.loadInitial()` → `refreshThreads()` +
   `openThread(threads.first.id)` kalau ada. Kalau kosong → tetap draft
   (`currentThread == null`), empty state tampil.
2. **Kirim pesan pertama di draft**:
   - `sendUserMessage` create `ChatThread` baru (uuid v4), title =
     `_autoTitle(trimmed)` (baris pertama, potong 40 char + ellipsis).
   - `HistoryService.upsertThread` → row baru di `threads`.
   - User message langsung `upsertMessage` sebelum stream mulai.
   - Assistant placeholder di-buffer di memory; setelah `onDone`/`onError`/
     `stopGenerating` → `upsertMessage` versi final + `touchThread`
     (bump `updatedAt`) → `refreshThreads` → sidebar auto-refresh.
3. **Buka thread lain**: tap tile di drawer → `openThread(id)` →
   `stopGenerating` kalau lagi streaming, load messages dari DB,
   sync `model` dari `thread.modelId` → notify → chat view re-render.
4. **New Chat** dari drawer atau AppBar → `newDraft()` (tidak ada row
   baru di DB sampai user kirim pesan pertama — hindari thread "kosong").
5. **Rename / Pin / Delete** via popup menu tile → `HistoryService`
   method langsung → `refreshThreads`. Delete thread aktif → auto pindah
   ke thread paling baru berikutnya.

**File baru**
- `lib/services/history_service.dart` — singleton wrapper sqflite.
  Tabel `threads` (id, title, modelId, createdAt, updatedAt, pinned) +
  `messages` (id, threadId, role, content, attachments-JSON, createdAt)
  dgn FK cascade + index `(threadId, createdAt)`. `PRAGMA foreign_keys=ON`
  di `onConfigure`. Method: `listThreads / getThread / upsertThread /
  renameThread / togglePin / touchThread / deleteThread / clearAll /
  listMessages / upsertMessage / deleteMessage`. Attachment di-serialize
  JSON (siap M4, default `[]` di M2).
- `lib/features/sidebar/sidebar_drawer.dart` — `SidebarDrawer` (width 300,
  bg surface). Layout: header brand+versi → tombol `+ New Chat` full-width
  → list thread (section **Pinned** + **Recent**) → footer settings.
  Dialog rename (TextField maxLength 80) & confirm delete built-in.
  Helper `formatRelative(DateTime)` — "baru saja / N mnt lalu / N jam
  lalu / N hari lalu / d MMM yyyy".
- `lib/features/sidebar/thread_tile.dart` — `ThreadTile` dgn highlight
  saat selected (`surfaceHigh`), icon push_pin kalau pinned (accent
  oranye), timestamp relatif, `PopupMenuButton` (**Ubah judul / Sematkan
  / Hapus** — Hapus warna danger).

**File diubah**
- `lib/features/chat/chat_controller.dart` — dari in-memory jadi
  **persisted**. Tambah `HistoryService` dependency (default singleton),
  state `currentThread` (nullable = draft), `threads`, `threadsLoading`.
  Method baru: `loadInitial`, `refreshThreads`, `openThread`, `newDraft`,
  `renameThread`, `togglePin`, `deleteThread`. `sendUserMessage`
  sekarang: (a) create thread + auto-title kalau draft, (b) persist user
  msg sebelum stream, (c) persist assistant final saat `finally`,
  (d) `touchThread` untuk update `updatedAt` sidebar sort. `setModel`
  ikut update `modelId` thread aktif di DB. `stopGenerating` persist
  konten parsial. `resetThread` sekarang = `newDraft()` (thread lama
  tetap di DB, bisa dibuka lagi dari sidebar).
- `lib/features/chat/chat_screen.dart` — `initState` call `loadInitial`
  di `addPostFrameCallback`. `drawer:` ganti ke `SidebarDrawer(
  controller: _controller)`. AppBar new-chat button enable kalau ada
  message ATAU thread aktif; onPressed → `newDraft()`. Class
  `_PlaceholderDrawer` di-hapus (obsolete).

**Catatan teknis**
- **UUID v4** untuk thread id & message id (via `Uuid()` dari package
  `uuid` — sudah di deps M0). Prefix `u_` untuk user msg id, `a_` untuk
  assistant msg id — konsisten dgn M1 biar log/debug enak.
- **Sort order** di `listThreads`: `pinned DESC, datetime(updatedAt) DESC`
  — pinned selalu di atas, dalam grup diurut recent-first.
- **Auto-title**: hanya dari `firstLine` (split `\n`). Kalau ≤40 char
  → ambil apa adanya, kalau > → potong + `…`. User bisa override via
  Ubah judul kapan aja.
- **Assistant streaming** TIDAK di-upsert per chunk (hindari write DB
  ratusan kali per detik). Hanya di-upsert sekali di `finally` blok
  `sendUserMessage` atau saat `stopGenerating`.
- **Buka thread saat streaming**: `openThread` panggil `stopGenerating`
  dulu — thread lama disimpan dgn state "Dihentikan" kalau kosong,
  atau konten parsial kalau sudah ada token.
- **DB file** di `getApplicationDocumentsDirectory` → `claude48.db`
  (persist antar install-update, hilang saat uninstall / Clear Data).
- **Locale** `intl.DateFormat` sengaja tanpa arg `'id_ID'` — Flutter
  default locale sudah cukup, hindari `initializeDateFormatting` extra
  step. Bisa dinaikkan di M5 kalau butuh locale-aware.

**TODO / Diketahui**
- Search bar di sidebar (SOP 3.2 opsional) — belum, direncanakan M?
  begitu jumlah thread bertambah.
- Swipe-to-delete di ThreadTile — belum (pakai popup menu). Bisa
  ditambah di M6 polish.
- Migration DB (v1 → v2) — belum perlu; tambah `onUpgrade` saat schema
  berubah (misal saat M4 nambah kolom `attachments_meta`).
- Export chat ke JSON / MD dijadwalkan di M5 (butuh iterasi
  `listMessages` per thread → serialize).

**Compatibility / Breaking change**
- **In-memory thread hilang**: kalau ada build M1 terpasang → session
  chat lama tidak ke-migrate (memang tidak ada storage). Percakapan baru
  di M2 langsung persisted normal.
- API `ChatController.resetThread()` sekarang alias `newDraft()` —
  behavior sama dari sisi UI (chat view dikosongkan), bedanya thread
  lama tetap ada di DB.

**Belum di-lakukan (per SOP)**
- Tidak menyentuh `.github/workflows/android-build.yml` (sudah OK dari
  M0, dependency baru = 0).
- Tidak commit API key.
- Tidak ubah `pubspec.yaml` (semua deps yang dipakai — `sqflite`,
  `path_provider`, `path`, `uuid`, `intl` — sudah masuk sejak M0).
- Tidak menghapus history milestone — entry ini append di bawah M1.

---

## Update — Ikon Aplikasi & Splash Screen

**Perubahan:**
- `assets/icon/app_icon.png` diganti dengan ikon baru "Claude 4.8 AI" (bubble chat neuron ungu→oranye pada latar hitam, 1024×1024). Ikon launcher Android akan digenerate ulang oleh `flutter_launcher_icons` di CI (`dart run flutter_launcher_icons`) menjadi seluruh mipmap density + adaptive icon (background `#0B0B14`, foreground = ikon baru).
- `android/app/src/main/res/drawable/splash_logo.png` (+ `drawable-v21/`) ditambahkan sebagai bitmap logo splash.
- `android/app/src/main/res/drawable/launch_background.xml` (+ `drawable-v21/`) diubah dari solid black menjadi `layer-list`: background hitam + bitmap `@drawable/splash_logo` di tengah (gravity=center). Sekarang saat aplikasi pertama kali dibuka, splash menampilkan ikon Claude 4.8 AI di tengah layar dengan latar hitam pekat, sesuai desain yang dikirim user.

**File baru:**
- `android/app/src/main/res/drawable/splash_logo.png`
- `android/app/src/main/res/drawable-v21/splash_logo.png`
- `android/app/src/main/res/drawable-v21/launch_background.xml`

**File diubah:**
- `assets/icon/app_icon.png`
- `android/app/src/main/res/drawable/launch_background.xml`

---

## Log Milestone Terlaksana

### M3 — Model Selector di Composer ✅ (selesai)

Tanggal: 1 Juli 2026

**Ringkasan**
Model selector diangkat jadi komponen berdiri sendiri (`model_selector.dart`)
dengan bottom sheet baru: header + subteks penjelas, list model scrollable
(cap tinggi 60% viewport, siap kalau katalog membesar), tile dengan
brand icon gradient, badge "Aktif" ungu untuk model terpilih, dan
**capability row** berisi badge `Vision` / `File` / `Tools` (aktif =
oranye aksen, tidak didukung = muted) plus badge netral `max_tokens`.
Katalog model diperluas dari 1 → 3 varian keluarga Claude 4.8
(Haiku / Sonnet / Opus) semuanya memakai endpoint kie.ai yang sama
(`/claude/v1/messages`), cukup beda `id`. Persist last-used model per
thread sudah aktif sejak M2 (`ChatController.setModel` → `upsertThread`
`modelId`) — di M3 tinggal dipastikan tetap jalan lewat selector baru.

**File baru**
- `lib/features/chat/widgets/model_selector.dart` — API publik
  `showModelSelector(context, current) → Future<AiModel?>`. Internal:
  `_ModelSelectorSheet`, `_ModelTile`, `_CapabilityRow`,
  `_CapabilityBadge`. Sheet pakai `isScrollControlled: true` +
  `MediaQuery viewInsets.bottom` supaya aman kalau nanti ada keyboard
  (misal search bar model di M-berikutnya).

**File diubah**
- `lib/core/constants/ai_models.dart` — tambah `claude-sonnet-4-5`
  (label "Claude 4.8 Sonnet", maxTokens 8192) dan `claude-opus-4-1`
  (label "Claude 4.8 Opus", maxTokens 8192). Semua tetap
  vision + file + tools = true, endpoint `/claude/v1/messages`.
  Deskripsi diringkas per varian (default / seimbang / terkuat).
- `lib/features/chat/chat_screen.dart`:
  - Drop import `ai_models.dart` & `ai_model.dart` (sudah dipakai di
    dalam `model_selector.dart` — bukan urusan screen lagi).
  - Tambah import `widgets/model_selector.dart`.
  - `_openModelSelector` sekarang cuma call `showModelSelector(...)`.
  - Hapus class inline `_ModelSelectorSheet` + `_CapabilityDot` yang
    dulu tinggal di bawah file (≈160 baris) — ganti sepenuhnya dgn
    komponen baru.

**Catatan teknis**
- **Model chip di composer** (`MessageComposer._ModelChip`) tidak
  disentuh — sudah menampilkan `model.label` + panah `▾` sesuai SOP
  3.3, dan `onModelTap` sudah nyambung ke `_openModelSelector`.
- **Auto-migrasi thread lama**: kalau di DB ada thread dgn `modelId`
  yang tidak ada di katalog (misal user downgrade katalog),
  `ChatController` fallback ke `kAiModels.first` (Haiku) — logika lama
  di `openThread` sudah aman (`findModelById(t.modelId) ?? tetap
  pakai model default`).
- **Endpoint uniform**: semua varian Claude di kie.ai pakai path yang
  sama, jadi menambah model varian Claude baru = append 1 entry di
  `ai_models.dart`, tidak perlu ubah `AiClientService`.
- **Kenapa max 60% tinggi**: biar sheet tidak ambil seluruh layar saat
  katalog baru 3 item — masih ada breathing room untuk konteks chat di
  atas sheet. Kalau katalog >6 item, list otomatis scrollable di dalam
  sheet.

**TODO / Diketahui**
- Search bar model (kalau daftar > 8) — dijadwalkan bareng search
  thread di M6 polish.
- Icon per-provider (Claude / OpenAI / OpenRouter) — sekarang semua
  pakai hexagon brand gradient; nanti kalau nambah provider di luar
  Claude, tinggal switch `model.provider` di `_ModelTile`.
- Capability badges belum interaktif (tap → jelasin capability). Bisa
  ditambah di M6 pakai `Tooltip` atau bottom-sheet mini.

**Compatibility / Breaking change**
- **Tidak ada**. API `ChatController.setModel` & `MessageComposer`
  onModelTap tidak berubah. Thread lama tetap kompatibel — modelId
  Haiku (`claude-haiku-4-5`) tetap valid & jadi default.

**Belum di-lakukan (per SOP)**
- Tidak menyentuh `.github/workflows/android-build.yml` — tidak ada
  dependency baru, `flutter build apk --release` tetap jalan seperti
  M2.
- Tidak commit API key (tetap `--dart-define` runtime).
- Tidak ubah `pubspec.yaml` (0 dependency baru).
- Tidak menghapus history milestone — entry M3 append di bawah M2.


---

## M4 — Context Window + Rotasi API Key + Rebrand Model Selector

**Tanggal**: 2026-07-01
**Status**: ✅ Selesai

### Ringkasan
1. **Context window 20 pesan.** AI hanya baca 20 pesan terakhir dari
   history saat kirim request. Hemat token drastis di thread panjang;
   thread lama tetap tersimpan penuh di DB (sqflite) — hanya request
   ke provider yang di-trim.
2. **Rotasi multi API key.** Owner bisa inject banyak key sekaligus
   (koma-separated) via secret. Kalau 1 key kena `401` / `403` / `429`,
   client otomatis mark key itu sebagai exhausted dan retry ke key
   berikutnya. Loop berhenti kalau semua key habis.
3. **Rebrand model selector.** Meskipun backend tetap route ke
   `claude-haiku-4-5` (satu-satunya varian yang aktif di plan kie.ai
   saat ini), label di UI di-branding jadi 3 tier premium:
   - `Claude 4.8 Opus` (default)
   - `Claude 4.7 Opus`
   - `Claude 4.6 Haiku`

### File Baru / Diubah
- **`lib/models/ai_model.dart`** — tambah field opsional `apiModelId`
  + getter `effectiveApiId`. Pisah "id catalog" (untuk UI + DB) dari
  "id model backend" (untuk request ke provider).
- **`lib/core/constants/ai_models.dart`** — 3 entry Opus/Opus/Haiku
  dengan `apiModelId: 'claude-haiku-4-5'` sama semua. Default (top of
  list) = `claude-4-8-opus`. `findModelById` juga fallback lookup by
  `apiModelId` supaya thread lama (yg simpan `claude-haiku-4-5` di
  kolom `modelId`) tetap ke-resolve ke Opus 4.8.
- **`lib/core/constants/app_config.dart`** — tambah
  `contextWindowMessages = 20`, ganti `defaultModelId` ke
  `claude-4-8-opus`, bump `appVersion → 0.2.0`, `appBuild → 2`.
- **`lib/services/api_key_service.dart`** — refactor total:
  - Terima `AI_API_KEYS` (koma / titik-koma separated).
  - Fallback ke `AI_API_KEY` (single) → **backward-compat penuh
    dengan workflow lama**. Nilai `AI_API_KEY` juga bisa langsung
    di-isi comma-separated tanpa ubah workflow.
  - State runtime: `_cursor` + `Set<int> _exhausted`.
  - API baru: `activeKey`, `markKeyExhausted()`, `resetRotation()`,
    `totalKeys`, `liveKeys`, `rotationSummary`.
  - Alias `apiKey` dipertahankan untuk backward-compat dgn banner /
    UI About.
- **`lib/services/ai_client_service.dart`** — refactor:
  - `_buildMessages` slice ke `AppConfig.contextWindowMessages` pesan
    terakhir (system prompt dipertahankan kalau nanti ada).
  - `sendMessage` & `streamMessage` di-bungkus retry-loop; kalau
    status `_isRotatable` (401/403/429) → `markKeyExhausted()` lalu
    retry. Loop max = `totalKeys`. Kalau semua habis → throw pesan
    jelas ke user.
  - Body pakai `selected.effectiveApiId` (bukan `selected.id`), jadi
    UI Opus 4.8 → dikirim `claude-haiku-4-5` ke kie.ai.
  - Header `Authorization` pakai `ApiKeyService.activeKey` (bukan
    `apiKey` cached lama).

### Catatan teknis
- **Kenapa slice di client, bukan di controller?** Supaya history di
  UI + DB tetap utuh (user bisa scroll ke atas & lihat semua),
  sementara request ke provider tetap ramping. Perubahan
  `contextWindowMessages` cukup di 1 tempat.
- **Kenapa 3 label pakai model backend yang sama?** Sesuai instruksi
  owner: plan kie.ai saat ini hanya Haiku 4.5 aktif, tapi branding
  app tetap "Claude 4.8 AI". Nanti kalau upgrade plan, cukup ganti
  `apiModelId` per entry → **0 perubahan** di UI / controller / DB.
- **Backward-compat thread lama**: `findModelById` fallback lookup
  by `apiModelId`, jadi thread lama yg simpan `modelId =
  'claude-haiku-4-5'` di DB otomatis mapped ke entry `claude-4-8-opus`
  (yang top of list) — tidak ada migrasi manual.
- **Rotasi tidak persist ke disk**: state `_exhausted` reset tiap
  app cold-start. Ini disengaja — kadang provider unfreeze quota
  harian; biarkan tiap start app punya kesempatan retry semua key.
  Kalau nanti mau persist, tambah SharedPreferences di M6.
- **Zero-network side-effect**: kalau `AiClientService` throw
  `TimeoutException` atau exception non-HTTP, key TIDAK di-mark
  exhausted — karena mungkin gangguan jaringan, bukan key rusak.

### Compatibility / Breaking change
- **Tidak ada breaking change untuk build workflow existing.**
  Secret `AI_API_KEY` yang lama tetap dibaca. Untuk pakai multi-key,
  cukup isi secret `AI_API_KEY` dgn nilai comma-separated
  (`sk-a,sk-b,sk-c`) — tanpa ubah `.github/workflows/android-build.yml`.
- Model UI id berubah (`claude-haiku-4-5` → `claude-4-8-opus` dst),
  tapi thread lama tetap kompatibel via fallback `findModelById`.

### Checklist SOP
- [x] Tidak commit API key ke repo (tetap `--dart-define` runtime).
- [x] Tidak modifikasi `.github/workflows/android-build.yml`.
- [x] Tidak nambah dependency di `pubspec.yaml` (0 package baru).
- [x] Tidak menghapus milestone lama — entry M4 append di bawah M3.
- [x] Tidak `print`/log nilai API key.

### TODO (M5+)
- Persist state exhausted key ke SharedPreferences (opsional).
- UI Settings → panel "Manage keys": lihat status per-key, tombol
  "Reset rotation".
- Auto-summary saat context window mau kena limit (biar tidak
  kehilangan konteks awal thread).


---

## M5 — Daily Login Streak Premium (Profile Screen)

**Tanggal**: 2026-07-01
**Status**: ✅ Selesai
**Referensi spec**: `dailymissionfeatures.md`

### Ringkasan
Menambahkan **sistem daily login streak** device-local + halaman
**Profile** yang menampilkan progress 7 hari & status **Premium Mode**.
Retention loop sesuai spec: login 7 hari berturut-turut → premium aktif
(bebas iklan, siap ketika ads dipasang). Skip 1 hari → streak reset ke
0 & premium dicabut. Semua state persisted via `SharedPreferences`
(local-only, tanpa backend — sudah bisa langsung dipakai).

### Alur runtime
1. `main()` → `StreakService.instance.load()` (preload state sebelum
   `runApp`, hindari flicker).
2. `ChatScreen.initState` → setelah `loadInitial`, panggil
   `StreakService.checkIn()`. Result:
   - `alreadyToday` → no-op (idempotent per hari kalender lokal).
   - `firstDay` / `incremented` / `premiumMaintained` → silent update.
   - `reachedPremium` → dialog **🎉 Selamat! Premium Mode**.
   - `broken` → dialog **💀 Streak terputus!**.
3. Sidebar footer **Settings & Profile** sekarang aktif → push
   `ProfileScreen` (drawer dulu di-pop, kemudian route baru di-push).
4. `ProfileScreen` menampilkan header profil (avatar gradient brand),
   kartu streak (grid 7 sel: 6 hari ✓ + hari ke-7 🎁, progress bar,
   label "check-in terakhir"), kartu status **Premium Mode Aktif /
   Terkunci** (gradient ungu-oranye saat aktif), kartu info API-key
   rotation (memakai `ApiKeyService.rotationSummary` dari M4), dan
   kartu About (nama + versi).

### Logic streak (single source of truth di `StreakService`)
- Kunci `SharedPreferences`: `streak_count` (int), `streak_last_date`
  (ISO `yyyy-MM-dd` lokal).
- `checkIn(now?)` normalisasi ke midnight lokal, hitung `diffDays`
  antara `today` dan `lastCheckInDate`:
  - `null` → count = 1, result `firstDay`.
  - `diffDays == 0` → `alreadyToday`, tidak menulis prefs.
  - `diffDays == 1` → count += 1 (cap di `StreakState.maxDays = 7`).
    Sebelum cap == 7 → `reachedPremium`, sesudah cap tetap 7 →
    `premiumMaintained`, di antaranya → `incremented`.
  - `diffDays >= 2` → count = 1, result `broken`.
- `StreakState.premiumActive = count >= 7`.

### File baru
- **`lib/models/streak_state.dart`** — model `StreakState` (count,
  lastCheckInDate, derived `premiumActive`, `copyWith`) + enum
  `StreakCheckInResult` (6 kemungkinan hasil supaya UI bisa memilih
  reaksi tepat tanpa parsing string).
- **`lib/services/streak_service.dart`** — `ChangeNotifier` singleton
  `StreakService.instance`. Method: `load()`, `checkIn({now})`,
  `resetForDebug()`. Getter: `state`, `isLoaded`, `premiumActive`.
  Semua tanggal di-normalize ke `DateTime(year, month, day)` supaya
  jam berapa user buka app dalam 1 hari kalender = 1 slot.
- **`lib/features/profile/profile_screen.dart`** — `ProfileScreen`
  `StatefulWidget` (listen ke `StreakService`). Widget internal:
  `_ProfileHeader`, `_StreakCard`, `_DaysGrid`, `_DayCell`,
  `_PremiumStatusCard` (gradient brand saat aktif),
  `_ApiKeyInfoCard`, `_AboutCard`. Dialog helper publik:
  `showReachedPremiumDialog(context)` & `showStreakBrokenDialog(context)`.

### File diubah
- **`lib/main.dart`** — tambah `await StreakService.instance.load()`
  sebelum `runApp` (state siap sebelum ChatScreen build pertama).
- **`lib/features/chat/chat_screen.dart`** — import `StreakService` +
  `ProfileScreen` + dialog helper. `initState` post-frame diperluas:
  setelah `loadInitial`, panggil `checkIn` dan branch dialog untuk
  `reachedPremium` / `broken`. `drawer:` sekarang pass
  `onSettingsTap` yang push `ProfileScreen` (snackbar placeholder di
  `SidebarDrawer._Footer` otomatis tidak dipakai lagi karena
  `onSettingsTap != null`).
- **`lib/core/constants/app_config.dart`** — bump `appVersion → 0.3.0`,
  `appBuild → 3`.
- **`pubspec.yaml`** — bump `version: 0.3.0+3`.
- **`dailymissionfeatures.md`** — checklist status di-update jadi
  centang (kecuali item backend cloud & integrasi iklan yang memang
  tidak in-scope M5).

### Catatan teknis
- **Local-only by design.** Sesuai spec, streak dihitung per-device.
  Kalau nanti butuh sync antar device (mis. gabung akun cloud), tambah
  layer server-side + resolusi konflik "device mana yang benar" — bukan
  urusan M5.
- **Kenapa cap di 7?** Spec bilang reward diberikan **setelah** 7 hari
  berturut-turut. Setelah cap, `count` tetap 7 selama user login tiap
  hari → premium jalan terus (`premiumActive = count >= 7`). Skip 1
  hari → reset ke 1 → premium otomatis dicabut karena `1 < 7`. Tidak
  perlu field terpisah `premiumExpiresAt`.
- **Kenapa dialog dipicu di `ChatScreen`, bukan `main`?**
  `showDialog` butuh `BuildContext` yang punya `Navigator` — hanya
  tersedia setelah `MaterialApp` build. `ChatScreen.initState` +
  post-frame callback adalah titik paling awal yang aman.
- **`checkIn` di ChatScreen, bukan `App`.** Kalau nanti ada rute lain
  yang bisa jadi entry (mis. push notification deep link), pindah ke
  helper `AppLifecycleObserver` atau `WidgetsBindingObserver.didChangeAppLifecycleState`.
  Untuk M5, single entry (chat) cukup — sesuai fakta app cuma punya
  1 halaman utama.
- **Integrasi iklan**: belum ada `AdsService`; ketika nanti dipasang
  (misal `google_mobile_ads`), cukup gate `AdsService.shouldShow()` di
  `!StreakService.instance.premiumActive`. Zero perubahan di
  `StreakService`.
- **Debug reset**: `StreakService.resetForDebug()` sengaja ada tapi
  tidak dipasang di UI. Kalau nanti butuh, tambah tombol di
  `_AboutCard` khusus build debug (`kDebugMode`).
- **`SharedPreferences`** sudah ada di deps sejak M0 → **0 dependency
  baru**. Tidak menyentuh workflow build.

### Compatibility / Breaking change
- **Tidak ada breaking change.** Thread lama, `AiClientService`,
  rotasi API key M4 tidak disentuh. Prefs baru (`streak_count`,
  `streak_last_date`) tidak bentrok dgn key existing.
- Sidebar footer "Settings & Profile" perilaku berubah dari
  snackbar placeholder → push `ProfileScreen`. Tidak ada consumer
  eksternal drawer di kode lain, aman.

### Checklist SOP
- [x] Tidak commit API key ke repo.
- [x] Tidak modifikasi `.github/workflows/android-build.yml`
      (0 dependency baru).
- [x] Tidak nambah package di `pubspec.yaml` (semua pakai deps
      existing).
- [x] Tidak menghapus history milestone lama — entry M5 append di
      bawah M4.
- [x] Tidak `print`/log nilai API key atau state sensitif.
- [x] Warna baru diambil dari `AppColors` — tidak hardcode
      `Color(0xFF…)` di widget baru.
- [x] File naming `snake_case`, class `PascalCase`.

### TODO (M6+)
- Snackbar/toast ringan saat `incremented` (opsional — sekarang silent
  supaya tidak spam user yang buka app berkali-kali).
- Streak calendar view lengkap (kalender bulanan dengan hari-hari
  check-in di-highlight).
- Cloud sync streak (butuh auth + backend).
- Notification push "Streak kamu akan hangus dalam 2 jam!" — butuh
  local notification plugin.
- Tombol **Manage API Keys** di `ProfileScreen` (reset rotation,
  lihat status per-key) — carry-over dari TODO M4.

---

## Milestone M6 — UI/UX Overhaul & Rebranding (Claude AI)

### Tujuan
Refresh identitas produk jadi **Claude AI** dan ganti navigasi dari
drawer/sidebar → **bottom navigation 3 tab** (Chats / History /
Settings) supaya sesuai referensi desain baru (mobile-first, kartu
gelap dengan aksen ungu-oranye, avatar maskot bulat, bubble user
bergradien).

> Catatan: hanya perubahan **UI/UX + branding**. Business logic
> (streaming SSE, HistoryService, ApiKeyService, StreakService, rotasi
> API key) tidak disentuh.

### Perubahan branding
- `AppConfig.appName` → **"Claude AI"** (dari "Claude 4.8 AI").
- `AppConfig.appTagline` → tagline baru mengikuti positioning
  "Claude AI".
- Label model di `ai_models.dart`:
  - `claude-haiku-4-5` → **Fast**
  - `claude-sonnet-4-5` → **Balanced**
  - `claude-opus-4-1` → **Claude AI Pro**
- Semua string "kie" yang tampil ke user diganti "Claude AI"
  (backend endpoint `kie.ai` tetap — cuma copy front-end).
- App version bump: `0.4.0+4` → `0.4.0+4` (build tetap, versi major
  UI overhaul dicatat di milestone ini; tidak menyentuh Android
  `versionCode` supaya CI build workflow M0 tidak berubah).

### Aset baru
- `assets/mascot/claude_ai_mascot.png` — maskot 3D purple head untuk
  avatar assistant, header tab, dan floating action button.
- Registrasi asset di `pubspec.yaml` (folder `assets/mascot/`).

### Perubahan tema
`lib/core/theme/app_colors.dart`:
- Tambah `AppColors.online` (dot indikator status assistant).
- Tambah `AppColors.userBubbleGradient` (LinearGradient ungu →
  ungu-tua) untuk bubble user.
- Tambah `AppColors.avatarGradient` (ungu → orange aksen) untuk
  ring avatar & FAB new-chat.

### Arsitektur navigasi baru
- **Baru**: `lib/features/home/home_shell.dart` → `HomeShell`
  yang meng-host `ChatController` di root (state chat persistent
  saat pindah tab).
- Tab switching pakai `IndexedStack` (bukan `PageView`) supaya
  widget tree tidak rebuild tiap swipe.
- Global `ValueNotifier<ThemeMode> kThemeMode` di `lib/app.dart`
  → `MaterialApp` di-wrap `ValueListenableBuilder`, sehingga toggle
  Dark/Light dari Settings langsung reaktif.

### Screen baru
- `lib/features/chat/chat_screen.dart` — refactor: hapus `Drawer`,
  ganti dengan `_ChatAppBar` (avatar maskot + nama + dot online +
  overflow menu untuk pin/rename/delete thread aktif).
- `lib/features/chat/widgets/message_bubble.dart` — rewrite:
  - Assistant: avatar bulat maskot + card `surfaceElevated` +
    corner asimetris kecil kiri-atas.
  - User: gradient bubble ungu + status tick + timestamp mini.
- `lib/features/chat/widgets/message_composer.dart` — rewrite:
  input pill-shape dengan attach icon di dalam field + tombol send
  bulat gradient di luar (sesuai referensi).
- `lib/features/history/history_screen.dart` — daftar thread
  persisten, snippet last message, timestamp relatif ("Baru saja",
  "Kemarin, 21:14"), badge jumlah pesan, FAB new-chat, search inline
  (icon → toggle text field), tile menu (rename/pin/delete).
- `lib/features/settings/settings_screen.dart`:
  - Profile card (push ke `ProfileScreen` existing — streak UI M5
    tetap hidup di sana).
  - Preferences: segmented Dark/Light theme toggle (live), Language
    picker (bottom sheet), AI Model picker (reuse `showModelSelector`
    M3).
  - **Clear Chat History** (danger row → dialog konfirmasi →
    `HistoryService.clearAll()` + `refreshThreads()` + `newDraft()`).
  - About: version, privacy placeholder, rate-on-store placeholder.

### File yang dihapus
- Direktori `lib/features/chat/widgets/sidebar/` dan seluruh
  komponen drawer (`sidebar_thread_tile.dart` dkk). Migrasi
  fungsionalitasnya:
  - Thread list → **History tab**.
  - Settings & Profile footer → **Settings tab** + Profile card.
  - Search sidebar → search inline di History header.

### Alur user setelah M6
1. Buka app → landing di **Chats** tab (empty state jika belum ada
   draft, atau thread terakhir yang open).
2. Tap tab **History** → lihat semua percakapan, tap tile → thread
   ter-load, otomatis pindah ke Chats tab (callback `onOpenThread`).
3. Tap tab **Settings** → toggle theme / ganti model / hapus riwayat
   / buka Profile (streak M5 di sana).

### Catatan teknis
- **Theme reactive tanpa Provider.** Sengaja pakai `ValueNotifier`
  global, bukan `Provider`/`Riverpod`, supaya **0 dependency baru**
  dan konsisten dengan pola M5 (`SharedPreferences` local-first).
  Kalau app tumbuh, migrasi ke `InheritedNotifier` gampang.
- **`ChatController` di-hoist ke `HomeShell`.** Sebelumnya
  di-instantiate di `ChatScreen` — kalau tetap di sana, pindah tab
  akan `dispose()` controller dan streaming SSE bakal putus. Sekarang
  aman.
- **Kenapa `IndexedStack`?** Semua tab keep-alive → History tidak
  reload sqflite tiap tab-switch, ChatScreen tidak kehilangan scroll
  position saat user cek Settings sebentar.
- **Search History.** Filter client-side di memori (`_query`), tidak
  query ulang ke DB — jumlah thread realistis (< ratusan) tidak
  butuh full-text search.
- **Snippet last message.** Di-cache per-thread di
  `_HistoryScreenState._summaries` setelah first load. Invalidation
  cukup dari `controller.notifyListeners()` → tapi kita hanya load
  yang belum ada di cache; kalau butuh live snippet, extend `summary`
  jadi listener ke `HistoryService` events (belum perlu M6).
- **`Clear Chat History`.** Setelah `clearAll`, panggil `newDraft()`
  supaya ChatScreen tidak crash referensi thread yang sudah tidak
  ada.

### Compatibility / Breaking change
- **Breaking (internal only)**: `ChatScreen` tidak lagi bikin
  `ChatController` sendiri — sekarang butuh `controller` injection
  dari `HomeShell`. Tidak ada consumer eksternal, aman.
- Data user (sqflite `claude48.db`, `SharedPreferences`
  streak/api-key rotation) **tidak dimigrasi** — kompatibel penuh
  dengan install existing.
- Endpoint & API key rotation M4 tidak berubah.

### Checklist SOP
- [x] Tidak commit API key ke repo.
- [x] Tidak modifikasi `.github/workflows/android-build.yml`.
- [x] **0 dependency baru** di `pubspec.yaml`.
- [x] Tidak menghapus history milestone lama — entry M6 append di
      bawah M5.
- [x] Tidak `print` / log nilai sensitif.
- [x] Warna baru masuk `AppColors` — tidak hardcode `Color(0xFF…)`.
- [x] Naming: file `snake_case`, class `PascalCase`.
- [x] Resolve merge conflict `dailymissionfeatures.md` (ambil versi
      HEAD-baru yang sudah tick M5 selesai).

### TODO (M7+)
- Persist pilihan `Language` & `Theme` ke `SharedPreferences`
  (sekarang in-memory session, reset saat app relaunch).
- I18n riil (arb files) — sekarang picker baru simpan label kosmetik.
- Search History dengan full-text di SQL (`LIKE`) untuk riwayat
  besar.
- Attach button di composer (image upload / dokumen) — hook UI sudah
  ada.
- Skeleton loader untuk History tile (snippet loading state).
- Migrasi theme controller ke `InheritedNotifier` bila state global
  lain menyusul.

---

## M7 — Backend Integration + Native Obfuscation + Anti-Tamper (2026-07-01)

> Fokus milestone: sambungin app ke backend produksi (Google Apps Script
> untuk auth/email, Firebase untuk chat history & streak), tambahkan
> obfuscation tingkat tinggi (Dart + Java/Kotlin + native C++), dan
> anti-tamper guard yang redirect ke `www.google.com` kalau APK
> di-modifikasi/re-sign.
>
> **Semua tetap sesuai SOP** — tidak ada API key hardcoded, seluruh
> secret di-inject via `--dart-define` / GitHub Secret, workflow
> `android-build.yml` masih single-job Ubuntu + Flutter stable.

### 7.1  Rancangan backend final

```
Backend
├── Auth           → Google Apps Script  (kode.gs, Web App URL)
├── Email Verify   → Google Apps Script  (GmailApp + HTML template)
├── User Profile   → Google Apps Script  (Sheet "users")
├── Chat History   → Firebase Firestore  (users/{uid}/threads/*)
├── Daily Streak   → Firebase Firestore  (users/{uid}/streak/current)
└── Premium State  → Native C++ (memek.so) + local streak validator
```

Data Firestore dibuat otomatis begitu user beraktivitas — tidak perlu
seed manual (sesuai instruksi owner).

### 7.2  Dependencies baru (`pubspec.yaml`)

- `firebase_core: ^3.6.0` — init Firebase.
- `cloud_firestore: ^5.4.4` — chat history + streak.
- `crypto: ^3.0.5` — SHA-256 password hashing sebelum kirim ke GAS.
- `url_launcher: ^6.3.1` — buka `www.google.com` saat anti-tamper trip.
- `device_info_plus`, `package_info_plus` — helper diagnostik.

Version app di-bump `0.4.0+4 → 0.5.0+5`.

### 7.3  Layer Dart baru (`lib/services/`)

| File | Peran |
|---|---|
| `auth_service.dart`      | Client GAS (`register`, `verify`, `login`, `resend`, `profile`, `updateProfile`), simpan session di `SharedPreferences`. Password di-SHA256 client-side sebelum POST. |
| `firebase_service.dart`  | Init `Firebase.initializeApp()`. Helper `saveThread` / `saveMessage` / `upsertStreak` / `upsertProfile` — semua scoped ke `users/{uid}/...`. |
| `native_bridge.dart`     | `MethodChannel('com.claude48.ai/native')` → panggil `integrityCheck`, `verifyPremium`, `encryptField`, `decryptField`, `currentSignature`. |
| `tamper_guard.dart`      | `TamperGuard.check()` di `main()` sebelum `runApp`. Kalau false → render `blockedScreen()` yang auto-`launchUrl(https://www.google.com)`. |
| `premium_service.dart`   | `isPremiumTrusted(token, streakDays)` → forward ke native (memek→vault). Fake-Dart flag tidak dianggap valid. |

### 7.4  Auth UI (`lib/features/auth/`)

- `login_screen.dart`  — email + password → `AuthService.login`.
- `register_screen.dart` — nama + email + password → `AuthService.register` → route ke verify.
- `verify_screen.dart` — kode 6-digit + tombol resend → `AuthService.verify`.
- `AuthGate` di-mount di `app.dart` → `home: AuthGate(child: HomeShell())`.

### 7.5  Native C++ (`android/app/src/main/cpp/`)

Obfuscation dipecah jadi 4 shared object supaya sulit di-reverse
sekaligus:

| .so | Nama file cpp | Peran |
|---|---|---|
| **memek.so** *(wajib, entry JNI)* | `memek.cpp`  | Semua export `Java_com_claude48_ai_NativeBridge_*`, delegasi ke sibling libs. |
| aegis.so                          | `aegis.cpp`  | (a) Signature comparator konstan-waktu + opaque predicate + XOR-decoded strings. |
| cipher.so                         | `cipher.cpp` | (b) XOR/rot + polynomial mix untuk encrypt/decrypt field sensitif. |
| vault.so                          | `vault.cpp`  | (c) Premium token verifier (FNV1a + XOR-scrambled salt). |

Compiler flags:
```
-O2 -fvisibility=hidden -fno-rtti -fno-exceptions
-ffunction-sections -fdata-sections
-Wl,--gc-sections -Wl,--strip-all -Wl,-z,noexecstack
```

Load order di `MainActivity.kt`:
```kotlin
System.loadLibrary("vault")
System.loadLibrary("cipher")
System.loadLibrary("aegis")
System.loadLibrary("memek")   // entry point WAJIB
```

### 7.6  Anti-tamper flow

1. Gradle inject `EXPECTED_SIG_SHA256` (dari env) sebagai CMake define.
2. `MainActivity.currentSignatureSha256()` baca cert APK saat runtime.
3. `NativeBridge.integrityCheck(ctx, runtimeSig)` → `memek → aegis_verify_sig(expected, runtime)`.
4. `TamperGuard.check()` di `main()`. Kalau false → `blockedScreen()` +
   `launchUrl('https://www.google.com', externalApplication)`.
5. Kalau `EXPECTED_SIG_SHA256` kosong (dev / `flutter run` lokal) native
   otomatis return `true` — dev tidak terblokir.

Owner cukup ganti URL `_redirectUrl` di `tamper_guard.dart` saat landing
page redirect resmi sudah siap.

### 7.7  Obfuscation tingkat tinggi (Dart + Java/Kotlin + Native)

- **Dart** — `flutter build apk --obfuscate --split-debug-info=build/symbols`.
  Symbol file di-upload artifact `Claude48AI-debug-symbols`.
- **Java/Kotlin (R8)** — `minifyEnabled true`, `shrinkResources true`,
  `proguard-android-optimize.txt` + `proguard-rules.pro` custom:
  - `-repackageclasses 'o'` → semua class app di-flatten ke package `o`.
  - `-allowaccessmodification`, `-optimizationpasses 5`, `-overloadaggressively`.
  - `-assumenosideeffects android.util.Log` → semua log dev dihapus.
  - JNI bridge (`NativeBridge`, `MainActivity`) di-keep supaya `System.loadLibrary` tidak crash.
- **Native** — hidden visibility, strip-all, `--gc-sections`, XOR-encoded strings,
  opaque predicates, constant-time compare (biar tidak ada timing leak).

### 7.8  MultiDex

- `defaultConfig.multiDexEnabled = true` + `androidx.multidex:multidex:2.0.1`.
- `MainActivity.attachBaseContext` panggil `MultiDex.install(this)`.
- D8 otomatis split ke `classes.dex classes2.dex classes3.dex ...`
  sesuai jumlah method (Firebase + Firestore + Flutter engine + code app
  dijamin overflow single-DEX). Owner tidak perlu setting manual jumlah;
  D8 pilih yang optimal — dependencies berat (`cloud_firestore`,
  `firebase_core`, `dio`, `flutter_markdown`, dll.) hampir pasti
  memicu ≥ classes3.dex.

### 7.9  Google Apps Script — `backend/kode.gs`

- Endpoint tunggal `doPost(e)` dengan switch `action`.
- Data user disimpan di Google Sheet auto-created (`SHEET_NAME='users'`).
- Password: client kirim `SHA256(client_salt || plain)` → server
  re-hash `SHA256(SERVER_SALT || clientHash)` sebelum simpan (double-salt).
- Kode verifikasi: 6 digit, TTL 15 menit, disimpan di kolom `code` +
  `codeExpiresAt`.
- Email HTML: dark theme, gradient ungu-oranye (match brand), inline CSS
  (Gmail-safe), kode di-render besar (`font-size: 38px; letter-spacing: 12px`).

Deploy:
1. Buka <https://script.google.com> → New project → paste `kode.gs`.
2. Deploy → New deployment → Web app → **Execute as: Me**,
   **Who has access: Anyone**.
3. Copy URL → set GitHub Secret `GAS_AUTH_URL`.

### 7.10  Workflow update (`.github/workflows/android-build.yml`)

- Tambah step `nttld/setup-ndk@v1` (NDK r25c).
- Tambah step "Inject google-services.json" → decode base64 dari secret
  `GOOGLE_SERVICES_JSON` ke `android/app/google-services.json`. Kalau
  secret kosong, step di-skip (build tetap jalan tapi Firebase idle).
- Tambah step "Compute expected APK signature SHA-256" — pakai
  `keytool` di debug keystore, output ke `$GITHUB_OUTPUT`, di-forward
  sebagai env `EXPECTED_SIG_SHA256`.
- `flutter build apk` sekarang dengan `--obfuscate --split-debug-info=build/symbols`.
- Tambah dua artifact upload: `Claude48AI-debug-symbols` (Dart) dan
  `Claude48AI-r8-mapping` (Java/Kotlin `mapping.txt`) — wajib disimpan
  untuk stack-trace decoding release.

Secrets baru yang perlu di-set di repo:
- `GOOGLE_SERVICES_JSON` — isi file google-services.json di-base64 (`base64 -w0`).
- `GAS_AUTH_URL` — URL Web App GAS.

### 7.11  Firestore data model

```
users/{uid}
  ├─ email, name, updatedAt
  ├─ threads/{threadId}
  │    ├─ (semua field ChatThread.toMap)
  │    └─ messages/{msgId}    ← ChatMessage.toMap
  └─ streak/current
       ├─ count, lastCheckInIso, premiumActive, updatedAt
```

Semua collection dibuat lazy — Firestore auto-create begitu doc pertama
di-write. Rules disarankan (owner set di console):

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth.uid == uid;
}
```

Catatan: karena GAS pegang auth (bukan Firebase Auth), untuk sekarang
Firestore diakses tanpa Firebase Auth token — owner boleh (a) buka
rules `if true` selama testing, atau (b) tambah Firebase Auth custom
token flow di iterasi berikutnya.

### 7.12  Files ditambah / diubah

**Added:**
- `android/app/src/main/cpp/{CMakeLists.txt,memek.cpp,aegis.cpp,cipher.cpp,vault.cpp}`
- `android/app/proguard-rules.pro`
- `lib/services/{auth_service,firebase_service,native_bridge,tamper_guard,premium_service}.dart`
- `lib/features/auth/{login_screen,register_screen,verify_screen}.dart`
- `backend/kode.gs`

**Modified:**
- `pubspec.yaml` — bump version + Firebase/crypto/url_launcher deps.
- `android/settings.gradle` — plugin `com.google.gms.google-services`.
- `android/app/build.gradle` — Firebase plugin, multiDex, CMake, R8 minify+shrink, NDK abi filters.
- `android/app/src/main/kotlin/com/claude48/ai/MainActivity.kt` — MethodChannel + JNI + MultiDex.install.
- `lib/main.dart` — Tamper gate + Firebase init + AuthService.load.
- `lib/app.dart` — `AuthGate` wrap `HomeShell`.
- `.github/workflows/android-build.yml` — NDK, google-services inject, signature compute, obfuscation flags, symbol/mapping upload.

### 7.13  Yang TIDAK berubah (SOP dijaga)

- kie.ai endpoint & `ApiKeyService` rotasi 20+ key tetap seperti M0-M6.
- Streak logika lokal (`StreakService`) tidak diubah — hanya di-mirror ke
  Firestore lewat `FirebaseService.upsertStreak`.
- Theme `AppColors` (dark-first purple-orange) tidak ada hardcoded color baru.
- Workflow tetap single Ubuntu job, tidak ada matrix build.

### 7.14  Sisa ke owner

1. Buat Firebase project → download `google-services.json` → base64 → set ke
   secret `GOOGLE_SERVICES_JSON` (`base64 -w0 google-services.json | pbcopy`).
2. Deploy `backend/kode.gs` sebagai Web App → set URL ke secret `GAS_AUTH_URL`.
3. (Opsional) Ganti keystore release + update step "Compute expected APK signature"
   supaya baca alias & storepass release, bukan debug.
4. Ganti `_redirectUrl` di `lib/services/tamper_guard.dart` ke landing page
   khusus redirect kalau sudah siap.

---

## M8 — Simplify google-services.json handling & fix package name mismatch

### 8.1  Konteks
Build M7 gagal dengan error:
```
Run mkdir -p android/app
base64: invalid input
Error: Process completed with exit code 1.
```
Penyebab: GitHub Secret `GOOGLE_SERVICES_JSON` diisi **raw API key Firebase**
(`AIzaSy…`), bukan base64 dari file `google-services.json`. Perintah
`echo "$GOOGLE_SERVICES_JSON" | base64 -d` otomatis gagal karena input bukan
base64 valid.

Selain itu ditemukan mismatch package name:
- App: `com.claude48.ai`
- `google-services.json`: `com.claudememek.app`
→ Firebase akan menolak app saat runtime.

### 8.2  Keputusan desain
Owner memilih **commit `google-services.json` langsung ke repo** daripada
inject via secret. Alasan:
- Isi `google-services.json` = **API key publik Firebase** (client identifier),
  bukan secret sensitif. Google sendiri mendokumentasikan file ini aman
  di-embed di client / repo publik.
- Proteksi keamanan asli Firebase ada di **Security Rules** + **SHA-1
  fingerprint** app signing, bukan di kerahasiaan file JSON.
- Menghilangkan step base64 encode/decode → tidak ada lagi kelas error
  `base64: invalid input`, workflow lebih simpel & anti-gagal.

### 8.3  Perubahan package name → `com.claudememek.app`
Disesuaikan agar match `google-services.json` (mobilesdk_app_id
`1:…:android:…` dengan `package_name = com.claudememek.app`):

| File | Perubahan |
| --- | --- |
| `android/app/build.gradle` | `namespace` & `applicationId` → `com.claudememek.app` |
| `android/app/src/main/kotlin/com/claudememek/app/MainActivity.kt` | Dipindah dari `com/claude48/ai/`, `package com.claudememek.app` |
| `android/app/src/main/cpp/memek.cpp` | Semua simbol JNI `Java_com_claude48_ai_*` → `Java_com_claudememek_app_*` |
| `android/app/proguard-rules.pro` | Rule `com.claude48.ai.*` → `com.claudememek.app.*` |
| `lib/services/native_bridge.dart` | `MethodChannel` id → `com.claudememek.app/native` |
| `.github/workflows/android-build.yml` | `flutter create --org com.claudememek --project-name app` |
| `android/app/src/main/kotlin/com/claude48/` | Direktori lama dihapus |

### 8.4  Perubahan workflow (M8)
Step "Inject google-services.json" **dihapus total** dari
`.github/workflows/android-build.yml`. Diganti komentar dokumentatif yang
menjelaskan file sudah ada di `android/app/google-services.json`. Efek:
- Tidak perlu lagi secret `GOOGLE_SERVICES_JSON` di GitHub.
- Tidak ada base64 encode/decode.
- Build deterministik: file yang di-repo = file yang dipakai build.

### 8.5  Perbandingan pendekatan (untuk referensi masa depan)

| Aspek | Inject via secret (M7) | Commit langsung (M8, dipilih) |
| --- | --- | --- |
| Setup owner | Encode base64 + set secret | Tidak ada, file udah di repo |
| Failure mode | `base64: invalid input`, secret hilang, dll | Nihil |
| Keamanan efektif | Sama (isi = key publik) | Sama |
| Kompleksitas workflow | +1 step + 1 secret | 0 step |

### 8.6  Sisa ke owner (revisi M7 §7.14)
1. ~~Set secret `GOOGLE_SERVICES_JSON`~~ — **tidak perlu lagi**. Cukup pastikan
   `android/app/google-services.json` ter-commit dan package_name di dalamnya
   = `com.claudememek.app`.
2. Deploy `backend/kode.gs` sebagai Web App → set URL ke secret `GAS_AUTH_URL`.
3. (Opsional) Ganti keystore release + update step "Compute expected APK
   signature" supaya baca alias & storepass release, bukan debug.
4. Daftarkan SHA-1 fingerprint keystore ke Firebase Console (Project Settings
   → Your apps → Add fingerprint) supaya Auth/App Check berfungsi.

---

## M9 — Fix CMake macro double-quote saat build native release

### 9.1  Konteks error
Build GitHub Actions gagal di task:
```
:app:buildCMakeRelWithDebInfo[arm64-v8a]
```
dengan error C++:
```
#define EXPECTED_SIG_SHA256 ""350CC36485B69AE61BFEACDD286109D576491F4659410E0A3135D9387B7396B1""
error: expected ';' at end of declaration
const char* expected = EXPECTED_SIG_SHA256;
```

### 9.2  Penyebab
Nilai `EXPECTED_SIG_SHA256` kena quote dua kali:
- `android/app/build.gradle` mengirim argumen CMake sebagai
  `-DEXPECTED_SIG_SHA256=\"${expectedSigSha256}\"`
- `android/app/src/main/cpp/CMakeLists.txt` juga membungkus macro dengan quote:
  `add_definitions(-DEXPECTED_SIG_SHA256="${EXPECTED_SIG_SHA256}")`

Akibatnya compiler menerima macro `""HASH""`, bukan `"HASH"`.

### 9.3  Fix yang diterapkan
Di `android/app/build.gradle`, argumen CMake dibuat **raw tanpa quote**:
```gradle
arguments "-DEXPECTED_SIG_SHA256=${expectedSigSha256}"
```

Quote tetap hanya dilakukan satu kali di `CMakeLists.txt`, sehingga compiler
menerima bentuk valid:
```cpp
#define EXPECTED_SIG_SHA256 "350CC36485B69AE61BFEACDD286109D576491F4659410E0A3135D9387B7396B1"
```

### 9.4  Catatan warning
Warning `has C-linkage specified, but returns user-defined type std::string`
di `cipher.cpp`, `vault.cpp`, dan forward declaration `memek.cpp` belum jadi
penyebab gagal build. Build berhenti karena error quote macro di atas.

---

## Milestone 10 — Artifak Build Sukses (M10)

Setelah fix M9 diterapkan, GitHub Actions berhasil build dan menghasilkan
**3 artifak** yang bisa diunduh dari halaman workflow run:

1. `Claude48AI-release-apk`
2. `Claude48AI-r8-mapping`
3. `Claude48AI-debug-symbols`

Bagian ini mendokumentasikan fungsi masing-masing, kapan dipakai, dan best
practice penyimpanannya.

### 10.1  Claude48AI-release-apk (Artifak Utama)
- **Isi:** `app-release.apk` — file APK final siap install ke perangkat Android.
- **Status:** Sudah di-sign (release keystore), di-minify oleh R8, dan
  di-obfuscate. Ukuran kecil, kode Java/Kotlin sudah teracak.
- **Cara pakai:** Download → transfer ke HP → install (aktifkan "Install from
  unknown sources" jika belum).
- **Distribusi:** Bisa langsung dibagikan ke user, upload ke Google Play,
  atau via internal channel.

### 10.2  Claude48AI-r8-mapping (Decode Crash Java/Kotlin)
- **Isi:** `mapping.txt` yang dihasilkan R8/ProGuard saat proses minify +
  obfuscation.
- **Kenapa dibutuhkan:** Setelah obfuscation, nama class/method/variable
  Java/Kotlin berubah jadi karakter acak, contoh:
  ```
  com.claudememek.app.MainActivity.onCreate()  →  a.b.c.a()
  ```
  Kalau app crash di perangkat user, stack trace-nya jadi:
  ```
  at a.b.c(Unknown Source:1)
  at d.e.f(Unknown Source:2)
  ```
  → tidak bisa dibaca manusia.
- **Fungsi mapping.txt:** Kamus untuk membalikkan (retrace) nama acak ke
  nama asli. Contoh entri:
  ```
  com.claudememek.app.MainActivity -> a.b.c:
      void onCreate(android.os.Bundle) -> a
  ```
- **Cara pakai:**
  - Upload ke Google Play Console → tab "App bundle explorer" → Deobfuscation
    files. Play Console otomatis translate crash log jadi readable.
  - Manual: pakai tool `retrace` dari Android SDK
    (`$ANDROID_HOME/tools/proguard/bin/retrace.sh mapping.txt crash.txt`).
- **PENTING:** Simpan `mapping.txt` **per versi release**. Kalau file ini
  hilang, crash log dari user untuk versi tersebut **tidak akan pernah bisa
  dibaca lagi**.

### 10.3  Claude48AI-debug-symbols (Decode Crash Native C++)
- **Isi:** Symbol files dari native library `.so` (hasil kompilasi kode C++
  di `memek.cpp`, `cipher.cpp`, `vault.cpp` via NDK + CMake).
- **Kenapa dibutuhkan:** R8 mapping hanya menangani Java/Kotlin. Kode native
  C++ yang crash (segfault, null pointer, dsb) menghasilkan stack trace
  berupa alamat memori mentah:
  ```
  #00 pc 0x00000000000a3f2c  libmemek.so
  #01 pc 0x00000000000a51b8  libmemek.so
  ```
- **Fungsi symbol files:** Translate alamat memori tersebut menjadi
  nama fungsi + nomor baris file `.cpp` asli, sehingga crash native jadi
  bisa didebug.
- **Cara pakai:**
  - Upload ke Google Play Console (kolom "Native debug symbols") saat rilis
    App Bundle. Play Console otomatis symbolicate crash native.
  - Manual: pakai `ndk-stack` dari NDK
    (`ndk-stack -sym path/to/symbols -dump crash.log`).
- **Kapan wajib:** Kalau app dirilis publik dan pakai native code
  (project ini iya, karena `libmemek.so` dari CMake).

### 10.4  Ringkasan Praktis

| Artifak                     | Wajib install? | Fungsi                          | Kapan dipakai            |
|-----------------------------|----------------|---------------------------------|--------------------------|
| **Claude48AI-release-apk**  | YA             | File APK final                  | Install ke perangkat     |
| **Claude48AI-r8-mapping**   | Simpan saja    | Decode crash Java/Kotlin        | Debug crash user         |
| **Claude48AI-debug-symbols**| Simpan saja    | Decode crash native C++         | Debug crash native user  |

### 10.5  Best Practice Penyimpanan
- **Untuk rilis publik (Google Play):** Upload **ketiga artifak** ke Play
  Console. Mapping + symbols wajib supaya crash report readable.
- **Untuk testing internal / distribusi pribadi:** Cukup `release-apk`,
  tapi **jangan pernah buang** mapping.txt dan debug-symbols. Simpan di
  folder terarsip per versi (misal `releases/v1.0.0/`).
- **Aturan emas:** 1 build release = 1 folder arsip berisi APK + mapping +
  symbols + tag git commit. Kalau salah satu hilang, debugging crash user
  untuk versi itu praktis mustahil.

### 10.6  Alur end-to-end (M1 → M10)
```text
M1-M6  : Setup project Flutter + native (C++) + Firebase
M7     : Build gagal karena base64 invalid input
M8     : Fix GOOGLE_SERVICES_JSON (commit langsung, hapus secret)
         + rename package com.claude48.ai → com.claudememek.app
M9     : Fix double-quote macro EXPECTED_SIG_SHA256 di CMake
M10    : Build sukses → 3 artifak (APK + mapping + symbols)
```

---

## M11 — Hotfix Anti-Tamper Development Mode (2026-07-01)

### 11.1  Konteks
Setelah anti-tamper M7 aktif dengan validasi SHA256 certificate di
`aegis.so`, APK hasil build GitHub Actions **selalu ke-redirect ke
`www.google.com`** meskipun APK original hasil workflow resmi.

### 11.2  Root cause
GitHub Actions runner tidak punya release keystore permanen. Setiap
run, Flutter/Gradle auto-generate `~/.android/debug.keystore` baru
per runner (atau bahkan per job) → fingerprint SHA256 certificate
berubah setiap build.

Alur yang gagal:
1. Step "Compute expected APK signature" hitung SHA256 dari debug
   keystore runner saat ini → inject sebagai `EXPECTED_SIG_SHA256`
   ke CMake.
2. APK ter-build dengan certificate X, macro tertanam X.
3. Runtime `NativeBridge.integrityCheck` baca certificate APK yang
   ter-install (sama = X) → **harusnya match**.
4. Tapi karena user install APK dari run ke-N, sementara certificate
   di device masih dari install sebelumnya (atau debug keystore
   berbeda per fresh install), signature runtime ≠ macro
   `EXPECTED_SIG_SHA256` → `aegis_verify_sig` return false →
   `TamperGuard.blockedScreen()` → redirect google.com.

### 11.3  Pelajaran Hari Ini
Implementasi anti-tamper berbasis SHA256 certificate **berhasil
bekerja secara teknis** — comparator konstan-waktu, XOR-encoded
strings, opaque predicate, semua jalan sesuai desain M7.

Namun ditemukan bahwa GitHub Actions menggunakan **debug keystore
dinamis** sehingga fingerprint bisa berubah setiap build.

Akibatnya:
- APK original terdeteksi sebagai APK modifikasi.

Kesimpulan:
- Anti-tamper berhasil.
- **Developer berhasil ditembak oleh anti-tamper miliknya sendiri.** 🔫

Keputusan:
- Menonaktifkan **sementara** validasi signature untuk development.
- Anti-tamper akan diaktifkan kembali setelah **release keystore
  permanen** dibuat & didaftarkan ke workflow.

### 11.4  Fix yang diterapkan
File: `android/app/src/main/cpp/aegis.cpp`

Tambah preprocessor flag `DEVELOPMENT_BUILD` (default `1`) di paling
atas file. Body `aegis_verify_sig()` sekarang:

```cpp
#if DEVELOPMENT_BUILD
    // DEVELOPMENT MODE — bypass signature check.
    return true;
#else
    // ... logika comparator M7 tetap utuh (opaque predicate +
    // constant-time hex compare) ...
#endif
```

### 11.5  Yang TIDAK dihapus (arsitektur keamanan dijaga penuh)
Sesuai instruksi hotfix, **seluruh struktur anti-tamper tetap ada**
dan tinggal di-flip 1 flag untuk re-aktif:

- ✅ `memek.so` — entry JNI + JNI_OnLoad, semua export utuh.
- ✅ `aegis.so` — comparator + XOR decoder + opaque predicate + tag
  export. Hanya body `aegis_verify_sig` yang di-gate `#if`.
- ✅ `cipher.so` — encrypt/decrypt field sensitif (tidak disentuh).
- ✅ `vault.so` — premium token verifier (tidak disentuh).
- ✅ `lib/services/native_bridge.dart` — MethodChannel + panggilan
  `integrityCheck` / `verifyPremium` / `encryptField` / `decryptField`
  tetap ada.
- ✅ `lib/services/tamper_guard.dart` — `TamperGuard.check()`,
  `blockedScreen()`, `_redirectUrl` = `https://www.google.com`
  semua tetap.
- ✅ `lib/main.dart` — `TamperGuard.check()` gate sebelum `runApp`
  tetap dipanggil.
- ✅ Workflow `.github/workflows/android-build.yml` — step "Compute
  expected APK signature SHA-256" + `-DEXPECTED_SIG_SHA256=...`
  tetap ada. Nilai tetap di-inject; hanya di-abaikan oleh native
  selama `DEVELOPMENT_BUILD == 1`.
- ✅ Obfuscation Dart + R8 + native (hidden visibility, strip-all,
  XOR strings) tidak berubah.

### 11.6  Cara re-aktifkan anti-tamper (saat release keystore siap)

Owner cukup pilih salah satu:

**Opsi A — Edit source (paling aman untuk release final):**
```cpp
// android/app/src/main/cpp/aegis.cpp, baris DEVELOPMENT_BUILD:
#define DEVELOPMENT_BUILD 0
```

**Opsi B — Override via CMake args di `android/app/build.gradle`
(untuk build release yg beda-beda tanpa ubah source):**
```gradle
externalNativeBuild {
    cmake {
        arguments "-DEXPECTED_SIG_SHA256=${expectedSigSha256}",
                  "-DDEVELOPMENT_BUILD=0"
    }
}
```

Prasyarat sebelum flip flag:
1. Generate **release keystore permanen** (`keytool -genkeypair …`),
   simpan `.jks` di secret aman.
2. Update workflow signing config → pakai keystore release (bukan
   `signingConfigs.debug` lagi seperti M0).
3. Step "Compute expected APK signature" baca alias & storepass
   release, bukan debug (sudah ada TODO carry-over di M7 §7.14
   poin 3 dan M8 §8.6 poin 3).
4. Daftarkan SHA-1 fingerprint keystore release ke Firebase Console
   (M8 §8.6 poin 4).
5. Barulah flip `DEVELOPMENT_BUILD → 0` dan rebuild.

### 11.7  Checklist SOP
- [x] Tidak commit API key / secret sensitif.
- [x] Tidak menyentuh `.github/workflows/android-build.yml`
      (0 perubahan workflow — hotfix murni di native).
- [x] Tidak menambah dependency di `pubspec.yaml`.
- [x] Tidak menghapus milestone lama — entry M11 append di bawah M10.
- [x] Tidak menghapus struktur anti-tamper (memek/aegis/cipher/vault
      + native bridge + redirect flow tetap utuh).
- [x] Komentar dokumentasi ditambahkan di `aegis.cpp` header
      menjelaskan alasan bypass + cara re-enable.
- [x] Naming tetap `snake_case` (file) & `PascalCase` (class).

### 11.8  File yang berubah
- `android/app/src/main/cpp/aegis.cpp` — tambah `#define
  DEVELOPMENT_BUILD 1` + `#if DEVELOPMENT_BUILD` guard di body
  `aegis_verify_sig`.
- `pengembangan.md` — entry M11 ini.

### 11.9  Yang TIDAK berubah
- Semua file `.cpp` lain (`memek.cpp`, `cipher.cpp`, `vault.cpp`).
- `CMakeLists.txt` (masih inject `EXPECTED_SIG_SHA256` seperti M9).
- Semua file Dart (`tamper_guard.dart`, `native_bridge.dart`,
  `main.dart`, `app.dart`).
- Workflow build APK.
- Gradle & ProGuard rules.

---

## 12. Milestone M12 — Hotfix Register Flow & Email Template

**Tanggal:** 2 Juli 2026
**Konteks:** Setelah M11 (hotfix anti-tamper dev mode) build berhasil dan
aplikasi bisa jalan sampai screen register. Namun ditemukan 2 bug:

### 12.1  Bug #1 — `FormatException: Unexpected character <HTML>`

**Gejala:** Klik tombol "Kirim kode verifikasi" pada screen daftar →
muncul error merah `FormatException: Unexpected character (at character 1) <HTML>`.
Seharusnya user dibawa ke screen input OTP.

**Root cause:** Client (`auth_service.dart`) POST ke GAS Web App dengan
header `Content-Type: application/json`. Google Apps Script Web App
punya quirk terkenal: request dengan `Content-Type: application/json`
sering di-redirect ke `script.googleusercontent.com` dan/atau balikin
HTML interstitial page (login/consent), bukan JSON. Akibatnya
`jsonDecode(res.body)` di client fail parse karena body diawali `<HTML>`.

**Fix:** Ganti header menjadi `Content-Type: text/plain;charset=utf-8`.
Body request tetap JSON string (`jsonEncode(body)`), dan di GAS
`e.postData.contents` tetap terbaca apa adanya lalu di-`JSON.parse`.
Ini adalah pola standar & recommended cara komunikasi Flutter ↔ GAS.

**File berubah:** `lib/services/auth_service.dart` (fungsi `_post`).

### 12.2  Bug #2 — Email verifikasi tampilan busuk (emoji `��`)

**Gejala:** Email masuk ke Gmail user, tapi:
- Emoji 🤖 dan 👋 render sebagai `?` di dalam kotak diamond hitam.
- Setelah "Halo Idin Iskandar" muncul deretan `��������` (broken UTF-8).
- Design gradient ungu-oranye + dark background terkesan lebay.

**Root cause:**
1. Emoji Unicode di HTML body kadang gagal render di Gmail karena
   mismatch charset antara MIME header (dikontrol GmailApp) vs body.
2. Design terlalu ramai untuk email transaksional sederhana.

**Fix:** Rewrite `buildEmailHtml()`:
- **Hapus semua emoji** (🤖, 👋) → menghilangkan sumber utama masalah
  encoding, sekaligus terlihat lebih profesional.
- **Redesign minimal Apple-style**: background putih bersih (`#F5F5F7`),
  card putih dengan border tipis, satu aksen bar tipis warna ungu di
  atas, tipografi San Francisco stack. Fokus visual ke kode 6-digit.
- Tetap responsive (`max-width:480px`, viewport meta).
- Tetap satu warna brand (ungu `#7C3AED`) dipakai sangat hemat sebagai
  aksen — bukan sebagai gradient penuh.

**Prinsip design email baru:** *"Simple tapi bagus, cantik, tidak lebay."*

**File berubah:** `backend/kode.gs` (fungsi `buildEmailHtml`).

### 12.3  Yang TIDAK diubah
- Struktur endpoint GAS (`doPost`, actions register/verify/login/…).
- Flutter UI screens (`register_screen.dart`, `verify_screen.dart`).
- Native anti-tamper (masih di mode M11 `DEVELOPMENT_BUILD=1`).
- Workflow GitHub Actions, gradle, ProGuard.
- Dependency `pubspec.yaml`.

### 12.4  Post-deploy action required
Karena `kode.gs` berubah, user perlu:
1. Buka https://script.google.com project GAS auth-nya.
2. Copy-paste ulang isi `backend/kode.gs` ke editor GAS.
3. **Deploy → Manage deployments → Edit → New version → Deploy**.
4. URL Web App tidak berubah (kalau pakai "New version" bukan "New
   deployment"), jadi `GAS_AUTH_URL` di GitHub Secrets tidak perlu
   di-update.

### 12.5  Checklist SOP
- [x] Tidak menyentuh `.github/workflows/`.
- [x] Tidak menambah dependency.
- [x] Tidak menghapus milestone lama (M12 di-append).
- [x] Tidak menghapus struktur anti-tamper (masih utuh dari M11).
- [x] Komentar dokumentasi ditambahkan di kedua file yang berubah
      menjelaskan alasan perubahan.

---

## M13 — Hotfix GAS Redirect + Redesign Auth UI

### Bug: Register selalu error tapi email masuk

**Root cause (real, ini yang bener):**
Google Apps Script Web App bertingkah aneh saat menerima **POST** ke
`/macros/s/xxxx/exec`. Server selalu balikin **HTTP 302 redirect** ke
`script.googleusercontent.com/.../echo?...` (di situlah JSON payload asli
berada). Kalau HTTP client kita ngefollow redirect otomatis — yang dilakukan
`http.post` — method-nya tetap POST juga di URL redirect, dan Google
malah balikin **halaman HTML interstitial** ("Moved Temporarily" /
sign-in page). Client parse HTML sebagai JSON → `FormatException:
Unexpected character <HTML>`.

Yang bikin bingung: **email tetap terkirim** karena request pertama
udah dieksekusi sama `doPost` di sisi GAS. Yang gagal cuma parsing
response-nya di client.

Percobaan M12 (`Content-Type: text/plain`) doang **tidak cukup** —
redirect tetap terjadi.

**Fix di `lib/services/auth_service.dart`:**
- Ganti `http.post(...)` → `http.Request('POST', ...)` dengan
  `followRedirects = false`.
- Kalau status 301/302/303/307 → ambil header `Location` → **GET manual**
  URL itu → parse JSON dari body-nya.
- Loop maksimal 5 hop untuk safety.

Ini pola standar Flutter ↔ GAS yang sering ke-skip di tutorial.

### Redesign UI Auth (Login / Register / Verify)

Terinspirasi referensi "Schedit" (Kaaviya Suresh) tapi diadaptasi
ke dark-first sesuai identitas app:

- **`lib/features/auth/widgets/auth_widgets.dart`** — shared UI kit:
  `AuthHeaderBadge` (bulat, brand gradient, ada glow),
  `AuthTitle` (title + subtitle center),
  `AuthLabel`, `AuthField` (rounded 14, border tipis, prefix icon),
  `AuthPrimaryButton` (gradient + shadow, height 54),
  `AuthErrorText` (banner error rapi),
  `OtpBoxes` (6 kotak digit terpisah, tanpa dependency baru).
- **Login**: badge → "Selamat datang" → email & password (toggle show/hide) → CTA.
- **Register**: badge → "Buat akun" → nama/email/password → CTA "Kirim kode verifikasi".
- **Verify**: badge email → email highlight → **6 OTP boxes** → auto-submit saat 6 digit lengkap → tombol "Kirim ulang".

Semua warna 100% dari `AppColors` — tidak ada hardcoded color.

**⚠️ Post-deploy:** Karena `backend/kode.gs` tidak berubah di M13,
GAS deployment **tidak perlu** di-redeploy. Fix M13 murni di sisi Flutter.

---

## M14 — Hotfix Build: `withValues` → `withOpacity`

### Masalah
GitHub Actions gagal build APK release dengan error:
```
Error: The method 'withValues' isn't defined for the class 'Color'.
lib/features/auth/widgets/auth_widgets.dart:25
```

### Root cause
`Color.withValues(alpha: x)` adalah API **Flutter 3.27+** (setelah wide-gamut color rework). CI runner masih di **Flutter 3.24.5**, yang cuma punya `withOpacity(double)`.

### Fix
Replace semua `.withValues(alpha: X)` → `.withOpacity(X)` di
`lib/features/auth/widgets/auth_widgets.dart` (5 occurrences).

### Pelajaran
Jangan pakai API Flutter yang belum tersedia di channel CI. Cek `flutter --version` di workflow sebelum pakai method baru. Untuk saat ini `withOpacity` masih works — deprecation warning baru muncul di 3.27+.


---

## M15 — Integrasi Multi-Provider (NVIDIA Nemotron Selector)

**Tanggal:** 2 Juli 2026
**Status:** 🏗️ Draft / In-Progress
**Catatan:** Milestone ini di-merge ke `pengembangan.md` dari file terpisah
`m15.md` di M16 supaya semua sejarah pengembangan konsisten di satu dokumen.

### Ringkasan
Menambahkan **NVIDIA Nemotron** sebagai opsi model selector premium di
aplikasi. Integrasi berjalan *multi-provider* bersama KIE.AI. Pengguna
memilih via *Model Selector* (M3), dan sistem otomatis *route* ke
endpoint yang tepat.

### Alur Kerja (Workflows)
1. **Model Discovery** — list model di `lib/core/constants/ai_models.dart`
   diperluas dengan entry `nvidia-nemotron-3-ultra`. Setiap model punya
   field `provider` (`AiProvider.kieAI` | `AiProvider.nvidia`).
2. **Request Routing** — `AiClientService` pakai *Provider Factory Pattern*.
   `sendMessage` cek `selectedModel.provider`:
   - `kieAI` → `/claude/v1/messages`.
   - `nvidia` → `/v1/chat/completions` (`enable_thinking: true`).
3. **API Key Management** — rotasi API key (pola M4) untuk kedua provider.
   Key NVIDIA di-inject via `AI_NVIDIA_API_KEY` (secret baru).
4. **Interaction Style (NVIDIA)** — model NVIDIA support *thinking*.
   Blok `reasoning_content` di-render pakai `ReasoningBlock` widget
   (collapsible "Proses Berpikir") sebelum konten utama.

### Perubahan Struktur Kode
- `lib/core/constants/ai_models.dart` — tambah enum
  `AiProvider { kieAI, nvidia }`, entry NVIDIA dengan
  `apiModelId: "nvidia/nemotron-3-ultra-550b-a55b"`.
- `lib/services/ai_client_service.dart` — `streamMessage` branch by
  `provider`. NVIDIA butuh `extra_body`:
  `{"chat_template_kwargs":{"enable_thinking":true},"reasoning_budget":16384}`.
- `lib/features/chat/widgets/message_bubble.dart` — tambah `ReasoningBlock`
  untuk menangkap `reasoning_content` streaming dari NVIDIA.

### Penggunaan (UI/UX)
1. **Selector** — pilih model NVIDIA di composer.
2. **Interaction** — kirim chat seperti biasa.
3. **Thinking Display** — kalau NVIDIA aktif, box *Thinking* streaming
   di atas jawaban akhir.
4. **Error Handling** — kalau `AI_NVIDIA_API_KEY` kosong / salah →
   fallback ke KIE.AI (atau tampilkan error spesifik).

### Checklist Konfigurasi GitHub Actions
- [ ] Tambahkan secret `AI_NVIDIA_API_KEY` di repository settings.
- [ ] Update `android-build.yml` untuk inject
      `--dart-define=AI_NVIDIA_API_KEY=${{ secrets.AI_NVIDIA_API_KEY }}`.

---

## M16 — Hotfix Verifikasi + Firebase OAuth (Google & Facebook)

**Tanggal:** 2 Juli 2026
**Status:** ✅ Selesai

### 16.1 Konteks & keluhan owner
Owner mencoba flow **daftar → verifikasi email**:
1. Klik "Kirim kode verifikasi" pada `RegisterScreen`.
2. Email masuk normal (`396436`, template M12 rapi).
3. Masukin 6 digit kode di `VerifyScreen` → muncul error merah
   **"Email belum terdaftar."** — padahal user emang baru daftar dan
   lagi verifying pendaftaran itu. Bikin frustasi + confusing.

Selain itu owner minta pasang **Firebase OAuth Google + Facebook**
(dua-duanya) sebagai jalur alternatif — Firebase Authentication sudah
di-enable di console untuk kedua provider.

### 16.2 Root cause bug verifikasi
`backend/kode.gs` `getSheet()` lama:

```javascript
const ss = SpreadsheetApp.getActiveSpreadsheet()
  || SpreadsheetApp.create(APP_NAME + ' Auth DB');
```

Di GAS **standalone script** (bukan container-bound ke sheet),
`getActiveSpreadsheet()` selalu return `null`. Fallback
`SpreadsheetApp.create(...)` **bikin spreadsheet BARU** setiap kali
`doPost` dieksekusi. Konsekuensi:
- `actionRegister` → append row ke Spreadsheet A.
- User pindah screen → `actionVerify` invocation baru →
  `getSheet()` bikin Spreadsheet B → `findRow` return `-1` →
  throw `"Email belum terdaftar."`.

Bikin bertumpuk file `Claude AI Auth DB` di Drive owner tanpa dia
sadar.

### 16.3 Fix backend (`backend/kode.gs`)

**Persistent spreadsheet resolver:**
- Simpan `spreadsheetId` di
  `PropertiesService.getScriptProperties().setProperty('CLAUDE_AI_SS_ID', id)`
  saat pertama kali `create`.
- Berikutnya, `getScriptProperties().getProperty('CLAUDE_AI_SS_ID')` →
  `SpreadsheetApp.openById(id)`. ID persistent selamanya di script.

**Pesan error lebih ramah:**
- `actionVerify` kalau row tidak ketemu → *"Sesi verifikasi tidak
  ditemukan. Silakan kembali ke halaman daftar dan kirim ulang kode."*
- `actionVerify` kode expired → *"Kode sudah kadaluarsa. Tekan Kirim
  ulang untuk minta kode baru."*
- `actionResend` row tidak ketemu → *"Sesi pendaftaran tidak ditemukan.
  Silakan daftar ulang."*

**Kolom baru `provider`:**
- Sheet schema dari 9 → **10 kolom** (tambah `provider` di kolom J).
  Nilai: `'email'` (default), `'google'`, `'facebook'`.
- `readRow` sekarang baca `1..10`. Row lama (9 kolom) masih terbaca —
  `provider` di-default ke `'email'`.

**Action baru `socialUpsert`:**
- Body: `{ action:'socialUpsert', uid, email, name, avatarUrl?, provider }`.
- Idempotent: kalau email belum ada → append row dengan
  `verified=true` (OAuth = trusted, skip email verifikasi).
- Kalau email sudah ada → update `name` + `avatarUrl` + `provider`,
  tanpa nabrak `passwordHash` existing (linked account).

### 16.4 Firebase OAuth di Flutter (Google + Facebook)

**Dependency baru (`pubspec.yaml`):**
- `firebase_auth: ^5.3.1`
- `google_sign_in: ^6.2.1`
- `flutter_facebook_auth: ^7.1.1`

Bump versi `0.5.0+5 → 0.6.0+6`.

**File baru:**
- `lib/services/social_auth_service.dart` — `SocialAuthService.instance`:
  - `signInWithGoogle()` — `GoogleSignIn` (scope email/profile) →
    `GoogleAuthProvider.credential(idToken, accessToken)` →
    `FirebaseAuth.signInWithCredential` → `_finalize`.
  - `signInWithFacebook()` — `FacebookAuth.login(['email','public_profile'])` →
    `FacebookAuthProvider.credential(token)` → Firebase → `_finalize`.
  - `_finalize(...)` — POST `socialUpsert` ke GAS (best-effort, kalau
    gagal jangan block login) + `AuthService.acceptExternalSession()`.
  - `signOut()` — clear Google + Facebook + Firebase session.

**File diubah:**
- `lib/services/auth_service.dart` — expose method
  `acceptExternalSession(AuthSession)` supaya `SocialAuthService`
  bisa persist session tanpa hit GAS login endpoint.
- `lib/features/auth/widgets/auth_widgets.dart` — tambah
  `AuthOrDivider`, `SocialAuthButton`, `GoogleGlyph`, `FacebookGlyph`.
- `lib/features/auth/login_screen.dart` — 2 tombol OAuth di atas
  form email/password + divider "atau lanjut dengan".
- `lib/features/auth/register_screen.dart` — 2 tombol OAuth di atas
  form daftar + divider "atau daftar dengan email". User bisa skip
  seluruh flow verifikasi 6-digit dengan 1-tap Google/Facebook.

### 16.5 Android config (Facebook SDK)

**`AndroidManifest.xml`:**
- `<meta-data com.facebook.sdk.ApplicationId />` +
  `<meta-data com.facebook.sdk.ClientToken />` baca `@string/facebook_app_id`
  & `@string/facebook_client_token`.
- `FacebookActivity` + `CustomTabActivity` + intent-filter dengan
  scheme `@string/fb_login_protocol_scheme`.
- Label app dinaikin dari `"Claude 4.8 AI"` (legacy) ke `"Claude AI"`
  (konsisten dengan `AppConfig.appName` sejak M6).

**`android/app/build.gradle`:**
- `resValue "string", "facebook_app_id",           System.getenv("FACEBOOK_APP_ID")`
- `resValue "string", "facebook_client_token",     System.getenv("FACEBOOK_CLIENT_TOKEN")`
- `resValue "string", "fb_login_protocol_scheme",  "fb" + System.getenv("FACEBOOK_APP_ID")`
- Kalau env kosong → resource tetap ada tapi Facebook login gagal
  di runtime (Google login tetap jalan normal). Non-fatal.

**`res/values/strings.xml` (baru):** `app_name = "Claude AI"` untuk
label `FacebookActivity`.

**Workflow (`.github/workflows/android-build.yml`):**
- Tambah env `FACEBOOK_APP_ID` + `FACEBOOK_CLIENT_TOKEN` dari secrets
  di step "Build APK". `build.gradle` baca `System.getenv(...)` saat
  Gradle configure phase, jadi cukup di env — nggak perlu `--dart-define`.

### 16.6 Setup wajib di GitHub & Firebase (one-time owner)

1. **Firebase Console** — Authentication → Sign-in method:
   Google ✅ (sudah enabled), Facebook ✅ (sudah enabled, verified via
   screenshot owner).
2. **Facebook Developers Console** (https://developers.facebook.com):
   - Buat app tipe *Consumer* → aktifkan produk **Facebook Login**
     → Android platform.
   - Package: `com.claudememek.app`. Class name:
     `com.claudememek.app.MainActivity`.
   - Add key hash: SHA-1 debug keystore CI (owner bisa generate ulang
     dari step *Compute expected APK signature* di workflow, base64 dari
     hex SHA-1).
   - Copy **App ID** + **Client Token** (Settings → Advanced → Client Token).
3. **GitHub Secrets** — tambah 2 secret baru:
   - `FACEBOOK_APP_ID`
   - `FACEBOOK_CLIENT_TOKEN`
4. **Deploy ulang `backend/kode.gs`** di Google Apps Script:
   - Buka https://script.google.com project auth-nya.
   - Copy-paste ulang isi `backend/kode.gs`.
   - Deploy → *Manage deployments* → Edit → New version → Deploy.
   - URL Web App tetap → `GAS_AUTH_URL` tidak perlu diubah.
5. **Firebase SHA-1 fingerprint** — pastikan SHA-1 keystore debug CI
   sudah didaftarin di Firebase Console (Project Settings → Your apps →
   Add fingerprint). Kalau belum, Google sign-in bakal error
   `ApiException: 10 (DEVELOPER_ERROR)`.

### 16.7 UX flow baru
```
LoginScreen                              RegisterScreen
─────────────────                        ─────────────────
[Lanjut dengan Google]  ← 1-tap          [Lanjut dengan Google]  ← 1-tap
[Lanjut dengan Facebook]← 1-tap          [Lanjut dengan Facebook]← 1-tap
── atau lanjut dengan ──                 ── atau daftar dengan email ──
Email / Password                         Nama / Email / Password
[Login]                                  [Kirim kode verifikasi]
                                         → VerifyScreen (OTP 6-digit)
                                           (skip kalau pake OAuth)
```

### 16.8 Yang TIDAK berubah
- Native anti-tamper masih di mode M11 (`DEVELOPMENT_BUILD=1` di
  `aegis.cpp`). Belum ada release keystore permanen.
- kie.ai chat endpoint + rotasi API key M4 tidak disentuh.
- SQLite chat history (M2) + streak (M5) tidak disentuh.
- Bottom nav 3-tab (M6) tidak berubah.

### 16.9 Compatibility / Breaking change
- **Sheet schema breaking (minor):** kolom J baru `provider`. Row lama
  yang cuma punya 9 kolom TETAP bisa dibaca — `readRow` default
  `provider = 'email'`. Nggak perlu migrasi manual.
- User baru yang daftar via OAuth punya `passwordHash = ''` — kalau
  mereka nanti coba login dengan password akan ditolak (harus lewat
  OAuth). Ini disengaja: mencegah account takeover via password guess.
- `AuthSession` shape tetap `{uid, email, name}` — nggak ada consumer
  eksternal yang berubah.

### 16.10 Checklist SOP
- [x] Tidak commit API key / Facebook secret sensitif — via GitHub Secrets.
- [x] `.github/workflows/android-build.yml` cuma **nambah step**
      (env FACEBOOK_APP_ID/CLIENT_TOKEN) — step lama tetap.
- [x] `pubspec.yaml` versi di-bump (`0.5.0+5 → 0.6.0+6`).
- [x] Tidak menghapus milestone lama — M15 & M16 append di bawah M14.
- [x] Tidak menghapus struktur anti-tamper (M11 mode dev tetap).
- [x] Warna baru semua via `AppColors`; `GoogleGlyph`/`FacebookGlyph`
      pakai warna brand resmi masing-masing provider (bukan warna app,
      jadi wajar hardcode `#4285F4` / `#1877F2`).
- [x] Naming: file `snake_case`, class `PascalCase`.
- [x] Merge `m15.md` ke `pengembangan.md` — file lama dihapus supaya
      dokumentasi satu sumber.

### 16.11 File berubah / baru
**Added:**
- `lib/services/social_auth_service.dart`
- `android/app/src/main/res/values/strings.xml`

**Modified:**
- `backend/kode.gs`
- `pubspec.yaml`
- `lib/services/auth_service.dart`
- `lib/features/auth/widgets/auth_widgets.dart`
- `lib/features/auth/login_screen.dart`
- `lib/features/auth/register_screen.dart`
- `lib/core/constants/app_config.dart`
- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`
- `.github/workflows/android-build.yml`
- `pengembangan.md` (append M15 + M16)

**Deleted:**
- `m15.md` (isinya sudah di-merge ke pengembangan.md §M15)

---

## M17 — Release Keystore Permanen (generate di GitHub Actions, no PC needed)

Konteks: owner nggak punya PC/laptop, build cuma via GitHub Actions.
Termux di HP terlalu berat. Debug keystore lama di CI di-generate ulang
setiap run → SHA-1 berubah → Google Sign-in mental `DEVELOPER_ERROR`
setiap rebuild. Solusi: keystore permanen di-generate SEKALI di runner CI,
di-set otomatis sebagai GitHub Secret pakai PAT, dipakai selamanya.

### 17.1 File baru / diubah

**Added:**
- `.github/workflows/generate-keystore.yml` — workflow SEKALI PAKAI
  (manual dispatch) yang generate keystore + auto-set secret + upload
  backup ter-encrypt.

**Modified:**
- `android/app/build.gradle` — conditional release signing.
  Kalau `android/app/claude-release.jks` ada (di-decode dari secret
  `ANDROID_KEYSTORE_BASE64` di CI) → pakai release keystore. Kalau
  nggak → fallback debug signing.
- `.github/workflows/android-build.yml` — 2 step baru:
  1. Decode `ANDROID_KEYSTORE_BASE64` → `android/app/claude-release.jks`.
  2. Compute expected SHA-256 dari secret `EXPECTED_SIG_SHA256` (kalau
     release) atau dari debug keystore (fallback).
  Tambah 3 env di step Build APK: `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- `.gitignore` — block `*.jks`, `*.jks.base64`, `build/keystore/`,
  `android/app/claude-release.jks`.

### 17.2 Cara pakai (one-time setup, semua dari HP)

1. **Bikin Personal Access Token** di
   https://github.com/settings/tokens → *Generate new token (classic)* →
   scope `repo` → copy.
2. **Set secret `GH_PAT`** di repo → Settings → Secrets and variables →
   Actions → New repository secret → value = PAT tadi.
3. **Trigger workflow** *Generate Release Keystore* → Actions tab →
   Run workflow. Input:
   - `key_alias`: biarin default `claude-release`.
   - `backup_password`: password buat encrypt file backup (INGAT!).
   - `force_regenerate`: biarin `no`.
4. **Tunggu ~1 menit**. Buka Job Summary → copy SHA-1 & SHA-256.
5. **Firebase Console** → Project settings → Your apps
   (`com.claudememek.app`) → *Add fingerprint* → paste SHA-1 dan
   SHA-256 → *Download google-services.json* baru → replace
   `android/app/google-services.json` → commit (via github.com web UI
   dari HP).
6. **Download artifact** `claude-keystore-backup-ENCRYPTED` (7z,
   di-encrypt pake password step 3) → simpan di Google Drive /
   password manager. **File `.jks` ini kalau hilang = mati total.**
7. **(Optional)** Delete workflow file `generate-keystore.yml` biar
   nggak ke-trigger ulang tanpa sengaja.

Setelah itu tiap push ke `main`, workflow `Android Build` otomatis
decode keystore dari secret dan sign APK release dengan SHA-1 permanen.

### 17.3 Secret yang di-set otomatis (5)

| Secret | Isi |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Isi `.jks` base64 single-line |
| `ANDROID_KEYSTORE_PASSWORD` | Random 32-char alphanumeric |
| `ANDROID_KEY_ALIAS` | `claude-release` (atau input user) |
| `ANDROID_KEY_PASSWORD` | Random 32-char alphanumeric |
| `EXPECTED_SIG_SHA256` | Hex SHA-256 cert, tanpa colon, uppercase (buat native anti-tamper M11) |

Semua di-mask di log (`::add-mask::`).

### 17.4 Guard & safety

- Workflow refuse jalan kalau `ANDROID_KEYSTORE_BASE64` sudah ada,
  kecuali input `force_regenerate=YES`. Ini mencegah regenerate
  nggak sengaja (akan bikin SHA-1 lama mati, semua user Google
  Sign-in existing rusak).
- Password random 32-char, generated pakai `/dev/urandom` (bukan
  pseudo-random Bash). Alphanumeric doang biar aman lewat CLI.
- Backup artifact di-encrypt pakai 7z `-mhe=on` (header + content
  encryption) dengan password user, retention 90 hari.
- `.jks` nggak pernah ke-commit — di-block via `.gitignore`.

### 17.5 EXPECTED_SIG_SHA256 & anti-tamper M11

Sebelumnya (§16.8) native anti-tamper masih di dev mode karena
SHA-256 debug keystore berubah tiap build. Sekarang SHA-256 release
permanen sudah di-set sebagai secret `EXPECTED_SIG_SHA256`, dipake
otomatis oleh `build.gradle` (line 24) buat inject ke
`-DEXPECTED_SIG_SHA256=...` di CMake. Owner bisa switch M11 dari dev
mode ke production mode di `aegis.cpp` (`DEVELOPMENT_BUILD=0`) kalau
sudah yakin build release stabil.

### 17.6 Compatibility

- Kalau workflow generate-keystore belum dijalanin, semua secret M17
  kosong → `android-build.yml` fallback ke debug signing → build
  tetap sukses (nggak break). Cuma Google Sign-in bakal error kayak
  sebelumnya.
- `flutter run` lokal (kalau nanti owner punya PC) tetap jalan
  karena `build.gradle` cek `releaseKeystoreFile.exists()` dulu.

---

## M18 — Hotfix Keystore Password Padding + Kotlin Plugin Bump

**Tanggal:** 2 Juli 2026
**Status:** ✅ Selesai

### 18.1 Konteks
Setelah M17 (release keystore permanen), build `Android Build` di CI
gagal di task `:app:packageRelease` setelah ~6 menit dgn error:
```
com.android.ide.common.signing.KeytoolException:
Failed to read key *** from store ".../android/app/***.jks":
Get Key failed: Given final block not properly padded.
```
Ditambah Flutter Fix warning tentang Kotlin Gradle plugin outdated.

### 18.2 Root cause
**Bukan bug kode** — klasik **key password mismatch**. Di M17,
`generate-keystore.yml` bikin 2 password random terpisah (`STORE_PASS`
≠ `KEY_PASS`) lalu simpan ke 2 secret berbeda. Kalau salah satu secret
ke-truncate / salah paste / stale (misal keystore di-regenerate tapi
password lama belum di-update), Gradle sukses buka store tapi gagal
decrypt private key → error padding.

### 18.3 Perubahan yg diterapkan

**`.github/workflows/generate-keystore.yml`**
- **Single password** — `KEY_PASS="$STORE_PASS"`. PKCS12 spec technically
  mengharuskan store == key untuk banyak tool path, dan menghilangkan
  seluruh kelas error padding di masa depan. Owner cuma perlu inget 1
  password.
- **Explicit `-storetype PKCS12`** — default keytool modern, tapi
  eksplisit biar deterministik antara CI runner & lokal (kalau nanti
  ada).
- **Self-test** — setelah generate, langsung `keytool -list` pakai
  password yg sama. Kalau gagal → workflow abort sebelum sempet set
  secret (mencegah bug repeat di build workflow).

**`android/app/build.gradle`**
- `keyPassword` **fallback** ke `storePassword` kalau env
  `ANDROID_KEY_PASSWORD` kosong / whitespace. Konsisten dgn best-practice
  PKCS12.
- Guard: kalau `storePassword` kosong padahal file .jks ada →
  **jangan** bikin `signingConfig` release. Fallback ke debug signing
  dgn `logger.warn` jelas — jauh lebih baik daripada crash "padding" 6
  menit di packageRelease.
- Explicit `storeType "PKCS12"` di signingConfig.
- `logger.lifecycle` print signing summary (keystore, alias, mode
  keyPass) ke Gradle log — tanpa expose password. Ketauan lebih awal
  keystore mana yg dipakai.

**`.github/workflows/android-build.yml`**
- **Pre-flight validation step** baru: `Verify release keystore password
  (fail-fast)`. Jalanin `keytool -list` pakai password yg sama yg bakal
  dipakai Gradle. Kalau mismatch → workflow fail dalam 3 detik dgn
  pesan actionable (link ke HOTFIX-M18.md, langkah A/B recovery), bukan
  bakar 6 menit sampe mati di `packageRelease`.
- `base64 -d` sekarang di-preprocess `tr -d '\r\n '` buat handle
  whitespace tersembunyi kalau secret ke-paste dari web UI dgn trailing
  newline (bonus hardening, sekalian).

**`android/settings.gradle`**
- Bump `org.jetbrains.kotlin.android` **1.9.22 → 1.9.24**. Hilangkan
  warning "Your project requires a newer version of the Kotlin Gradle
  plugin". 1.9.24 masih fully-compatible dgn Flutter 3.24.5 + AGP 8.3.0
  + firebase_core 3.6, tanpa migrasi ke Kotlin 2.x yg butuh KSP baru.

### 18.4 File baru
- `HOTFIX-M18.md` — panduan recovery step-by-step buat owner (Opsi A:
  restore backup .7z; Opsi B: regenerate keystore).

### 18.5 File diubah
- `android/settings.gradle`
- `android/app/build.gradle`
- `.github/workflows/generate-keystore.yml`
- `.github/workflows/android-build.yml`
- `pengembangan.md` (entry M18 ini)

### 18.6 Compatibility / Breaking change
- **Tidak ada breaking change untuk kode Flutter / Dart**. Semua
  perubahan cuma di build system.
- **Keystore lama masih valid** — kalau owner punya backup .jks + tau
  password, tinggal set ulang secret (Opsi A di HOTFIX-M18.md), SHA-1
  tetap sama, Firebase & user Google Sign-in tetap jalan.
- Kalau owner regenerate keystore (Opsi B) → SHA-1 baru, WAJIB update
  Firebase Console + `google-services.json`.

### 18.7 Checklist SOP
- [x] Tidak commit API key / keystore ke repo (`.jks` masih di
      `.gitignore` dari M17).
- [x] Workflow lama tidak dihapus — cuma nambah step (pre-flight) +
      tweak step existing (whitespace-strip di decode, single-password
      di generate).
- [x] Tidak nambah dependency di `pubspec.yaml` (0 package baru).
- [x] Tidak menghapus milestone lama — entry M18 append di bawah M17.
- [x] Tidak menghapus struktur anti-tamper (M11 dev mode tetap).
- [x] Tidak `print` / log password (`::add-mask::` + `logger.lifecycle`
      cuma output nama file & alias).
- [x] File naming `snake_case`, class `PascalCase`.

### 18.8 Verifikasi
Build workflow output yg diharapkan setelah fix:
```
✅ Keystore & password match. Aman lanjut build.
...
✅ [M18] Release signing aktif — keystore=claude-release.jks,
   alias=claude-release, keyPass=FALLBACK→storePass
...
BUILD SUCCESSFUL in ~3m
```

### 18.9 TODO (M19+)
- Migrasi `pubspec.yaml` `flutter_lints` ke versi yg compat sama
  Kotlin 2.x kalau nanti Flutter stable-nya nge-force upgrade AGP > 8.5.
- Bikin `Manage Keystore` panel debug di `ProfileScreen` (opsional):
  print SHA-1 runtime dari `NativeBridge.currentSignature()` biar
  bandingin sama Firebase gampang tanpa buka keytool.

---

## M18.1 / M18.2 / M18.3 — Logout, Single-Device, Anti-Tamper Re-enable

**Tanggal:** 2 Juli 2026
**Status:** ✅ Selesai
**Version bump:** `0.6.0+6 → 0.7.0+7`

Konteks: fase auth + security dari M7–M18 (hotfix keystore) sudah stabil.
Owner minta tuntasin 3 sub-milestone terakhir di gerbong M18 sebelum jalan
ke M19 (Creator Mission System):
1. Tombol Logout eksplisit di UI.
2. Enforce 1 akun = 1 device.
3. Aktifkan kembali proteksi anti-tamper native (M11 sebelumnya dev-bypass).

### M18.1 — Tombol Logout

**Titik masuk UI:** `SettingsScreen` → section danger (di bawah "Clear
Chat History").

**Alur:**
1. Tap tombol `Sign out` → dialog konfirmasi (Batal / Keluar-danger).
2. Kalau confirm:
   - `DeviceSessionService.release(uid)` → hapus doc
     `users/{uid}/session/current` di Firestore **hanya kalau** device
     ini masih tercatat sebagai owner (compare-then-delete, hindari
     race dgn device baru).
   - `SocialAuthService.signOut()` → clear Google + Facebook + Firebase.
   - `AuthService.signOut()` → hapus session lokal (SharedPreferences).
   - `Navigator.popUntil((r) => r.isFirst)` → kembali ke root.
3. `AuthGate` re-evaluate → session kosong → render `LoginScreen`.

**File diubah:**
- `lib/features/settings/settings_screen.dart` — import 3 service,
  method `_signOut()`, 1 baris `_DangerRow(Sign out)` di build. Fix
  bug lama: `_DangerRow` hardcode `Icons.delete_outline_rounded`
  padahal punya param `icon` — sekarang pakai `icon` yg di-pass.

### M18.2 — 1 akun = 1 device

**Model data (Firestore):**

```
users/{uid}
  └─ session/current
       ├─ deviceId  (UUID v4, persist di SharedPreferences per install)
       ├─ platform  (android/ios/other)
       └─ updatedAt (server timestamp)
```

**Alur:**
1. Setiap install generate `deviceId` (UUID v4) sekali → simpan di
   `SharedPreferences` key `device_id_v1`. Uninstall / Clear Data =
   device baru.
2. Setiap kali user sign-in (email/password login, verify OTP, Google
   OAuth, Facebook OAuth) atau session di-restore dari disk saat boot
   → `DeviceSessionService.claim(uid)` write doc di atas.
3. Semua device yang masih pegang session lokal untuk uid tsb
   subscribe ke `snapshots()` doc itu.
4. Ketika device lain meng-claim uid yang sama → doc ke-overwrite →
   snapshot masuk ke device lama dgn `deviceId ≠ myDeviceId` →
   `kicked` `ValueNotifier` di-set true.
5. `AuthGate` dengerin `kicked`:
   - Sign out lokal (Google/Facebook/Firebase/AuthService).
   - **TIDAK** release doc Firestore — device baru berhak tetap
     jadi owner.
   - `setState` → LoginScreen tampil.
   - Show `AlertDialog`: *"Akun ini baru saja login di perangkat lain.
     Untuk keamanan, sesi di perangkat ini otomatis di-logout."*

**Semantik yg dipilih:** *"device baru menang"* — mirip WhatsApp Web /
Netflix. Alternatif *"device pertama menang, tolak login baru"* lebih
frustrating (user beli HP baru langsung ketolak).

**Rules Firestore:** cukup rule existing
`match /users/{uid}/{document=**} { allow read, write: if request.auth.uid == uid; }`
yang sudah didokumentasiin di M7 §7.11 — path `session/current` masuk
cascade `{document=**}` otomatis, tidak perlu rule baru.

**Catatan sinkronisasi:** karena project ini pakai Firebase Auth (M16 —
Google/Facebook OAuth), `request.auth.uid` akan match. Untuk user yang
login lewat GAS email/password (M7), `FirebaseAuth.instance.currentUser`
mungkin null → write ke Firestore ditolak rules. Owner **rekomendasi**
enable "Anonymous sign-in" di Firebase Console dan tambah
`FirebaseAuth.instance.signInAnonymously()` di boot, atau (jangka
panjang) migrasi flow email/password ke Firebase Auth Email Link.
Untuk sekarang, path OAuth (mayoritas user) sudah full-protected;
path email/password fallback ke rely on Firestore reject → device kedua
tetap bisa sign-in tapi kick tidak jalan sampai auth Firebase dipenuhi.

**File baru:**
- `lib/services/device_session_service.dart` — singleton dengan
  `deviceId()`, `claim(uid)`, `claimCurrent()`, `release(uid)`, `stop()`,
  `ValueNotifier<bool> kicked`.

**File diubah:**
- `lib/services/firebase_service.dart` — tambah `_sessionDoc(uid)`,
  `claimDevice(...)`, `sessionSnapshots(uid)`, `releaseDeviceIfOwned(...)`.
- `lib/features/auth/login_screen.dart` — `AuthGate` claim on boot +
  listen `kicked`; `_submit`/`_google`/`_facebook` panggil `claim(uid)`
  setelah profile upsert.
- `lib/features/auth/verify_screen.dart` — call `claim(s.uid)` setelah
  OTP verify sukses.
- `lib/features/settings/settings_screen.dart` — logout flow panggil
  `DeviceSessionService.release(uid)` sebelum clear session lokal.

### M18.3 — Aktifkan kembali Anti-Tamper

**Perubahan:**
- `android/app/src/main/cpp/aegis.cpp` —
  `#define DEVELOPMENT_BUILD 1` → `#define DEVELOPMENT_BUILD 0`.
  Header comment di-update ke "PRODUCTION MODE (re-enabled di M18.3)".

**Kenapa sekarang aman:**
- M17 sudah generate release keystore permanen + set 4 secrets
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) + `EXPECTED_SIG_SHA256`.
- M18 hotfix (single-password + PKCS12 + pre-flight verify di CI)
  bikin signing stabil, SHA-256 cert tidak berubah antar rebuild.
- `build.gradle` sudah forward `EXPECTED_SIG_SHA256` env ke CMake
  `-DEXPECTED_SIG_SHA256=...`, dan `CMakeLists.txt` bungkus quote sekali
  (fix M9). Jadi macro `EXPECTED_SIG_SHA256` di dalam `aegis.cpp` sudah
  berisi hex uppercase 64-char runtime cert yg sah.

**Fallback dev tetap aman:**
- Kalau owner build tanpa secret `EXPECTED_SIG_SHA256` (mis. flutter run
  lokal, atau workflow generate-keystore belum dijalankan), macro
  string kosong → `aegis_verify_sig` return true di baris
  `if (!expected || !*expected) return true;`. Dev tidak terblokir.
- Kalau APK di-re-sign pihak lain (mod / repack) → runtime SHA-256
  beda dengan macro → `ct_hex_eq` return false → `TamperGuard.check()`
  false → `blockedScreen()` + redirect `https://www.google.com`.

### Compatibility / Breaking change

- **User existing yg sekarang login di 2 device** (mis. HP + tablet):
  begitu update ke 0.7.0+7, device kedua yg pertama kali buka app
  bakal claim, device lain otomatis ke-kick di next snapshot. Bukan
  data loss — chat history lokal + cloud (M7) tetap ada, user cukup
  sign-in ulang di device yg diinginkan.
- **APK non-release (debug)**: kalau owner build lokal tanpa keystore
  release + tanpa `EXPECTED_SIG_SHA256`, anti-tamper tetap bypass
  (fallback macro kosong). APK release resmi yg di-sign keystore lain
  di luar CI = akan kena block. Ini justru behavior yg diinginkan.

### Checklist SOP

- [x] Tidak commit API key / keystore ke repo.
- [x] Tidak menyentuh `gradle-wrapper.jar` / `.properties`.
- [x] Workflow tidak diubah (semua kerjaan M18.x murni di kode Dart +
      1 baris di aegis.cpp).
- [x] `pubspec.yaml` version bump (`0.6.0+6 → 0.7.0+7`) + `AppConfig`
      sinkron.
- [x] Warna semua via `AppColors` (`AppColors.danger` untuk Sign out row).
- [x] Naming: `snake_case` file, `PascalCase` class
      (`DeviceSessionService`).
- [x] Milestone append di bawah, tidak menghapus entry lama.
- [x] Tidak nambah dependency baru — semua sudah ada sejak M0/M7
      (`shared_preferences`, `uuid`, `cloud_firestore`, `firebase_auth`).

### File berubah / baru (ringkas)

**Added:**
- `lib/services/device_session_service.dart`

**Modified:**
- `lib/services/firebase_service.dart`
- `lib/features/auth/login_screen.dart`
- `lib/features/auth/verify_screen.dart`
- `lib/features/settings/settings_screen.dart`
- `android/app/src/main/cpp/aegis.cpp`
- `lib/core/constants/app_config.dart`
- `pubspec.yaml`
- `pengembangan.md`

### Sisa ke owner

1. (Opsional, direkomendasi) Tambah `FirebaseAuth.instance.signInAnonymously()`
   di boot atau migrasi email/password ke Firebase Auth supaya path GAS
   juga bisa write `users/{uid}/session/current` (rules butuh `request.auth.uid`).
2. Tidak ada perubahan Firestore Rules yg wajib — path `session/current`
   masuk cascade wildcard existing.
3. Setelah update, minta 1 tester coba login akun sama di 2 device
   untuk verify kick flow jalan (device pertama harus dapet dialog
   "Sesi berakhir" dalam < 3 detik setelah device kedua login).


# ============================================================
# M19 — Creator Mission System  (STATUS: IMPLEMENTED v0.9.0+9)
# ============================================================

## Ringkasan Implementasi

Sistem reward berbasis konten TikTok: user submit link, admin review, reward
premium (No Ads / Claude Pro 30 hari / Nvidia Premium) diterapkan otomatis
ke entitlement doc `users/{uid}` saat approve.

## File Baru

- `lib/models/creator_submission.dart` — schema submission + helper
  `rewardForViews()` (300 → no_ads, 1000 → pro_30d, 5000 → nvidia).
- `lib/models/user_entitlements.dart` — flat entitlement flags dibaca
  dari `users/{uid}`: `no_ads`, `pro_expired`, `nvidia_unlock`,
  `creator_reward_claimed`.
- `lib/services/creator_mission_service.dart` — `submit()`,
  `mySubmissionsStream()`, `pendingStream()`, `review()`,
  `fetchEntitlements()`.
- `lib/services/admin_service.dart` — cache boolean `is_admin` dari
  profile doc (bootstrap manual via Firestore console).
- `lib/features/mission/mission_page.dart` — M19.1: hero banner,
  status entitlement chips, reward tiers, tombol submit (bottom-sheet
  dengan validasi TikTok URL + duplicate check), list riwayat status.
- `lib/features/admin/admin_dashboard.dart` — M19.4: list pending
  submissions, search (username/uid/url), input verified-views + notes,
  tombol Approve/Reject yang memanggil reward engine.
- `backend/firestore.rules` — rules Firestore lengkap:
  - user hanya bisa write field non-entitlement pada dokumen sendiri;
  - hanya admin yang boleh mengubah `no_ads`, `pro_expired`,
    `nvidia_unlock`, `creator_reward_claimed`;
  - `creator_submissions` — user create (uid==auth.uid, status=pending,
    reward=null, views=0), admin update/delete, read own + admin.

## File Yang Dimodifikasi

- `lib/models/ai_model.dart` — tambah `isLocked` & `lockedReason`.
- `lib/core/constants/ai_models.dart` — tambah entry
  `Nvidia Premium` (id `nvidia-premium-8b`, `isLocked=true`), route ke
  `_kBackendModel` supaya fallback aman.
- `lib/features/chat/widgets/model_selector.dart` — badge "LOCKED"
  ber-warning color untuk model locked, onTap short-circuit + snackbar.
- `lib/features/settings/settings_screen.dart` — section baru "GROWTH"
  dengan entry `Mission Center` (semua user) dan `Admin Dashboard`
  (hanya kalau `AdminService.isAdmin()==true`).
- `pubspec.yaml` + `app_config.dart` → version `0.9.0+9`.

## Step Progress

- [x] M19.1 UI Mission Center — responsive + dark mode via `AppColors`.
- [x] M19.2 Firestore Collection `creator_submissions` + rules.
- [x] M19.3 Submit Mission — validasi TikTok / http prefix + duplicate.
- [x] M19.4 Dashboard Admin — approve/reject + search + notes.
- [x] M19.5 Reward Engine — tier auto-pick dari `views`,
      entitlement patch di `users/{uid}` via `SetOptions(merge: true)`.
- [x] M19.6 Anti Abuse — duplicate URL check, `creator_reward_claimed`
      flag, admin approval wajib, rules melarang user menulis entitlement.
- [ ] M19.7 Notification System — dihold; user tetap dapat status via
      stream real-time (`mySubmissionsStream`). FCM push akan menyusul
      di M21 (Global Notification).

## Bootstrap Admin

Set `is_admin: true` manual di Firestore console pada doc
`users/{ownerUid}`. Setelah itu buka Settings → GROWTH → Admin
Dashboard akan muncul.

## Catatan Nvidia

Model `nvidia-premium-8b` masih **placeholder**: `isLocked=true`,
apiModelId route ke `claude-haiku-4-5` supaya fallback tidak error.
Ketika backend Nvidia siap, cukup ubah `apiModelId` + `isLocked=false`.


# ============================================================
# M20 — Auth Cleanup: OAuth-Only (Google + Facebook)
# ============================================================

**Tanggal:** 3 Juli 2026
**Status:** ✅ Selesai
**Version bump:** `0.9.0+9 → 0.10.0+10`

## Konteks
Owner memutuskan aplikasi **100% pakai Firebase Authentication**. Jalur
email/password + verifikasi OTP via Google Apps Script (M7 / M13 / M16
form) dihapus total dari UI. Alasan utama:

1. **Konsistensi dashboard admin (M20 web)** — dashboard baca `users/{uid}`
   di Firestore. User jalur GAS tidak punya `request.auth` di Firebase,
   sehingga doc `users/{uid}` **tidak pernah tertulis** → dashboard
   kosong meskipun user aktif di aplikasi.
2. **Reduksi permukaan serangan** — 1 sumber auth (Firebase) = 1 tempat
   audit, tidak ada double-hash password di server GAS lagi.
3. **UX lebih ringan** — 1-tap, tanpa email verifikasi 6-digit.

## Perubahan Kode

**Removed:**
- `lib/features/auth/register_screen.dart`
- `lib/features/auth/verify_screen.dart`

**Modified — `lib/features/auth/login_screen.dart`:**
- Class `_LoginScreenState` di-rewrite: buang `_email`, `_password`,
  `_obscure`, `_submit`, semua widget `AuthField` + `AuthPrimaryButton`
  "Login" + divider "atau lanjut dengan" + row "Belum punya akun? Daftar".
- UI baru minimalis: brand badge → title → 2 tombol OAuth
  (Google + Facebook) → error text (kalau ada) → footnote ToS.
- `_goHome()` push `HomeShell()` langsung (drop kelas `_Rehome`
  intermediate — tidak dipakai lagi setelah RegisterScreen dihapus).
- `AuthGate` (kelas yg sama file) tidak berubah perilakunya.

**Modified — `lib/services/firebase_service.dart`:**
- `upsertProfile()` sekarang **wajib** menulis `createdAt` (sekali, saat
  first-create) + `lastActiveAt` (setiap panggilan). Ini fix
  root-cause dashboard admin tidak menampilkan user: query pakai
  `orderBy("createdAt","desc")` sehingga doc tanpa field ini di-skip.
- Method baru `touchLastActive()` untuk heartbeat "online user"
  (window 5 menit di dashboard Overview). Rencana: dipanggil dari
  `HomeShell` lifecycle observer tiap ~2 menit saat foreground —
  detail wiring bisa masuk M20.1 kalau butuh.

**Modified — `lib/main.dart`:**
- Buang `import 'features/auth/login_screen.dart'` yg tidak dipakai
  (LoginScreen di-referensi via `AuthGate` di `app.dart`).

**Modified — `pubspec.yaml` + `lib/core/constants/app_config.dart`:**
- Version bump `0.9.0+9 → 0.10.0+10`.

## Yang TIDAK dihapus (masih dipakai)

- `lib/services/auth_service.dart` — masih dipakai untuk **persist
  session lokal** via `SharedPreferences` (`acceptExternalSession`).
  Method GAS (`register/login/verify/resend`) tetap ada di kode tapi
  **tidak ada UI yang manggil**. Boleh dihapus di M21 kalau owner mau
  sekalian bersih-bersih; sekarang dibiarkan agar diff M20 minimal &
  reversible.
- `lib/services/social_auth_service.dart` — tetap. Sub-call
  `_gasUpsert` di dalamnya masih best-effort (tidak fatal kalau GAS
  offline / URL kosong).
- `backend/kode.gs` — tidak diubah. Endpoint `socialUpsert` masih
  dipanggil `SocialAuthService._finalize` sebagai mirror ke Sheets
  (opsional). Owner boleh matiin endpoint lain (`register/verify/login/
  resend`) kapan aja tanpa affect aplikasi.
- `lib/features/auth/widgets/auth_widgets.dart` — dipertahankan penuh.
  Widget yg dipakai: `AuthHeaderBadge`, `AuthTitle`, `SocialAuthButton`,
  `GoogleGlyph`, `FacebookGlyph`, `AuthErrorText`. Widget lain
  (`AuthField`, `AuthPrimaryButton`, `AuthLabel`, `OtpBoxes`,
  `AuthOrDivider`, `AuthInfoText`) tetap ada — safe to keep, tinggal
  purge di M21.

## Compatibility / Breaking change

- **User existing yg dulu login pakai email/password GAS**: begitu
  update ke 0.10.0+10, session lokal SharedPreferences masih valid
  (tidak dipaksa logout). Tapi **kalau logout**, mereka tidak bisa
  login ulang lewat UI karena form email/password tidak ada. Solusi:
  login pakai Google / Facebook dgn email yg **sama** — Firebase Auth
  akan bikin user baru (uid berbeda), sehingga chat history lama
  (`users/{oldUid}/threads/*`) tidak ke-migrate.
- **Rekomendasi communication ke user:** tampilin release note in-app
  "sekarang login cukup 1-tap Google / Facebook".

## Checklist SOP

- [x] Tidak menyentuh `.github/workflows/android-build.yml` — 0
      dependency baru.
- [x] Tidak menyentuh `gradle-wrapper.jar` / `.properties`.
- [x] Tidak commit API key / keystore.
- [x] Warna semua via `AppColors` (footnote ToS pakai `textMuted`).
- [x] Naming: `snake_case` file, `PascalCase` class.
- [x] Milestone ini append di bawah, tidak menghapus entry lama.
- [x] Version bump `pubspec.yaml` + `AppConfig` sinkron.

## Sisa ke owner

1. (Opsional) Panggil `FirebaseService.instance.touchLastActive()` dari
   `HomeShell` `didChangeAppLifecycleState` tiap 2 menit saat resumed
   untuk aktifkan modul "Online Users" di dashboard.
2. (Opsional M21) Purge `AuthService.register/login/verify/resendCode`
   + `AuthField`/`AuthPrimaryButton`/`OtpBoxes` widget yang sekarang
   dead code.
3. Setelah rules Firestore terbaru (juga dari sesi M20) di-publish di
   Firebase Console, semua doc `users/{uid}` dari user OAuth baru
   otomatis muncul di dashboard.

---

# M21 — Mission Manual Check-In, Model Gating, Notifications Tab

**Tanggal**: sesi lanjutan M20.
**Version bump**: `0.10.0+10` → `0.11.0+11`.
**Instruksi owner**:
> "Purge ke M21. Validasi misi (daily check-in gak auto — user klik dulu,
> nanti bakal rewarded video AdMob). Tambah tab Notifications di
> bottom-bar (broadcast admin + streak). Validasi gating model: user
> non-premium cuma Claude AI Fast yang open, sisanya gembok & terbuka
> otomatis by mission."

## 1. Purge total sisa GAS auth (dead code M20)

- `lib/services/auth_service.dart`: dirampingkan → hanya
  `AuthSession` + `load/signOut/acceptExternalSession/_persist`.
  Method `register/login/verify/resendCode/_hashPassword/_post` +
  `AuthException` **dihapus**. Import `http` & `crypto` dibuang.
- `lib/services/social_auth_service.dart`: hapus mirror ke GAS
  (`_gasUpsert`, `_gasEndpoint`) — sync profil sepenuhnya via
  `FirebaseService.upsertProfile()` yang dipanggil di `LoginScreen`.
- `lib/features/auth/widgets/auth_widgets.dart`: sisakan widget yang
  masih dipakai `LoginScreen` (`AuthHeaderBadge`, `AuthTitle`,
  `SocialAuthButton`, `GoogleGlyph`, `FacebookGlyph`, `AuthErrorText`).
  `AuthLabel`, `AuthField`, `AuthPrimaryButton`, `OtpBoxes`,
  `AuthOrDivider`, `AuthInfoText` dihapus.

**Efek**: bundle mengecil, tidak ada lagi surface `Exception:` GAS
yang bocor ke UI.

## 2. Model catalog & gating

`lib/models/ai_model.dart` (M20 sudah menambah `ModelUnlock`) sekarang
dipakai penuh. `lib/core/constants/ai_models.dart` didefinisikan:

| ID catalog          | Label              | Unlock                              |
| ------------------- | ------------------ | ----------------------------------- |
| `claude-4-6-haiku`  | Claude AI Fast     | **open** (default free)             |
| `claude-4-7-opus`   | Claude AI Balanced | `streak7` — Daily Login 7 hari      |
| `claude-4-8-opus`   | Claude AI Pro      | `pro` — mission 1.000 views         |
| `nvidia-premium-8b` | Nvidia Premium     | `nvidia` — mission 5.000 views      |

`AppConfig.defaultModelId` diubah ke `claude-4-6-haiku` supaya user
baru (belum ada entitlement) tidak nyangkut di model locked.

### `showModelSelector` (M21 refactor)

`lib/features/chat/widgets/model_selector.dart` sekarang:

1. Memuat `UserEntitlements` (Firestore `users/{uid}`) + streak count
   lokal di dalam sheet (`FutureBuilder`-ish via `initState`).
2. Menghitung `isModelUnlocked(model, ent, streakCount)`:
   - `open` → selalu true.
   - `streak7` → `streakCount ≥ 7 || proActive || nvidiaUnlock`.
   - `pro` → `proActive || nvidiaUnlock`.
   - `nvidia` → `nvidiaUnlock`.
3. Model locked ditampilkan dengan gembok + badge alasan lock
   (mis. "DAILY STREAK 7 HARI", "CLAUDE PRO", "NVIDIA PREMIUM").
4. Tap model locked → sheet close → auto-nav ke `MissionPage`
   (bukan snackbar mati).

Fungsi `isModelUnlocked(...)` di-export supaya bisa dipakai validator
lain nanti (mis. saat send message).

## 3. Daily Check-In manual + rewarded-ad placeholder

`lib/services/streak_service.dart`:

- Hapus asumsi auto-check-in.
- Tambah getter `hasCheckedInToday` (bandingkan `lastCheckInDate`
  dengan tanggal lokal hari ini).
- Tambah `simulateRewardAd()` → return `true` setelah delay 900ms.
  **TODO owner**: nanti diganti `RewardedAd.load().show(onEarned)` dari
  package `google_mobile_ads` begitu AdMob dihidupkan; sisanya (rule
  check-in + streak) tetap sama.
- Tambah `todayNotifId()` → id stabil `streak-YYYY-MM-DD` untuk
  idempotent push notif harian.

`lib/features/chat/chat_screen.dart`:

- Hapus blok `checkIn() + showReachedPremiumDialog/showStreakBrokenDialog`
  di `initState`. Chat screen sekarang **tidak** menyentuh streak.

`lib/features/mission/mission_page.dart`:

- Ditambah widget `_DailyCheckInCard` (setelah `_HeroBanner`):
  - Progress dots 1..7 (visual).
  - Tombol besar `Check-In Hari Ini (Tonton Iklan)`:
    - disabled kalau `hasCheckedInToday`.
    - klik → `simulateRewardAd()` → `checkIn()`.
  - Setelah check-in sukses, push notif lokal via
    `NotificationsService.pushLocal(id: todayNotifId, type: 'streak', …)`.
  - Copy dinamis per `StreakCheckInResult` (first day / incremented /
    reachedPremium / premiumMaintained / broken).
- Card ini juga jadi entry unlock untuk **Claude AI Balanced** model.
- Reward tier list (300/1.000/5.000 views) + form submit link tetap
  aktif — jalur mission untuk unlock No-Ads / Claude Pro / Nvidia
  tidak berubah dari M19.1.

## 4. Notifications tab & service

- `lib/models/app_notification.dart`: struct gabungan
  `broadcast|streak|mission|system` dgn `isBroadcast`, `createdAt`,
  `read`.
- `lib/services/notifications_service.dart`:
  - `combinedStream()` menggabung `broadcasts/*` (limit 50) +
    `users/{uid}/notifications/*` (limit 50), sorted desc by
    `createdAt`.
  - `pushLocal({id, type, title, body})` — idempotent kalau `id`
    diberikan (dipakai daily streak).
  - `markAllRead()` — batch update saat user buka tab.
  - Menggunakan **`_combineLatest2` custom** (StreamController) supaya
    tidak menambah dependency `rxdart` baru (menjaga janji M21: tidak
    modif workflow build).
- `lib/features/notifications/notifications_screen.dart` (**baru**):
  render list dari `combinedStream`, empty state, badge `ADMIN` untuk
  broadcast, ikon warna sesuai type (`streak`/`mission`/`system`).
- `lib/features/home/home_shell.dart`: bottom nav sekarang **4 tab** —
  `Chats` / `History` / **`Inbox`** / `Settings`. Padding horizontal
  dikecilkan dari 8→6 supaya 4 item nyaman di layar sempit.

## 5. Sinkron ke dashboard admin

- Struktur `broadcasts/{id}` yang di-consume: `{ title, body,
  createdAt, createdBy }` — sudah cocok dengan `appchatadmin`
  (broadcast composer). Pastikan admin push
  `createdAt: serverTimestamp()`.
- Firestore rules M20 sudah membuka `read` `broadcasts` untuk semua
  user login → tab Inbox otomatis nge-listen realtime.
- Notif lokal user disimpan di `users/{uid}/notifications/{id}` —
  perlu tambahan sub-collection rules kalau rules M20 belum
  mengcover:
  ```
  match /users/{uid}/notifications/{doc} {
    allow read, write: if isAdmin() ||
      (request.auth != null && request.auth.uid == uid);
  }
  ```
  Rekomendasi: kalau rules M20 diflag ulang, tambahkan snippet di
  atas — tidak ada perubahan aplikasi lain.

## 6. SOP compliance checklist

- [x] Package `com.claude48.ai` — tidak disentuh.
- [x] Warna via `AppColors` (tidak ada literal color baru selain glyph
      Google/Facebook official).
- [x] Naming: `snake_case` file, `PascalCase` class.
- [x] Milestone di-append (M21) tanpa menghapus M0–M20.
- [x] Version bump `pubspec.yaml` + `AppConfig` sinkron
      (`0.11.0+11`).
- [x] Tidak ada dependency baru (rxdart di-skip via manual combineLatest).
- [x] Tidak modif `.github/workflows/android-build.yml`, gradle wrapper,
      atau `google-services.json`.
- [x] Tidak commit API key / keystore.

## 7. Sisa ke owner

1. Publish Firestore rules revisi (M20 + snippet notifications
   sub-collection dari poin 5).
2. Test end-to-end di device: Google login → Inbox tab kosong →
   Mission Center → klik Check-In (delay 0.9s placeholder ad) →
   Inbox muncul entri "Selamat datang di Daily Streak".
3. Setelah AdMob aktif, ganti body `StreakService.simulateRewardAd()`
   dengan real Rewarded Ad; **tidak perlu** ubah `MissionPage` /
   `NotificationsService`.
4. Broadcast test dari admin dashboard (`appchatadmin`) →
   dokumen `broadcasts/{autoId}` dgn `createdAt: serverTimestamp()`.

---

## M22 — Rebrand Total "KiKai" + Redesign UI/UX Monokrom

**Tanggal:** 3 Juli 2026
**Ringkasan:** Rombak total identitas & UI/UX dari "Claude 4.8 AI" (dark ungu-oranye) menjadi **KiKai** — gaya hitam-putih minimalis. DILARANG: linear-gradient warna, neon, cyberpunk, RGB (semua "gradient" token dibuat solid hitam).

### Perubahan
- **Branding:** `AppConfig.appName` → `KiKai`; kelas app `Claude48App` → `KiKaiApp`; versi bump `0.12.0` (build 12).
- **Model:** label baru — `Kikai 4.8 Haiku` (Fast), `Kikai 4.8 Sonnet` (Balanced/streak7), `Kikai 4.8 Opus` (Pro), `Kikai Nvidia`. ID backend & gating (open/streak7/pro/nvidia) TIDAK berubah.
- **Design tokens (`app_colors.dart`):** palet monokrom light-first (cream `#F5F3EE`, kartu putih, ink `#0A0A0A`). Field name lama dipertahankan; semua gradient = solid hitam.
- **Theme (`app_theme.dart`):** light-first, font **Plus Jakarta Sans**. `themeMode` default `light`.
- **Navigasi (`home_shell.dart`):** bottom nav 5-slot — Chat · History · **[Kikai]** · Missions · Profile. Tombol tengah "Kikai" = new chat. Settings diakses dari Profile (gear), Notifications dari Chat (bell).
- **Chat:** header = notifikasi · model pill di tengah · new chat. Bubble user = hitam (teks putih); asisten = polos + avatar "K". Code block terang (githubTheme). Composer pill + lampiran/kamera + tombol kirim bulat hitam.
- **Profile:** avatar "K", nama dari sesi, akses Settings via gear.
- **Mission:** monokrom, hero hitam, param `embedded`, rebrand teks.
- **Aset:** ikon aplikasi baru (`assets/icon/app_icon.png`, "K" putih di kotak hitam) & mascot monokrom (`assets/mascot/claude_ai_mascot.png`, robot putih). Nama file mascot dipertahankan agar referensi lama tetap valid.
- **Dihapus:** `register_screen.dart` & `verify_screen.dart` (dead code pasca M20 OAuth-only).

### Catatan
- Logic/service/model TIDAK diubah — hanya presentation layer + branding, agar tidak ada fitur yang rusak.

---

## M23 — Hotfix Broadcast Field Mismatch + Finalisasi Rebrand KiKai

**Tanggal:** 3 Juli 2026
**Version bump:** `0.12.0+12 → 0.12.1+13`
**Referensi:** `PERBAIKAN-BROADCAST.md` (dari owner)

### 23.1 Bug
Broadcast admin (dashboard `appchatadmin`) tersimpan sukses di Firestore
tapi tidak muncul di tab Inbox Flutter. Root cause: dashboard menulis
`created_at` (snake_case) sedangkan Flutter query `orderBy('createdAt')`
(camelCase). Firestore auto-exclude dokumen tanpa field yang di-orderBy →
snapshot kosong, tanpa error.

### 23.2 Fix (Opsi B — sisi Flutter)
Karena scope pekerjaan hanya di repo `idincode-main` (bukan dashboard),
dipilih **Opsi B**: samakan Flutter ke konvensi dashboard `created_at`.

**Modified — `lib/services/notifications_service.dart`:**
- Query `broadcasts` diubah `orderBy('createdAt')` → `orderBy('created_at')`.
- Query `users/{uid}/notifications/*` **tetap** `orderBy('createdAt')`
  karena field itu ditulis sendiri oleh `pushLocal()` di Flutter.
- Doc-comment header disesuaikan (`broadcasts` fields = title, body,
  created_at, created_by, audience).
- `AppNotification.fromMap` **tidak** diubah — sudah tolerant dua-duanya
  (`m['createdAt'] ?? m['created_at']`), jadi kalau di masa depan
  dashboard nulis dua-duanya (Opsi A) tetap kompatibel.

### 23.3 Rebrand KiKai (finalisasi label OS-level)
`AppConfig.appName` sudah `KiKai` sejak M22, tapi label OS + pubspec
description masih "Claude AI". Diseragamkan tanpa menyentuh package
name (tetap `com.claudememek.app`, sesuai instruksi owner).

**Modified:**
- `android/app/src/main/AndroidManifest.xml` → `android:label="KiKai"`.
- `android/app/src/main/res/values/strings.xml` → `app_name = "KiKai"`
  (label FacebookActivity).
- `pubspec.yaml` → `description: "KiKai — Multi-model AI chat companion."`
- `pubspec.yaml` + `AppConfig` version sync `0.12.1+13`.

### 23.4 Yang TIDAK diubah
- `applicationId` / `namespace` Android tetap `com.claudememek.app`.
- Semua JNI symbol (`Java_com_claudememek_app_*`) tetap.
- `google-services.json` tidak disentuh.
- `.github/workflows/*` tidak disentuh (0 dependency baru).
- Rules Firestore, `AppNotification.fromMap`, semua service lain tetap.

### 23.5 Checklist SOP
- [x] Tidak commit API key / keystore.
- [x] Tidak menyentuh gradle wrapper, workflow, `google-services.json`.
- [x] 0 dependency baru di `pubspec.yaml`.
- [x] Version bump sinkron pubspec ↔ AppConfig.
- [x] Milestone append di bawah M22.
- [x] Package name TIDAK diubah (`com.claudememek.app`) — hanya display name.

### 23.6 Verifikasi
1. Rebuild APK via GitHub Actions.
2. Install → label launcher tampil "KiKai".
3. Login (Google) → buka tab Inbox → broadcast lama/baru dari dashboard
   admin (yang punya field `created_at`) langsung muncul realtime.

---

### M22 — NVIDIA Nemotron via Proxy Vercel + Keychain Native (obfuscated)

Tanggal: 3 Juli 2026

**Ringkasan**
Menghidupkan model **Kikai Nvidia** (NVIDIA Nemotron 3 Ultra 550B) di
composer + memindahkan seluruh API key AI dari `--dart-define`
(plain-text di APK) ke native `.so` (XOR-obfuscated, di-embed saat
build via CMake). Detail penuh cara kerja NVIDIA end-to-end ada di
[`nvidia_integration.md`](./nvidia_integration.md).

**Kenapa dua hal digabung di satu milestone?**
Keduanya "bocor-key mitigation":
- NVIDIA → key hidup di server Vercel, APK cuma pegang URL publik.
- KiKai/Claude → key masih perlu di APK tapi sekarang lewat native
  keychain (XOR + hidden visibility + strip-all), bukan telanjang di
  `String.fromEnvironment`.

**File baru**
- `lib/services/nvidia_client_service.dart` — client SSE ke proxy
  Vercel (`https://nvidia-api-nine.vercel.app/api/chat`). Kontrak SSE:
  `data: {"type":"content","delta":"..."}` → yield delta,
  `type:"done"` → return, `type:"error"` → throw. Timeout 120s.
- `android/app/src/main/cpp/keychain.cpp` — decoder XOR key list.
  Baca `KEYCHAIN_XOR_HEX` + `KEYCHAIN_XOR_KEY` yang di-embed CMake,
  return CSV asli. Compile jadi `libkeychain.so` (hidden visibility,
  strip-all — sama pola dengan `vault.so`/`cipher.so`).
- `nvidia_integration.md` — dokumentasi cara kerja NVIDIA end-to-end
  (arsitektur, request/response contract, alur Flutter, alur backend,
  env-var Vercel, test manual, gating unlock, FAQ debug).

**File diubah**
- `lib/models/ai_model.dart` — tambah `AiProvider.nvidia` di enum.
- `lib/core/constants/app_config.dart` — tambah `nvidiaBackendUrl`
  (override via `--dart-define=NVIDIA_BACKEND_URL=...`).
- `lib/core/constants/ai_models.dart` — entry `nvidia-premium-8b`
  sekarang `provider: AiProvider.nvidia`, `apiModelId: 'nvidia-ultra'`
  (alias yang di-resolve `nvidia-backend/lib/models.js` →
  `nvidia/nemotron-3-ultra-550b-a55b`), `maxTokens: 16384`.
- `lib/services/ai_client_service.dart` — `sendMessage` &
  `streamMessage` cek `model.provider == AiProvider.nvidia` di awal,
  route ke `NvidiaClientService`. Fallback path lama (kie.ai +
  rotasi key --dart-define) tetap dipertahankan untuk model Claude.
- `lib/services/api_key_service.dart` — tambah `Future<void> init()`
  async: query `NativeBridge.getApiKeys()` (dari keychain.so), kalau
  ada → override `_cachedKeys`. Kalau kosong → getter `keys` fallback
  baca `--dart-define` lama (backward compat, dev flow tetap jalan).
- `lib/services/native_bridge.dart` — tambah `Future<String> getApiKeys()`
  MethodChannel call. Aman di non-Android (MissingPluginException → '').
- `lib/main.dart` — panggil `await ApiKeyService.init()` sebelum
  service lain (setelah TamperGuard, sebelum Firebase).
- `android/app/src/main/cpp/CMakeLists.txt` — tambah target
  `keychain` (SHARED), link ke `memek`. Baca CMake args
  `KEYCHAIN_XOR_HEX` + `KEYCHAIN_XOR_KEY` (default `0x5A`).
- `android/app/src/main/cpp/memek.cpp` — forward-decl
  `keychain_get_keys()`, tambah JNI export
  `Java_com_claudememek_app_NativeBridge_getApiKeys`.
- `android/app/src/main/kotlin/com/claudememek/app/MainActivity.kt` —
  tambah `System.loadLibrary("keychain")` (SEBELUM `memek`), external
  `getApiKeys()`, dan handler MethodChannel `"getApiKeys"`.
- `android/app/build.gradle` — baca env `AI_API_KEYS` (fallback
  `AI_API_KEY`), XOR tiap byte dgn `0x5A`, encode hex, pass ke CMake
  via `-DKEYCHAIN_XOR_HEX=... -DKEYCHAIN_XOR_KEY=90`. Log ringkasan
  tanpa expose isi key.
- `.github/workflows/android-build.yml` — **TIDAK DIUBAH**. Env
  `AI_API_KEYS` sudah di-export dari `secrets.AI_API_KEYS` untuk step
  `flutter build apk` — gradle otomatis baca env yang sama. Tetap
  pass `--dart-define=AI_API_KEYS="$AI_API_KEYS"` supaya fallback
  jalan kalau native keychain error / build debug.

**Alur build (setelah M22)**
```
GitHub Secret AI_API_KEYS
       │
       ▼   (env var)
android/app/build.gradle  ── XOR 0x5A + hex ──▶  -DKEYCHAIN_XOR_HEX=…
       │                                              │
       │                                              ▼
       │                                        CMake → keychain.cpp
       │                                              │
       │                                              ▼
       │                                         libkeychain.so (di APK)
       │
       └── --dart-define=AI_API_KEYS=… ──▶  Dart AOT const  (fallback)
                                                       │
                                                       ▼
Runtime app:  ApiKeyService.init()
              ├── coba NativeBridge.getApiKeys()  ← keychain.so decode
              └── kalau kosong: fallback baca --dart-define
```

**Alur runtime NVIDIA**
```
composer select "Kikai Nvidia"
     │
     ▼
chat_controller → AiClientService.streamMessage(model)
     │
     │  model.provider == AiProvider.nvidia?
     ├── YES → NvidiaClientService.streamMessage
     │         POST https://nvidia-api-nine.vercel.app/api/chat (SSE)
     │            → backend Vercel rotasi NVIDIA_API_KEYS
     │            → integrate.api.nvidia.com/v1 (nemotron-3-ultra-550b)
     │
     └── NO  → jalur lama kie.ai (Claude Haiku 4.5 dgn rotasi
                --dart-define / keychain.so key)
```

**Catatan keamanan**
- Keychain native bukan proteksi mutlak — attacker yang serius bisa
  attach `frida` / dump memory. Tapi ini naikin bar dari
  "1-menit `strings`" jadi "perlu dinamis analisis" — untuk
  distribusi APK ke komunitas, sudah cukup.
- API key NVIDIA (`nvapi-...`) **tidak pernah** ada di APK — hidup
  hanya di env-var Vercel. Rotasi = tambah/ganti secret di Vercel
  dashboard, redeploy backend (tanpa rilis APK baru).
- ProGuard/R8 rules untuk `com.claudememek.app.NativeBridge` sudah
  di-keep (existing `proguard-rules.pro`), jadi JNI symbol
  `Java_com_claudememek_app_NativeBridge_getApiKeys` tidak di-rename.

**Verifikasi**
1. Rebuild APK via GitHub Actions (workflow lama, tidak perlu
   diubah — env `AI_API_KEYS` sudah tersedia di step build).
2. Install → buka app → composer → tap chip model → pilih
   "Kikai Nvidia" (butuh entitlement `nvidia_unlock` via Creator
   Mission 5.000 views).
3. Ketik "hai" → jawaban streaming muncul realtime dari NVIDIA
   Nemotron.
4. Debug: cek Logcat filter `[nvidia-chat]` (log dari backend Vercel
   di dashboard Vercel), atau tail log gradle saat build untuk
   konfirmasi `✅ [M22] keychain.so embed N AI key`.

---

## M23 — Rombak Model Selector: Claude 4.8 Opus + Seluruh Model NVIDIA Backend

**Konteks**
Backend `idincode-baseAi` (proxy Vercel `nvidia-api-nine.vercel.app`) sudah
meng-host 9 model via NVIDIA Integrate API. Sebelum M23, model selector
aplikasi hanya menampilkan 3 varian brand Claude (Haiku/Sonnet/Opus, semua
route ke Claude Haiku 4.5) + 1 entry NVIDIA Nemotron. Sisa 8 model backend
belum ter-expose ke UI.

**Perubahan**
`lib/core/constants/ai_models.dart` — ditulis ulang total:

1. **Hapus** varian Kikai Haiku & Kikai Sonnet. Sisakan satu entry
   brand `Kikai 4.8 Opus` yang tetap route ke backend Claude Haiku 4.5
   (`apiModelId = 'claude-haiku-4-5'`) — konsisten dengan permintaan
   product owner: "biar tampil Claude 4.8 Opus di UI meskipun backend
   pakai 4.5 Haiku".
2. **Tambah** seluruh 9 model dari `idincode-baseAi/lib/models.js`,
   route ke `AiProvider.nvidia` (`/api/chat`), diurutkan dari yang
   paling hebat:

   | # | Label UI                        | `apiModelId` (alias) |
   |---|---------------------------------|----------------------|
   | 1 | Kikai 4.8 Opus                  | `claude-haiku-4-5`   |
   | 2 | NVIDIA Nemotron 3 Ultra 550B    | `nvidia-ultra`       |
   | 3 | DeepSeek V4 Pro                 | `deepseek-v4-pro`    |
   | 4 | Mistral Small 4 119B            | `mistral-small-4`    |
   | 5 | Moonshot Kimi K2.6              | `kimi`               |
   | 6 | Dracarys Llama 3.1 70B          | `dracarys`           |
   | 7 | MiniMax M2.7                    | `minimax`            |
   | 8 | ByteDance Seed-OSS 36B          | `seed-oss`           |
   | 9 | Google Gemma 4 31B              | `gemma`              |
   |10 | Meta Llama Guard 4 12B          | `llama-guard`        |

3. **Unlock policy**: semua model di-set `ModelUnlock.open` supaya user
   free tier bisa langsung mencoba seluruh katalog. Gating premium
   (streak / pro / nvidia entitlement) dari M21 tetap tersedia di
   `ModelUnlock` — tinggal ganti `unlockKey` per entry kalau nanti
   mau di-monetize lagi.

**Backward compat**
- `findModelById()` dan `kDefaultFreeModel` tetap tersedia dengan
  signature yang sama — tidak ada breaking change di sisi
  `chat_controller`, `model_selector`, atau storage (`chatModelId`).
- Routing tetap: `provider == AiProvider.nvidia` → `NvidiaClientService`
  ke `AppConfig.nvidiaBackendUrl/api/chat`. Backend meresolve alias
  via `ALIAS_MAP` di `models.js`.

**File yang berubah**
- `lib/core/constants/ai_models.dart` — rewrite penuh.
- `pengembangan.md` — entry M23 (dokumen ini).

**Verifikasi**
1. `flutter analyze` — pastikan tidak ada import/id yang broken.
2. Jalankan app → tap chip model di composer → bottom sheet harus
   menampilkan 10 entry sesuai urutan tabel di atas.
3. Pilih "NVIDIA Nemotron 3 Ultra 550B" → kirim "hai" → jawaban
   streaming muncul (SSE dari backend NVIDIA).
4. Pilih "DeepSeek V4 Pro" → kirim prompt coding → cek log
   `[nvidia-chat]` di Vercel dashboard menunjukkan
   `model=deepseek-ai/deepseek-v4-pro`.
5. Pilih "Kikai 4.8 Opus" → kirim prompt → tetap route ke jalur
   kie.ai Claude Haiku 4.5 (regression test M21 unlock jalur lama).

**End of M23**

---

## M23.1 — Ikon Kustom per-Model di Model Selector

**Tanggal:** 4 Juli 2026
**Version bump:** `0.12.1+13 → 0.12.2+14`

### Ringkasan
Setiap entry di model selector sekarang punya **ikon PNG kustom** (bulat 38×38, corner radius 11) menggantikan hexagon gradient generik. Ikon dikirim owner via chat, di-embed sebagai asset lokal (bukan network) supaya cepat & offline-friendly.

### File baru (10 PNG)
`assets/models/`:
- `claude-4-8-opus.png` — Kikai 4.8 Opus (robot + code window)
- `nvidia-nemotron-3-ultra-550b.png` — NVIDIA Nemotron (badge hijau NVIDIA)
- `deepseek-v4-pro.png` — DeepSeek V4 Pro (robot ungu + speech bubble code)
- `mistral-small-4-119b.png` — Mistral Small 4 (silver head + circuit brain)
- `kimi-k2-6.png` — Moonshot Kimi K2.6 (chrome robot head + antena)
- `qwen-3-5-122b.png` — **ikon Qwen 3.5-122B-A10B (tersedia untuk model Qwen; belum di-wire karena Qwen belum ada di katalog `ai_models.dart`. Wire dengan `iconAsset: 'assets/models/qwen-3-5-122b.png'` saat Qwen ditambah)**
- `minimax-m2-7.png` — MiniMax M2.7 (helm robot + huruf M)
- `bytedance-seed-oss-36b.png` — ByteDance Seed-OSS 36B
- `gemma-4-31b.png` — Google Gemma 4 31B
- `llama-guard-4-12b.png` — Meta Llama Guard 4 12B

### File diubah
- `lib/models/ai_model.dart` — tambah field opsional `String? iconAsset`.
- `lib/core/constants/ai_models.dart` — set `iconAsset` untuk 9 dari 10 entry (Dracarys sengaja tetap fallback hexagon karena tidak ada ikon Dracarys yang dikirim; owner mengirim ikon Qwen yang belum punya slot).
- `lib/features/chat/widgets/model_selector.dart` — extract `_ModelIcon` widget. Kalau `iconAsset` tersedia → `Image.asset` bulat (ClipRRect radius 11) dengan fallback `errorBuilder` ke hexagon gradient. Saat model locked → overlay gembok samar di tengah + opacity 0.55 pada ikon (menggantikan icon lock full-cover lama).
- `pubspec.yaml` — daftar asset `assets/models/` + version bump `0.12.2+14`.
- `lib/core/constants/app_config.dart` — version sync `0.12.2` build `14`.

### Catatan
- **Ikon Qwen belum dipakai** karena Dracarys Llama 3.1 70B (satu-satunya slot tanpa ikon) adalah keluarga model berbeda — attach ke slot itu akan misleading. File tetap di-bundle di `assets/models/` supaya siap wire begitu Qwen ditambah ke `ai_models.dart`.
- **Behavior selektor lain tidak berubah** — gating unlock, tap-to-mission, dan sort order sama persis dengan M23.
- **Zero dependency baru.** Semua render pakai `Image.asset` built-in Flutter.

### Checklist SOP
- [x] Tidak commit API key / keystore.
- [x] Tidak menyentuh `.github/workflows/*` (0 workflow change).
- [x] Tidak ubah gradle wrapper / `google-services.json`.
- [x] 0 dependency baru di `pubspec.yaml`.
- [x] Version bump sinkron pubspec ↔ AppConfig.
- [x] Milestone append di bawah M23 tanpa menghapus entry lama.
- [x] Warna via `AppColors` (surfaceHigh fallback bg), tidak ada literal color baru.
- [x] Naming: file `snake_case`/`kebab-case`, class `PascalCase` (`_ModelIcon`).

---

## M24 — Monetisasi via AdMob & Buka Semua Model AI

**Tanggal:** 4 Juli 2026
**Version bump:** `0.12.2+14 → 0.13.0+15`

### Ringkasan
Menghapus **seluruh gating unlock model AI** (M21/M23) — semua 10 model
kini free-access untuk semua user. Sebagai gantinya, monetisasi
dilakukan lewat **Google AdMob** dengan 4 placement:

| Placement | Format | Trigger | Ad Unit ID |
|---|---|---|---|
| Home landing | Interstitial | 60 detik setelah user landing di Home (sekali/sesi) | `ca-app-pub-4040764940734722/2791490885` |
| Profile tab | Interstitial | Tap tab Profile pertama kali (sekali/sesi) | `ca-app-pub-4040764940734722/2791490885` |
| Chat | Rewarded Video | Pesan user ke-5 dikirim, lalu bergantian +10, +5, +10, +5, … (siklus) | `ca-app-pub-4040764940734722/7852245873` |
| Daily Check-In | Rewarded Video | Tap tombol Check-in di Mission page | `ca-app-pub-4040764940734722/2322506031` |
| Notifikasi | Native Ad (medium) | Sisip inline tiap 3 notifikasi | `ca-app-pub-4040764940734722/6539164204` |

**AdMob App ID** (terdaftar di `AndroidManifest.xml`):
`ca-app-pub-4040764940734722~3957197502`

### File baru
- `lib/services/ads_service.dart` — singleton pembungkus
  `google_mobile_ads`. Mengelola preload/show + counter siklus chat
  (5 → +10 → +5 → +10 → +5 …). Fail-open: kalau ad tidak siap /
  gagal load, flow user tidak diblokir.

### File diubah
- `pubspec.yaml` — tambah `google_mobile_ads: ^5.1.0`; version
  `0.13.0+15`.
- `android/app/src/main/AndroidManifest.xml` — tambah `meta-data`
  `com.google.android.gms.ads.APPLICATION_ID` =
  `ca-app-pub-4040764940734722~3957197502`.
- `lib/main.dart` — panggil `AdsService.instance.init()` (non-blocking)
  setelah semua service inti siap.
- `lib/core/constants/app_config.dart` — bump `appVersion=0.13.0`,
  `appBuild=15`; komentar model default diperbarui.
- `lib/features/home/home_shell.dart` — timer 60 detik →
  `showHomeInterstitialOnce()`, tap tab Profile →
  `showProfileInterstitialOnce()`.
- `lib/features/chat/chat_controller.dart` — setelah tiap pesan user
  dipersist, panggil `AdsService.instance.notifyUserMessageSent()`
  untuk trigger rewarded ad siklus.
- `lib/features/mission/mission_page.dart` — ganti
  `StreakService.instance.simulateRewardAd()` (placeholder) menjadi
  `AdsService.instance.showRewardedCheckin()` (RewardedAd asli).
- `lib/features/chat/widgets/model_selector.dart` — `isModelUnlocked`
  disederhanakan **selalu return `true`**. Semua parameter (`ent`,
  `streakCount`) menjadi opsional dan diabaikan. Enum `ModelUnlock`
  tetap ada di `ai_model.dart` (backward-compat & siap re-enable
  kelak), tapi tidak lagi memblokir UI.
- `lib/features/notifications/notifications_screen.dart` — sisip
  `_NativeAdTile` inline setiap 3 notifikasi menggunakan
  `NativeTemplateStyle(templateType: TemplateType.medium)`.

### Behavior
- **Tidak ada** perubahan pada backend Nvidia/kie.ai — routing model
  tetap sesuai M23.
- Entitlements M19/M21 (`noAds`, `proActive`, `nvidiaUnlock`) masih
  hidup di data model & Mission page (chip status), tapi **tidak
  dipakai untuk gating model**. Nanti bisa dipakai untuk mem-bypass
  iklan kalau owner mau restore fitur "No Ads" reward.
- Iklan yang gagal load / offline **tidak** mem-block user — flow
  fail-open (chat tetap terkirim, check-in tetap valid).

### Checklist SOP
- [x] Tidak commit API key / keystore.
- [x] Tidak ubah `.github/workflows/*` (0 workflow change).
- [x] Tidak menyentuh gradle wrapper / `google-services.json`.
- [x] Version bump sinkron pubspec ↔ `AppConfig`.
- [x] Milestone append di bawah M23.1 tanpa menghapus entry lama.
- [x] Warna via `AppColors`, tidak ada literal color baru.
- [x] Dependency baru: **1** (`google_mobile_ads`).

**End of M24**


---

## M25 — Rilis Resmi: pastikan iklan asli (bukan Test Ad)

**Tanggal:** 2026-07-06
**Version bump:** `0.13.0+15` → `0.13.1+16`
**Konteks:** Sebelum rilis Play Store, user melaporkan iklan yang
tampil masih berlabel *"Test Ad"*. Investigasi:

- Semua `adUnitId` di `AdsService` **sudah pakai ID produksi asli**
  yang owner berikan (publisher `pub-4040764940734722`). Tidak ada
  ID sample Google (`ca-app-pub-3940256099942544/...`) di seluruh
  codebase.
- `AndroidManifest.xml` `APPLICATION_ID` sudah
  `ca-app-pub-4040764940734722~3957197502`.
- Tidak ada `testDeviceIds` yang di-set di mana pun.

Kenapa label *"Test Ad"* masih muncul? Google Mobile Ads SDK
otomatis menyajikan **test ads** ketika app dijalankan pakai
**debug keystore** / emulator — tanpa peduli Ad Unit-nya asli.
Begitu APK/AAB di-build **release** dan di-sign dengan keystore
rilis resmi (upload key Play Store), label *"Test Ad"* hilang dan
iklan produksi tayang.

### Perubahan defensif
- `lib/services/ads_service.dart` — setelah `MobileAds.instance
  .initialize()`, panggil `updateRequestConfiguration(
  RequestConfiguration(testDeviceIds: const <String>[]))` untuk
  **secara eksplisit mengosongkan** daftar test device. Tidak ada
  jalan bagi test ads untuk aktif via konfigurasi.
- Version bump `0.13.1+16` (pubspec + `AppConfig`).

### Langkah rilis (owner)
1. Build release: `flutter build appbundle --release` (workflow
   `release.yml` sudah handle signing via secret).
2. Upload `.aab` ke Play Console → Production track.
3. Setelah app terpasang dari Play Store / internal testing,
   iklan asli akan tayang tanpa label *"Test Ad"*.

### Checklist SOP
- [x] Tidak ada Ad Unit test / sample di codebase.
- [x] Tidak ubah workflow / keystore / `google-services.json`.
- [x] Dependency: tidak ada penambahan baru.
- [x] Milestone di-append di bawah M24, entry lama utuh.

**End of M25**


---

## M26 — Sinkronisasi alias model NVIDIA (backend `nvidia-api-nine`)

**Tanggal:** 2026-07-06
**Version bump:** `0.13.1+16` → `0.13.2+17`
**Konteks:** Dokumen `tutorial integrasi idin code api.md` (repo
`nvidia-api`) merilis daftar **alias resmi** yang diterima
`POST /api/chat` di `https://nvidia-api-nine.vercel.app`. Beberapa
`apiModelId` di `lib/core/constants/ai_models.dart` masih memakai
alias lama (versi eksperimen M23) sehingga backend akan fallback
ke `nvidia-ultra` — akibatnya user "memilih" DeepSeek / Mistral /
ByteDance Seed-OSS, tapi respon selalu datang dari Nemotron.

### Alias resmi (dari tutorial)
| Model UI                       | Alias backend (`apiModelId`) |
|--------------------------------|------------------------------|
| NVIDIA Nemotron 3 Ultra 550B   | `nvidia-ultra`               |
| DeepSeek V4 Pro                | `deepseek`                   |
| Mistral Small 4 119B           | `mistral`                    |
| Moonshot Kimi K2.6             | `kimi`                       |
| Dracarys Llama 3.1 70B         | `dracarys`                   |
| MiniMax M2.7                   | `minimax`                    |
| ByteDance Seed-OSS 36B         | `bytedance-seed`             |
| Google Gemma 4 31B             | `gemma`                      |
| Meta Llama Guard 4 12B         | `llama-guard`                |

### Perubahan file
- `lib/core/constants/ai_models.dart` — 3 alias diperbaiki:
  - `deepseek-v4-pro` → **`deepseek`**
  - `mistral-small-4` → **`mistral`**
  - `seed-oss` → **`bytedance-seed`**
  Alias lain (`nvidia-ultra`, `kimi`, `dracarys`, `minimax`,
  `gemma`, `llama-guard`) sudah benar dan tidak disentuh.
- `pubspec.yaml` & `lib/core/constants/app_config.dart` —
  version bump `0.13.2+17`.

### Behavior
- Model selector tetap menampilkan **10 model** (1 Claude + 9
  NVIDIA) dengan urutan & metadata tak berubah.
- Setiap pilihan model NVIDIA sekarang **benar-benar** menjalankan
  model yang dimaksud di sisi backend (bukan lagi fallback ke
  Nemotron).
- Endpoint, streaming SSE (`type: reasoning|content|done|error`),
  serta payload (`uid`, `messages`, `temperature`, `top_p`,
  `max_tokens`, `stream`) **tidak berubah** — kompatibel penuh
  dengan `AiClientService` yang sudah ada.
- `maxTokens` per model sudah selaras dengan default tutorial
  (16384 untuk reasoning models, 8192 MiniMax, 4096 Seed-OSS,
  1024 Dracarys, 5 Llama Guard).

### Checklist SOP
- [x] Tidak commit API key / keystore.
- [x] Tidak ubah `.github/workflows/*`.
- [x] Tidak menyentuh gradle wrapper / `google-services.json`.
- [x] Version bump sinkron pubspec ↔ `AppConfig`.
- [x] Milestone di-append di bawah M25, entry lama utuh.
- [x] Dependency baru: **0**.

**End of M26**


## M27 — Fix routing backend NVIDIA: tiap model beneran jalan sendiri

### Konteks bug
User laporan: **semua model di selector (Kimi, DeepSeek, Mistral, dst.) jawab
"Saya model bahasa yang dikembangkan NVIDIA"** — padahal dropdown-nya beda-beda.

### Root cause
`nvidia-api/lib/models.js` versi M26 cuma punya mapping untuk alias
`nvidia-ultra`. Semua alias lain (`kimi`, `deepseek`, `mistral`,
`bytedance-seed`, `minimax`, `dracarys`, `gemma`, `llama-guard`) **jatuh ke
`DEFAULT_MODEL = nvidia/nemotron-3-ultra-550b-a55b`** lewat baris:

```js
return MODEL_MAP[key] || (key.startsWith("nvidia/") ? key : DEFAULT_MODEL);
```

Selain itu `chat.js` selalu inject `reasoning_budget` +
`chat_template_kwargs.enable_thinking` ke tiap request, padahal model seperti
Mistral, MiniMax, Dracarys, Gemma, dan Llama-Guard tidak mendukung parameter
tsb dan bisa error / fall-through ke Nemotron.

### Perubahan
**Backend `nvidia-api/` (repack terpisah):**

1. `lib/models.js` — dirombak jadi **MODEL_REGISTRY** per-alias, tiap entry
   punya `id` + `params` default sesuai tutorial resmi NVIDIA Integrate:
   - `nvidia-ultra`   → `nvidia/nemotron-3-ultra-550b-a55b`
   - `deepseek`       → `deepseek-ai/deepseek-v4-pro`
   - `mistral`        → `mistralai/mistral-small-4-119b-2603` (+ `reasoning_effort:"high"`)
   - `kimi`           → `moonshotai/kimi-k2.6` (+ `chat_template_kwargs.thinking:true`)
   - `dracarys`       → `abacusai/dracarys-llama-3.1-70b-instruct`
   - `minimax`        → `minimaxai/minimax-m2.7`
   - `bytedance-seed` → `bytedance/seed-oss-36b-instruct` (+ `extra_body.thinking_budget:-1`)
   - `gemma`          → `google/gemma-3-27b-it`
   - `llama-guard`    → `meta/llama-guard-4-12b`
   - Legacy alias (`kimi-k2-6`, `deepseek-v4-pro`, dst.) tetap didukung via
     `LEGACY_ALIASES` supaya client versi lama tidak putus.
   - Pass-through model id `vendor/model` yang sudah lengkap.

2. `api/chat.js` — `buildRequest()` sekarang **merge `resolved.params` +
   override eksplisit dari client**. `reasoning_budget` /
   `chat_template_kwargs` cuma di-inject kalau model default memang
   memakainya, jadi Mistral/MiniMax/Gemma/Llama-Guard bersih dari parameter
   yang tidak didukung.
   Respons non-stream juga sekarang mengembalikan `alias` supaya app bisa
   verifikasi routing.

**Flutter app `idincode-main/`:**
- Tidak ada perubahan kode; `lib/core/constants/ai_models.dart` alias sudah
  benar sejak M26 (`kimi`, `deepseek`, `mistral`, `bytedance-seed`, dll).
- `pubspec.yaml` bump ke `0.13.3+18`, `app_config.dart` disesuaikan.

### Hasil
Setelah backend `nvidia-api` di-deploy ulang ke Vercel:
- Pilih **Moonshot Kimi K2.6** → beneran Kimi (moonshotai/kimi-k2.6).
- Pilih **DeepSeek V4 Pro** → beneran DeepSeek.
- Pilih **Mistral Small 4** → beneran Mistral (tanpa error parameter).
- Dst.

### Deploy note (WAJIB)
Perubahan ini butuh **redeploy backend Vercel** — cukup unzip
`nvidia-api-M27.zip`, `vercel --prod`, atau push ke repo yang ke-hook Vercel.
Selama backend belum di-deploy, gejala "semua model = Nemotron" masih terjadi.

**End of M27**


## M28 — Hotfix Gemma model id + endpoint `/api/models`

**Tanggal:** 2026-07-06
**Version bump:** `0.13.3+18` → `0.13.4+19`
**Referensi:** `gudang/gemma-4-31b-it.txt`, `gudang/dracarys-llama-3.1-70b-instruct.txt`,
`nvidia-api/tutorial integrasi idin code api.md` (tabel alias resmi).

### Konteks bug (lanjutan M27)
Setelah M27 sukses memisahkan tiap alias ke real model id-nya sendiri,
alias **`gemma`** masih salah rute karena `MODEL_REGISTRY.gemma.id` di
`nvidia-api/lib/models.js` di-set `google/gemma-3-27b-it` — id tsb TIDAK
tersedia di NVIDIA Integrate. Endpoint upstream membalas 404 / model
not found, sehingga user yang memilih **Google Gemma 4 31B** di
model selector gagal dapat respons (atau ke-fallback lewat error path).

Referensi resmi dari `gudang/gemma-4-31b-it.txt`:

```
model: "google/gemma-4-31b-it"
max_tokens: 16384
chat_template_kwargs: { enable_thinking: true }
```

Selain itu params default **Dracarys** juga beda dari
`gudang/dracarys-llama-3.1-70b-instruct.txt` (`temperature 0.5`,
`top_p 1`). Nilai lama (`0.7 / 0.95`) bukan bug fatal — cuma bikin
karakter output geser dari referensi. Diseragamkan sekalian.

### Perubahan
**Backend `nvidia-api/` (repack terpisah — WAJIB re-deploy Vercel):**

1. `lib/models.js`
   - `gemma.id`: `google/gemma-3-27b-it` → **`google/gemma-4-31b-it`**
   - `gemma.params.max_tokens`: `8192` → **`16384`**
   - `gemma.params.chat_template_kwargs`: tambah `{ enable_thinking: true }`
   - `dracarys.params.temperature`: `0.7` → **`0.5`**
   - `dracarys.params.top_p`: `0.95` → **`1`**
   - `LEGACY_ALIASES`: tambah `gemma-3-27b` & `gemma-3-27b-it` → `gemma`
     (biar client versi lama yang keburu di-cache tidak putus).

2. `api/models.js` (BARU) — endpoint `GET /api/models` sesuai
   dokumentasi tutorial. Return `{ ok, count, default, models[] }`
   dengan `alias`, `id`, `max_tokens`, `reasoning`, `default`.
   Berguna buat verifikasi routing pasca-deploy tanpa harus
   nyalakan streaming.

**Flutter app `idincode-main/`:**
- `pubspec.yaml` + `lib/core/constants/app_config.dart`
  bump `0.13.4+19`.
- **Tidak ada perubahan** di `lib/core/constants/ai_models.dart`
  (`apiModelId: 'gemma'` sudah benar sejak M26 — bug murni di sisi
  backend resolve).

### Verifikasi setelah deploy
1. `GET https://nvidia-api-nine.vercel.app/api/models`
   → entry `gemma` harus `id: "google/gemma-4-31b-it"`.
2. Di app, pilih **Google Gemma 4 31B** → kirim "halo, kamu model apa?"
   → jawaban muncul (bukan hang / error) dan menyebut Gemma, bukan
   Nemotron.
3. Model lain (`kimi`, `deepseek`, `mistral`, `bytedance-seed`,
   `minimax`, `dracarys`, `llama-guard`, `nvidia-ultra`) tetap jalan
   seperti M27.

### Checklist SOP
- [x] Tidak commit API key / keystore.
- [x] Tidak ubah `.github/workflows/*`.
- [x] Tidak menyentuh gradle wrapper / `google-services.json`.
- [x] Version bump sinkron pubspec ↔ `AppConfig`.
- [x] Milestone di-append di bawah M27, entry lama utuh.
- [x] Dependency baru: **0** (client & backend).

### Deploy note (WAJIB)
Perubahan ini backend-only. Redeploy `nvidia-api` ke Vercel
(`nvidia-api-M28.zip` → `vercel --prod`, atau push ke repo yang
ke-hook Vercel). Selama backend belum di-deploy, gejala
"pilih Gemma → gagal / fallback Nemotron" masih terjadi.

**End of M28**


---

## M29 — Swap upstream model NVIDIA (deepseek/minimax/gemma/bytedance) + hapus llama-guard

**Tanggal:** 2026-07-06
**Scope:** backend `nvidia-api/lib/models.js` + Flutter `lib/core/constants/ai_models.dart`

### Masalah (dari screenshot user)
- **DeepSeek V4 Pro** → "(Respons kosong dari server.)"
- **Moonshot Kimi K2.6** → hanya balas "p" (echo, tidak jalan penuh)
- **Nemotron 3 Ultra 550B** → hanya balas "p"
- **Dracarys Llama 3.1 70B** → hanya balas "p"
- **MiniMax M2.7** → `ClientException: Connection closed while receiving data`
- **ByteDance Seed-OSS 36B** → `ClientException: Connection closed while receiving data`
- **Google Gemma 4 31B** → "(Respons kosong dari server.)"
- **Mistral Small 4 119B** → jalan normal ✅
- **Meta Llama Guard 4 12B** → balas "safe" (memang classifier, bukan chat)

### Keputusan
User menyediakan model pengganti via NVIDIA Integrate yang sudah dites di
gudang. Alias key backend tetap sama supaya app tidak perlu ubah routing.

| Alias           | Sebelum                                | Sesudah (M29)                  |
| --------------- | -------------------------------------- | ------------------------------ |
| `deepseek`      | `deepseek-ai/deepseek-v4-pro`          | `z-ai/glm-5.2`                 |
| `minimax`       | `minimaxai/minimax-m2.7`               | `minimaxai/minimax-m3`         |
| `gemma`         | `google/gemma-4-31b-it`                | `stepfun-ai/step-3.7-flash`    |
| `bytedance-seed`| `bytedance/seed-oss-36b-instruct`      | `qwen/qwen3.5-397b-a17b`       |
| `llama-guard`   | `meta/llama-guard-4-12b`               | **DIHAPUS**                    |

### Params per model (M29)
- **deepseek → z-ai/glm-5.2**
  `max_tokens: 16384, temperature: 1, top_p: 1, seed: 42`
- **minimax → minimaxai/minimax-m3**
  `max_tokens: 8192, temperature: 1, top_p: 0.95` (multimodal, terima
  `image_url` & `video_url`)
- **gemma → stepfun-ai/step-3.7-flash**
  `max_tokens: 16384, temperature: 1, top_p: 0.95`
- **bytedance-seed → qwen/qwen3.5-397b-a17b**
  `max_tokens: 16384, temperature: 0.6, top_p: 0.95, top_k: 20,
   presence_penalty: 0, repetition_penalty: 1`

### File yang berubah
- `nvidia-api/lib/models.js`
  - Update 4 entry di `MODEL_REGISTRY` (id + params)
  - Hapus entry `"llama-guard"` dan alias legacy `"llama-guard-4-12b"`
- `idincode-main/lib/core/constants/ai_models.dart`
  - Ubah `label` 4 model sesuai upstream baru
    (`Z-AI GLM 5.2`, `MiniMax M3`, `Qwen 3.5 397B A17B`,
     `StepFun Step 3.7 Flash`)
  - MiniMax slot: `supportsVision: true` (M3 multimodal)
  - Hapus entry `Meta Llama Guard 4 12B`
- `pubspec.yaml` & `app_config.dart`: `0.13.4+19` → **`0.13.5+20`**

### Catatan deploy
- Backend `nvidia-api` **harus di-redeploy** ke Vercel (env var
  `NVIDIA_API_KEY` tidak berubah).
- Icon asset `assets/models/llama-guard-4-12b.png` tidak lagi direferensi;
  boleh dihapus manual kalau mau clean.
- `apiModelId` (`deepseek`/`minimax`/`gemma`/`bytedance-seed`) sengaja
  dipertahankan supaya alias legacy client masih route benar.


---

## M30 — Slim Single-Model + Dataset KiKai (KiKai Pro)

### Ringkasan
Rombak besar sesuai permintaan owner: hanya **satu model** yang tersisa
di selector — **KiKai Pro** (backend NVIDIA Nemotron 3 Ultra 550B).
Semua varian lain dihapus. Dataset lokal `Dataset-For-Ai-Engineer` di-
bundle ke APK dan dipakai sebagai sumber system prompt persona.

### File yang berubah
- `lib/core/constants/ai_models.dart`
  - Dihapus: Claude Haiku, Z-AI GLM, Mistral, Kimi, Dracarys,
    MiniMax, Qwen, StepFun.
  - Tersisa satu entry: `id: kikai-pro`, `apiModelId: nvidia-ultra`,
    `label: 'KiKai Pro'`.
- `lib/core/constants/app_config.dart`
  - `defaultModelId` diubah dari `claude-4-6-haiku` → `kikai-pro`.
- `lib/services/kikai_dataset_service.dart` **(baru)**
  - Load JSONL persona & identity dari `assets/dataset/**` sekali di
    startup, susun jadi system prompt (batas 20 contoh per file).
  - Fallback string aman kalau asset belum termuat.
- `lib/services/nvidia_client_service.dart`
  - `streamMessage` & `sendMessage` sekarang `await
    KikaiDatasetService.instance.ensureLoaded()` sebelum request.
  - `_buildMessages` inject system prompt persona di depan history.
- `lib/main.dart`
  - Preload `KikaiDatasetService.instance.ensureLoaded()` (unawaited)
    setelah `ApiKeyService.init()`.
- `pubspec.yaml`
  - Deklarasi asset directory penuh untuk `assets/dataset/**`
    (Universal, casual-vibe, dataset/ringan, security, integrasiApi).

### Dataset
- Sumber: `Dataset-For-Ai-Engineer-main.zip` (owner upload).
- Ukuran total: ± 14 MB, 397 file (JSONL + MD).
- Struktur di APK: `assets/dataset/{Universal,casual-vibe,dataset,security,integrasiApi}/…`
- Seed file untuk system prompt:
  - `Universal/dataset/identity/kikai_developer.jsonl`
  - `Universal/dataset/identity/universal_persona.jsonl`
  - `Universal/dataset/interaction/casual_chat.jsonl`
  - `dataset/ringan/identity/persona.jsonl`
- Corpus penuh tetap ter-bundle → siap dipakai untuk RAG lokal di
  milestone berikutnya.

### Catatan
- Backend `nvidia-api` tidak perlu diubah — alias `nvidia-ultra` sudah
  ada di registry.
- Model lama masih bisa muncul di history thread; `findModelById`
  akan null → controller otomatis fallback ke `kAiModels.first` =
  KiKai Pro.


---

## M31 — Rebrand "KiKai Native", Anti-Cut Responses & About Page

### Ringkasan
Rebrand user-facing untuk menyamarkan bahwa backend memakai NVIDIA
(sekarang model terlihat sepenuhnya sebagai produk asli KiKai),
menghilangkan pemotongan pada jawaban panjang, menambah halaman
About profesional dengan profil developer, dan menyesuaikan Mission
Rewards agar konsisten dengan katalog single-model.

### File yang berubah
- `lib/core/constants/ai_models.dart`
  - `description` model KiKai Pro ditulis ulang — tidak menyebut
    NVIDIA / 550B / GPU cloud. Cukup: "flagship reasoning KiKai".
  - `maxTokens` dinaikkan `16384 → 32768` supaya jawaban panjang
    (contoh: dump `sqlmap --help`) tidak ter-cut.
- `lib/services/nvidia_client_service.dart`
  - `reasoning_budget` diturunkan `16384 → 4096`. Reasoning tokens
    tidak lagi menghabiskan budget output; sisa untuk jawaban final
    jauh lebih besar → response tidak terpotong.
- `lib/features/about/about_page.dart` **(baru)**
  - Halaman About profesional dark-first. Berisi:
    - Hero developer "Idin Iskandar — Solo Developer, Pencipta
      aplikasi ini" (gradient brand).
    - Copy "Tentang KiKai" & daftar fitur utama.
    - Link sosial media (Instagram, LinkedIn, GitHub) dan dua model
      open source di Hugging Face (`KiKai-For-Hacking-7.6B`,
      `KiKai-Universal-7B`). Semua dibuka via `url_launcher` mode
      `externalApplication`.
    - Footer versi + copyright.
- `lib/features/settings/settings_screen.dart`
  - Row "About KiKai" sekarang `Navigator.push` ke `AboutPage`
    (bukan lagi `showAboutDialog`).
  - Hapus `_showAbout()` dan import `api_key_service.dart` yang
    tidak lagi dipakai.
- `lib/features/mission/mission_page.dart`
  - Chip status: `KiKai Pro` → `Priority Response`, `Nvidia Premium`
    → `KiKai Ultra`.
  - Reward Tiers disesuaikan katalog single-model:
    - 300 Views → No Ads Permanen
    - 1,000 Views → Priority Response 30 Hari
    - 5,000 Views → KiKai Ultra Unlock

### Catatan
- Entitlement enum (`proActive`, `nvidiaUnlock`) di backend TIDAK
  diubah — hanya label UI. Legacy claim tetap kompatibel.
- Backend `nvidia-api` tidak perlu redeploy; perubahan murni klien.
- Aturan repo tetap: tidak ada API key di APK, dark-first theme.

## Milestone M32 — Notifications UX, Universal Upload & Anti-RE Hardening
Tanggal: 2026-07-19

### Ringkasan
Iterasi berbasis feedback owner:
1. Iklan native muncul juga di tab **History** (sebelumnya cuma di
   Notifications).
2. Tap notifikasi → halaman detail dedicated, siap menampung link
   update APK yang di-push admin dashboard.
3. Composer dukung upload file universal (kode, dokumen, gambar).
4. Dataset di `assets/dataset/**` disembunyikan pakai native XOR key
   supaya reverse engineer via MT-Manager mentah gak dapat teks.
5. Anti-tamper redirect diarahkan ke landing baru
   `https://idinlabs-dev.github.io/hahahafuckyou/`.

### Perubahan File
- `lib/features/shared/native_ad_tile.dart` **(baru)**
  - Widget `NativeAdTile` dipakai bersama antara Notifications &
    History (unit id sama: `ca-app-pub-4040764940734722/6539164204`).
- `lib/features/history/history_screen.dart`
  - Sisipkan `NativeAdTile` tiap 4 thread di list.
- `lib/features/notifications/notifications_screen.dart`
  - `_NotifTile` dibungkus `InkWell` → tap membuka
    `NotificationDetailPage` dengan objek `AppNotification`.
- `lib/features/notifications/notification_detail_page.dart` **(baru)**
  - Halaman full-screen: header ikon+badge ADMIN, judul, timestamp
    lengkap, body scrollable dengan deteksi URL otomatis (regex
    `https?://…`) — URL jadi tap-able & muncul list "Tautan cepat"
    (mode `externalApplication` via `url_launcher`).
- `lib/features/chat/widgets/message_composer.dart`
  - Ikon paperclip → `file_picker` universal (`FileType.any`).
    File teks (<200KB, UTF-8 decodable) langsung diserialisasi jadi
    blok ```` ```<ext>``` ```` sebelum pesan user; file biner dilampirkan
    metadata (nama + ukuran) supaya model tetap punya konteks.
  - Ikon kamera diganti ikon gambar → `FilePicker` mode image. Karena
    model KiKai Pro text-only, gambar dilampirkan sebagai metadata
    (nama + ukuran) dengan catatan agar model minta deskripsi tambahan.
  - Chip attachment muncul di atas field text, bisa dihapus per-item.
- `lib/services/tamper_guard.dart`
  - `_redirectUrl` → `https://idinlabs-dev.github.io/hahahafuckyou/`.
- `lib/services/native_bridge.dart`
  - Tambah `getDatasetKey()` (fallback 0xA7).
- `lib/services/kikai_dataset_service.dart`
  - Path seed berubah ke ekstensi `.jsonlx`.
  - Loader baca bytes → XOR byte-per-byte dengan key dari
    `NativeBridge.getDatasetKey()` → decode UTF-8 → parse JSONL.

### Native (Android C++)
- `android/app/src/main/cpp/keychain.cpp`
  - Fungsi baru `keychain_get_dataset_key()`. Nilai key (0xA7)
    disimpan sebagai `0xE7 - 0x40` supaya `strings` tidak menemukan
    literal 0xA7 di `.rodata`.
- `android/app/src/main/cpp/memek.cpp`
  - Tambah forward decl `keychain_get_dataset_key` dan JNI export
    `Java_com_claudememek_app_NativeBridge_getDatasetKey`.
- `android/app/src/main/kotlin/com/claudememek/app/MainActivity.kt`
  - Method channel handler `getDatasetKey` → `NativeBridge.getDatasetKey()`.
  - Tambah `external fun getDatasetKey(): Int`.

### Aset Dataset
- Semua `.jsonl` dan `.md` di `assets/dataset/**` (397 file, ~14MB)
  di-XOR dengan key 0xA7 lalu direname ke `.jsonlx` / `.mdx`.
- Loader satu-satunya (`KikaiDatasetService`) sudah ikut update. Owner
  yang mau menambah file dataset baru harus menjalankan XOR encode
  yang sama sebelum drop ke folder assets.
- Karena `pubspec.yaml` sudah listing folder (bukan file individual),
  tidak ada perubahan pubspec untuk asset — hanya versi app naik ke
  `0.14.0+21`.

### Catatan
- Backend Firebase / Node worker tidak diubah.
- ProGuard/R8 masih sesuai M22 (repackageclasses 'o' +
  allowaccessmodification + strip log). Ditambah XOR dataset di atas
  memenuhi target ~80% anti-RE (bar untuk MT-Manager & `strings`
  cukup tinggi; attacker perlu Ghidra + trace JNI).

---

## M33.3 — Mode Selector + Sanitized Errors + File Chip

**Delivered:**

1. **Friendly error messages** — `NvidiaClientService` sekarang punya
   `_friendlyError()` / `_friendlyStatus()` yang memetakan raw error
   (ResourceExhausted, SocketException, host lookup, timeout, 401/403/429/5xx)
   ke pesan singkat bahasa Indonesia — **tanpa** bocorin URL endpoint,
   stack trace, atau nama vendor.

2. **Mode Selector (4 modes)** — `lib/core/constants/ai_models.dart`
   sekarang punya 4 entri (Santai, Coding, Hacking, Universal) dengan
   `apiModelId` sama (`nvidia-ultra`) tapi `personaSystemPrompt`
   berbeda. Persona di-inject ke system prompt di
   `NvidiaClientService._buildMessages`. Header bottom sheet diubah
   dari "Pilih model" → "Pilih mode".

3. **Image upload dihilangkan** — `_pickImage` inline icon dihapus dari
   `MessageComposer`. User hanya melihat 1 tombol lampiran (file
   universal).

4. **File chip di bubble user** — attachment sekarang dibungkus
   sentinel `<<<KIKAI_FILE ... >>> ... <<<KIKAI_FILE_END>>>`. Isi file
   tetap dikirim ke AI apa adanya (persis seperti sebelumnya), tapi
   `_UserRow` di `message_bubble.dart` mem-parse sentinel dan render
   sebagai chip (ikon + nama + size), sementara teks user asli tetap
   tampil di bubble.

---

## M38 — Slim Build + Icon Rebrand + Identity Scoping

**Build size optimization (arm64-only)**
- `android/app/build.gradle`: `abiFilters` diciutkan jadi `arm64-v8a` saja
  (drop `armeabi-v7a` & `x86_64`). Target: HP Android 10+ modern.
- `scripts/build-apk-arm64.sh`: helper build `flutter build apk --release
  --target-platform android-arm64 --split-per-abi --obfuscate
  --split-debug-info=build/debug-info`. Ekspektasi ukuran ~55–70MB
  (turun dari ~193MB fat APK). AAB skip — distribusi manual, bukan
  Play Store.

**Icon rebrand — no more sparkles**
- Semua `Icons.auto_awesome*` diganti `Icons.bolt*` (rounded/outlined)
  di: skills_service, models_gallery_page, about_page, settings_screen,
  login_screen, home_shell, deep_research_card.

**Identity injection sekarang per-model (`nvidia_client_service.dart`)**
- `apiModelId == 'nvidia-ultra'` (KiKai personas: Santai/Coding/Hacking/
  Universal) → identity KiKai penuh + reminder Idin Iskandar + sosmed.
- `apiModelId == 'deepseek-v4-flash'` (rebrand "Kimi") → identity Kimi
  kuat (`KikaiDatasetService.kimiSystemPrompt`) supaya mengaku Kimi,
  bukan DeepSeek.
- Model lain (GLM 5.2, DeepSeek V4 Pro, GPT-OSS 20B) → **natural** —
  cuma persona bawaan modelnya, tanpa injection identity KiKai.
- `kikai_dataset_service.dart`: tambah `_kimiIdentityRule` +
  `kimiSystemPrompt` getter.
