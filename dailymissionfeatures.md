# 🚀 Fitur Baru - Daily Login Streak Premium

## Ide
Menambahkan sistem **Daily Login Reward** untuk meningkatkan retention user dan membuat user terus membuka aplikasi setiap hari.

---

## Mekanisme

- User melakukan login/check-in setiap hari.
- Progress login harian disimpan di server/database.
- Setelah user berhasil login selama **7 hari berturut-turut**, maka user mendapatkan status:

### ⭐ Premium Temporary
- Semua iklan dinonaktifkan.
- User dapat menggunakan aplikasi tanpa gangguan iklan.
- Tidak ada batas penggunaan tambahan.

---

## Aturan Reset

Jika user tidak membuka aplikasi selama **1 hari saja**, maka:

```text
Streak = 0
Premium = Dicabut
```

User harus memulai kembali dari hari pertama.

---

## UI/UX

### Halaman Profile

```text
🔥 Daily Login Streak

Hari 1 ✅
Hari 2 ✅
Hari 3 ✅
Hari 4 ✅
Hari 5 ✅
Hari 6 ✅
Hari 7 🎁 PREMIUM

Progress : 6/7
```

---

### Setelah Berhasil

```text
🎉 Selamat!

Anda mendapatkan:
⭐ Premium Mode
🚫 Bebas Iklan
⚡ Pengalaman AI lebih nyaman

Tetap login setiap hari agar status premium tidak hilang.
```

---

### Jika Streak Putus

```text
💀 Streak terputus!

Anda tidak membuka aplikasi selama 1 hari.

Status premium telah dicabut.
Silakan mulai kembali dari hari pertama.
```

---

## Tujuan Fitur

- Meningkatkan Daily Active User (DAU).
- Meningkatkan retention pengguna.
- Membentuk kebiasaan membuka aplikasi setiap hari.
- Memberikan insentif tanpa mengeluarkan biaya.
- Mengurangi kemungkinan uninstall aplikasi.
- Menciptakan efek "sayang kalau streak hilang".

---

## Status

- [x] Desain UI (kartu 7-hari grid + progress bar di `ProfileScreen`)
- [x] Streak system (local-first via `SharedPreferences`, service `StreakService`)
- [x] Database user streak (kunci `streak_count`, `streak_last_date`)
- [x] Premium temporary logic (`StreakState.premiumActive = count >= 7`)
- [x] Reset streak otomatis (gap ≥ 1 hari kalender lokal → count reset ke 1)
- [x] Dialog "Selamat!" saat mencapai hari ke-7
- [x] Dialog "Streak terputus!" saat gap ≥ 1 hari
- [ ] Backend streak system (opsional — belum, masih device-local)
- [ ] Integrasi non-aktifkan iklan (belum ada iklan di app; hook siap begitu ads dipasang)
- [ ] Testing end-to-end multi-device

**Selesai di:** Milestone **M5** — lihat `pengembangan.md`.
