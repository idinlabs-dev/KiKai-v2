# M19 — Creator Mission System (Growth & Reward Economy)

## Latar Belakang

Setelah sistem autentikasi, keamanan, anti-tamper, dan monetisasi dasar selesai, muncul pemikiran untuk membangun sistem pertumbuhan (growth system) berbasis komunitas.

Daripada mengandalkan iklan berbayar atau sistem referral tradisional yang rentan disalahgunakan (multi akun, device farming, self referral), dipilih pendekatan baru:

> User membantu mempromosikan aplikasi melalui konten media sosial, kemudian mendapatkan reward berupa fitur premium.

Tujuan utama:
- meningkatkan exposure aplikasi secara organik;
- mengurangi biaya marketing;
- mengurangi risiko abuse referral;
- meningkatkan loyalitas komunitas.

---

## Konsep Fitur

Membuat halaman baru:

```
Mission Center
```

yang berisi berbagai misi komunitas untuk mendapatkan reward premium.

Contoh tampilan:

```
🎯 Creator Mission

Buat konten TikTok tentang aplikasi Claude 4.8 AI.

Syarat:
✓ Tag akun resmi aplikasi
✓ Video harus publik
✓ Konten original
✓ Memenuhi minimal jumlah views

Reward:
300 views   → No Ads permanen
1000 views  → Claude Pro 30 hari
5000 views  → Nvidia Premium Unlock
```

---

## Alur Sistem

```
User
    ↓
Membuat konten TikTok
    ↓
Tag akun resmi aplikasi
    ↓
Upload link video ke aplikasi
    ↓
Masuk ke database "creator_submissions"
    ↓
Status = pending
    ↓
Admin melakukan review
    ↓
Approve / Reject
    ↓
Reward otomatis diberikan
```

---

## Struktur Database

### creator_submissions

```json
{
  "uid": "user_uid",
  "username": "user",
  "platform": "tiktok",
  "video_url": "https://tiktok.com/xxxxx",
  "views": 0,
  "status": "pending",
  "reward_type": null,
  "created_at": "timestamp"
}
```

---

## Reward System

### Tier 1

```
300 views
    ↓
No Ads permanen
```

Tujuan:
- memberikan motivasi awal;
- reward murah;
- meningkatkan jumlah konten.

---

### Tier 2

```
1000 views
    ↓
Claude Pro 30 hari
```

Tujuan:
- meningkatkan engagement;
- memperkenalkan fitur premium.

---

### Tier 3

```
5000 views
    ↓
Nvidia Premium Unlock
```

Tujuan:
- memberikan reward eksklusif;
- mendorong creator membuat konten berkualitas.

---

## Anti Abuse

Untuk mencegah penyalahgunaan:

### Validasi wajib:

- video harus publik;
- akun TikTok harus mencantumkan tag akun resmi;
- satu akun hanya dapat memperoleh reward creator tertentu satu kali;
- admin wajib melakukan verifikasi manual;
- view hasil bot atau view farm dapat ditolak;
- reward tidak diberikan otomatis tanpa persetujuan admin.

---

## Dashboard Admin

Tambahkan halaman:

```
Creator Mission Review
```

Contoh:

```
User:
idinceliboy

Platform:
TikTok

Video:
https://tiktok.com/xxxxx

Views:
5231

Status:
[PENDING]

[APPROVE]
[REJECT]
```

---

## Keuntungan Sistem Ini

### Dibanding referral:

```
Referral:
- mudah dinuyul
- perlu device validation
- perlu anti multi account
- sulit diaudit

Creator Mission:
- lebih sulit dimanipulasi
- menghasilkan promosi nyata
- meningkatkan brand awareness
- biaya marketing hampir nol
```

---

## Filosofi

Daripada membayar iklan kepada platform:

```
Developer
        ↓
memberikan fitur premium
        ↓
user mempromosikan aplikasi
        ↓
aplikasi berkembang
        ↓
kedua pihak diuntungkan
```

---

## Catatan Developer

Ide ini muncul karena kekhawatiran terhadap abuse pada sistem referral tradisional.

Daripada melawan ribuan akun palsu, lebih baik mengubah sistem reward menjadi berbasis kontribusi nyata terhadap pertumbuhan aplikasi.

> "Jika user ingin mendapatkan fitur premium, bantu aplikasi berkembang terlebih dahulu."

— Catatan pengembangan M19
