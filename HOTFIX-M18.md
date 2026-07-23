# HOTFIX M18 — "Given final block not properly padded" pas build APK

## TL;DR
Error itu = **password keystore mismatch**. Ada 2 kemungkinan:

- **A)** Lo masih punya backup `.7z` dari workflow generate-keystore lama.
- **B)** Backup hilang / lupa password → generate ulang keystore baru.

Pilih salah satu di bawah.

---

## Opsi A — Restore dari backup .7z (paling aman, SHA-1 gak berubah)

1. Extract file `claude-keystore-backup-ENCRYPTED.7z` pakai password yg lo
   input pas trigger workflow generate-keystore. Isi: `claude-release.jks`,
   `claude-release.jks.base64`, `SECRETS.txt`, `FINGERPRINTS.txt`.
2. Buka repo → **Settings → Secrets and variables → Actions**.
3. Update 4 secret ini pakai nilai dari `SECRETS.txt`:
   - `ANDROID_KEYSTORE_BASE64`  ← isi `claude-release.jks.base64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`  (biasanya `claude-release`)
   - `ANDROID_KEY_PASSWORD`  (di build M18+ = sama dgn store password)
4. Push commit apa aja / trigger **Android Build** manual. Pre-flight step
   baru bakal ngasih tau kalau masih mismatch dalam 3 detik.

---

## Opsi B — Regenerate keystore (backup hilang / password lupa)

⚠️ **Konsekuensi:** SHA-1 lama mati. Semua APK yg udah lo distribusi ke
user pakai keystore lama **gak bisa update lagi via install biasa**
(harus uninstall dulu). Google Sign-in existing juga akan ketolak sampai
lo update SHA-1 baru di Firebase.

1. **Actions** tab → **Generate Release Keystore** → **Run workflow**.
   Input:
   - `key_alias` = `claude-release` (default)
   - `backup_password` = password buat encrypt backup (INGAT!)
   - `force_regenerate` = **`YES`** (persis, uppercase)
2. Tunggu ~1 menit. Buka Job Summary → copy **SHA-1** & **SHA-256**.
3. Download artifact `claude-keystore-backup-ENCRYPTED` → simpan aman
   di Google Drive / password manager.
4. **Firebase Console** → Project settings → Your apps
   (`com.claudememek.app`) → **Add fingerprint** → paste SHA-1 & SHA-256.
5. Klik **Download google-services.json** yg baru → replace
   `android/app/google-services.json` → commit via github.com web UI.
6. Trigger **Android Build** ulang. Pre-flight step bakal validasi
   sebelum lanjut ke `flutter build apk`.

---

## Kenapa error ini bisa muncul di build sebelumnya?

Root cause historis (build workflow lama M17):
1. Password disimpan ke 2 secret terpisah (`ANDROID_KEYSTORE_PASSWORD`
   ≠ `ANDROID_KEY_PASSWORD`).
2. Kalau salah satu ke-truncate saat paste manual di web UI, atau kalau
   lo regenerate keystore tapi lupa update **semua** secret sekaligus,
   Gradle akan sukses buka store tapi gagal decrypt key entry →
   `KeytoolException: Get Key failed: Given final block not properly padded`.
3. Error baru muncul di task `:app:packageRelease` (menit ke-6-an), bikin
   loop debugging panjang.

## Yang berubah di M18

- **`generate-keystore.yml`**: sekarang pakai **1 password aja** (store ==
  key), tipe **PKCS12** eksplisit, plus self-test sebelum set secret.
  Password mismatch model gini secara fundamental gak bisa terjadi lagi
  di keystore baru.
- **`android/app/build.gradle`**: `keyPassword` auto-fallback ke
  `storePassword` kalau env `ANDROID_KEY_PASSWORD` kosong / whitespace.
  Print signing summary jelas ke Gradle log.
- **`android-build.yml`**: pre-flight step `keytool -list` buat validasi
  keystore ↔ password **sebelum** Gradle jalan. Fail 3 detik dgn pesan
  actionable, bukan crash 6 menit di packageRelease.
- **`android/settings.gradle`**: Kotlin plugin 1.9.22 → **1.9.24**
  (hilangkan warning "Your project requires a newer version of the
  Kotlin Gradle plugin"). Masih fully-compatible dgn Flutter 3.24.5.

## Verifikasi setelah fix diterapkan

Build workflow output yg diharapkan:
```
✅ Keystore & password match. Aman lanjut build.
...
BUILD SUCCESSFUL in 3m 20s
```

Kalau masih fail dengan pesan pre-flight M18 → lanjut Opsi A atau B di atas.
