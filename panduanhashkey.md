# 🔐 Panduan Keystore & SHA-1 (WAJIB DIBACA — Jangan Sampai Lupa!)

> Dokumen ini merangkum semua yang lo perlu tau soal keystore, SHA-1, dan Google Sign-in.
> Simpan baik-baik. Setiap kali bingung → baca ulang file ini.

---

## 🎯 Inti / TL;DR

- **Keystore = KTP aplikasi lo.** Dibuat **SEKALI SEUMUR HIDUP** aplikasi.
- **SHA-1 = sidik jari KTP itu.** Selama keystore-nya sama → SHA-1 **TIDAK PERNAH BERUBAH**.
- **Update aplikasi (fitur baru, bug fix, versi baru) TIDAK mengubah SHA-1** — asalkan pakai keystore yang sama.
- Firebase Console cukup lo isi SHA-1 **1 kali aja**. Selamanya.

---

## 📅 Urutan Setup (HANYA DILAKUKAN SEKALI)

Ini alur wajib pertama kali. **Salah urutan = Google Sign-in rusak.**

```
1. Set Secret GH_PAT di GitHub → Settings → Secrets → Actions
   (Personal Access Token, scope: repo + workflow)

2. Ganti .github/workflows/generate-keystore.yml dengan versi FIXED
   (yang pakai openssl rand -hex 16, bukan tr|head)

3. Jalankan workflow "Generate Release Keystore"
   → Copy SHA-1 & SHA-256 dari Job Summary
   → Download artifact .7z → simpan aman (Google Drive / password manager)

4. Firebase Console → Project Settings → Your App (Android)
   → Add Fingerprint → paste SHA-1
   → Add Fingerprint → paste SHA-256
   → Download google-services.json (versi BARU)

5. Replace android/app/google-services.json di repo → commit → push

6. Jalankan workflow "Build APK"
   → Download APK

7. UNINSTALL APK lama di HP dulu (WAJIB, kalau engga bakal signature mismatch)
   → Install APK baru → tes Google Sign-in ✅
```

**Setelah step 7 sukses → SELESAI. Setup permanen. Jangan diulang.**

---

## 🔁 Alur Update Aplikasi (Setiap Kali Ada Fitur/Bugfix Baru)

Ini yang bakal lo lakuin **berulang-ulang** seumur hidup aplikasi:

```
1. Edit kode / tambah fitur / fix bug
2. Push ke GitHub
3. Jalankan workflow "Build APK"
4. Download APK baru
5. Install di HP (nimpa yang lama — TIDAK perlu uninstall)
   ✅ Google Sign-in tetap jalan
   ✅ SHA-1 tetap sama
   ✅ Firebase TIDAK perlu disentuh
```

**Yang TIDAK perlu dilakuin lagi:**
- ❌ Generate keystore ulang
- ❌ Copy-paste SHA-1 ke Firebase
- ❌ Download google-services.json baru
- ❌ Uninstall APK sebelum install versi baru

---

## ⚠️ KAPAN SHA-1 BERUBAH? (Bahaya — Hindari!)

SHA-1 berubah **HANYA** kalau:

| Aksi | Efek |
|------|------|
| Generate keystore baru | ❌ SHA-1 baru → Google Sign-in RUSAK di semua APK lama |
| Kehilangan file keystore | ❌ Terpaksa bikin baru → SHA-1 baru |
| Build pakai debug keystore | ⚠️ SHA-1 debug beda per mesin — bukan untuk rilis |
| Build tanpa signing (unsigned) | ❌ Tidak bisa install / SHA-1 kosong |

**Aturan emas:**
> Jangan pernah jalankan workflow "Generate Release Keystore" **lagi** setelah setup pertama berhasil,
> kecuali darurat (keystore hilang) dengan flag `force_regenerate=YES`.

---

## 🧠 Kenapa Keystore Permanen?

Android verifikasi APK pakai signature dari keystore. Kalau signature beda:
- Sistem nolak install (harus uninstall dulu)
- Google Play nolak update
- Firebase Auth (Google Sign-in) nolak karena SHA-1 di server ≠ SHA-1 di APK

Makanya keystore itu **aset paling berharga** di project Android. Backup di:
1. Google Drive pribadi (folder terenkripsi)
2. Password manager (Bitwarden / 1Password)
3. Email ke diri sendiri (attach .7z + password terpisah)

**Kalau keystore hilang → aplikasi lo dianggap "aplikasi baru" oleh Android & Firebase. Semua user harus uninstall & install ulang.**

---

## 🐛 Error yang Pernah Terjadi & Solusinya

### 1. `Error: Secret GH_PAT belum di-set`
**Penyebab:** Belum tambah PAT di GitHub Secrets.
**Solusi:** GitHub → Settings → Developer settings → Personal access tokens → Generate new token (classic) → scope `repo` + `workflow` → copy → paste ke repo Settings → Secrets → Actions → `GH_PAT`.

### 2. `tr: write error: Broken pipe` + `exit code 1`
**Penyebab:** `tr -dc ... </dev/urandom | head -c 32` kena SIGPIPE karena `set -o pipefail`.
**Solusi:** Ganti dengan `openssl rand -hex 16` (sudah difix di `generate-keystore-FIXED.zip`).

### 3. Google Sign-in error setelah install APK baru
**Penyebab:** SHA-1 di Firebase ≠ SHA-1 keystore yang dipakai build.
**Solusi:**
- Cek fingerprint APK: `keytool -printcert -jarfile app.apk`
- Bandingkan dengan SHA-1 di Firebase Console
- Kalau beda → update fingerprint di Firebase → download google-services.json baru → replace → rebuild

### 4. "App not installed" saat install APK baru
**Penyebab:** APK baru disign dengan keystore beda dari APK yang sudah ke-install.
**Solusi:** Uninstall APK lama dulu → install yang baru.

---

## 📋 Checklist Simpel

Setup awal (sekali):
- [ ] `GH_PAT` di GitHub Secrets ✅
- [ ] `generate-keystore.yml` versi FIXED ✅
- [ ] Jalankan "Generate Release Keystore" ✅
- [ ] Backup file keystore `.7z` di 3 tempat ✅
- [ ] SHA-1 & SHA-256 di Firebase ✅
- [ ] `google-services.json` baru di repo ✅
- [ ] Build APK → uninstall lama → install baru → tes login Google ✅

Update rutin:
- [ ] Push kode → Build APK → install (tanpa uninstall) → selesai ✅

---

## 🚨 JANGAN LAKUKAN INI

- ❌ Jangan hapus workflow `generate-keystore.yml` walau udah ga dipakai (jaga-jaga darurat)
- ❌ Jangan commit file `.jks` / `.keystore` ke repo publik
- ❌ Jangan share password keystore di chat/screenshot
- ❌ Jangan jalankan ulang "Generate Release Keystore" tanpa flag `force_regenerate=YES`
- ❌ Jangan lupa backup keystore — kalau hilang, GAME OVER

---

**Update terakhir:** 2 Juli 2026
**File terkait:**
- `generate-keystore-FIXED.zip` — workflow fix broken pipe
- `idincode-main-M17.zip` — source code aplikasi
