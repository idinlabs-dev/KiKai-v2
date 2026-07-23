# Rancangan Monetize System — KiKai

> **Created by:** Idin Code
> **Status:** Draft
> **Tanggal:** 4 Juli 2026

---

## 1. Ringkasan

Sistem monetisasi berbasis **retention loop** + **social growth loop**.
Model AI premium di-*gate* pakai iklan (Ads), dan user bisa **unlock No-Ads** dengan dua jalur:

1. **Login streak harian** (jalur retention) — reward berjenjang: 3 / 7 / 12 hari.
2. **Bonus loyalitas** — login 30 hari + minimal 50 chat/hari → reward 30 hari No-Ads.
3. **Creator mission** (jalur growth loop) — bikin konten TikTok / Instagram / Facebook,
   min. **6.000 views** & retensi rata-rata **≥ 1 menit** → **No-Ads unlimited selamanya**.

Setelah masa aktif reward habis → **iklan muncul lagi**, user mengulang loop dari awal.

---

## 2. Katalog Model

Total **8 model** yang di-monetisasi (di luar model free default):

| # | Model ID                                    | Tier Unlock         |
|---|---------------------------------------------|---------------------|
| 1 | `google/gemma-4-31b-it`                     | Streak 3 hari       |
| 2 | `minimaxai/minimax-m2.7`                    | Streak 3 hari       |
| 3 | `meta/llama-guard-4-12b`                    | Streak 3 hari       |
| 4 | `bytedance/seed-oss-36b-instruct`           | Streak 7 hari       |
| 5 | `mistralai/mistral-small-4-119b-2603`       | Streak 7 hari       |
| 6 | `moonshotai/kimi-k2.6`                      | Streak 12 hari      |
| 7 | `deepseek-ai/deepseek-v4-pro`               | Streak 12 hari      |
| 8 | `abacusai/dracarys-llama-3.1-70b-instruct`  | Streak 12 hari (NVIDIA Nemotron tier) |

> Catatan: label "nvidia nemotron" di draft owner dipetakan ke slot tier-12 hari
> (bundle bareng Kimi & DeepSeek).

---

## 3. Aturan Reward (Retention Loop)

### 3.1 Tier 1 — Login 3 Hari Berturut-turut
- **Unlock:** `minimax-m2.7`, `llama-guard-4-12b`, `gemma-4-31b-it`
- **Durasi No-Ads:** **7 hari (1 minggu)** untuk 3 model tersebut
- **Trigger:** `streak_count == 3` (check-in hari ke-3)

### 3.2 Tier 2 — Login 7 Hari Berturut-turut
- **Unlock:** `seed-oss-36b-instruct`, `mistral-small-4-119b-2603`
- **Durasi No-Ads:** **7 hari**
- **Trigger:** `streak_count == 7`

### 3.3 Tier 3 — Login 12 Hari Berturut-turut
- **Unlock:** `kimi-k2.6`, `deepseek-v4-pro`, NVIDIA Nemotron (`dracarys-llama-3.1-70b`)
- **Durasi No-Ads:** **14 hari**
- **Trigger:** `streak_count == 12`

### 3.4 Bonus Loyalitas — 30 Hari + 50 Chat/hari
- **Syarat:** login **30 hari berturut-turut** **DAN** min. **50 chat per hari**
  di setiap hari dalam streak (tidak boleh ada hari yang < 50 chat).
- **Reward:** **No-Ads 30 hari** untuk **semua model** di katalog.
- **Trigger:** `streak_count == 30 && min(daily_chat_count[last30]) >= 50`

### 3.5 Reset Rule
- Skip 1 hari check-in → `streak_count = 0`, semua reward aktif **tetap jalan
  sampai masa aktif habis**, tapi progress tier baru mulai dari 0 lagi.
- Reward expired → flag `no_ads_*` dicabut → iklan aktif kembali.

---

## 4. Free Unlimited No-Ads (Creator Mission)

Jalur "endgame" — user bisa dapat **No-Ads selamanya** (unlimited, semua model)
dengan syarat konten sosial media:

| Item                    | Nilai Minimum                        |
|-------------------------|--------------------------------------|
| Platform                | TikTok **atau** Instagram **atau** Facebook |
| Views (verified)        | **≥ 6.000**                          |
| Retensi rata-rata       | **≥ 1 menit**                        |
| Bukti                   | Link video + screenshot analytics    |
| Review                  | Manual oleh admin (Admin Dashboard)  |

- Approve → set `no_ads_forever = true` di `users/{uid}`.
- Reject → notifikasi + user boleh submit ulang link berbeda.
- **Anti-abuse:** 1 link = 1x klaim (hash URL sudah unik di `creator_submissions`).

---

## 5. Alur Loop (Diagram)

Lihat file `diagrams/monetize-flow.mmd` untuk diagram Mermaid interaktif.

Ringkasan alur:

```
User baru → default free (ads ON, cuma model gratis)
     │
     ▼
Login harian ─► streak 3 ─► unlock tier-1 (7 hari No-Ads)
     │              │
     │              ▼
     │         streak 7 ─► unlock tier-2 (7 hari No-Ads)
     │              │
     │              ▼
     │         streak 12 ─► unlock tier-3 (14 hari No-Ads)
     │              │
     │              ▼
     │         streak 30 & 50 chat/hari ─► bonus 30 hari No-Ads semua model
     │
     ▼
Creator mission ─► views ≥ 6000 & retensi ≥ 1 menit ─► No-Ads UNLIMITED
     │
     ▼
Reward habis ─► ads aktif lagi ─► ulangi loop dari awal
```

---

## 6. Skema Data (Firestore)

Extend dokumen `users/{uid}` dengan field entitlement per-tier:

```json
{
  "streak_count": 0,
  "streak_last_date": "2026-07-04",
  "daily_chat_count": { "2026-07-04": 12, "2026-07-03": 55 },
  "no_ads_tier1_expires_at": "2026-07-11T00:00:00Z",
  "no_ads_tier2_expires_at": null,
  "no_ads_tier3_expires_at": null,
  "no_ads_bonus_expires_at": null,
  "no_ads_forever": false,
  "creator_reward_claimed": false
}
```

Helper Dart:

```dart
bool isModelNoAds(String modelId, UserEntitlements ent) {
  if (ent.noAdsForever) return true;
  if (ent.noAdsBonusExpiresAt?.isAfter(DateTime.now()) ?? false) return true;
  final tier = _tierOfModel(modelId); // 1 | 2 | 3
  return ent.tierExpiresAt(tier)?.isAfter(DateTime.now()) ?? false;
}
```

---

## 7. Enforcement Iklan

- Sebelum kirim pesan ke model X → cek `isModelNoAds(X, ent)`.
- Kalau **false** → tampilkan **rewarded ad** (AdMob), lanjut request setelah `onEarned`.
- Kalau **true** → langsung streaming tanpa iklan.
- Model **free default** (`claude-4-6-haiku` / setara) tetap **selalu no-ads** —
  tidak masuk tier apa pun.

---

## 8. Anti-Abuse Checklist

- [x] Streak dihitung per **tanggal lokal** (bukan 24h rolling) → tidak bisa
      "double check-in".
- [x] `daily_chat_count` di-track server-side (Firestore rules block client
      write ke field ini).
- [x] Creator submission: 1 URL = 1 klaim (unique index).
- [x] Reward expiry di-server-timestamp (bukan client clock).
- [x] Bonus 30-hari cek **semua** 30 hari punya ≥ 50 chat (bukan rata-rata).

---

## 9. Milestone Rilis

| Milestone | Scope                                                          |
|-----------|----------------------------------------------------------------|
| M-A       | Skema data + entitlement engine + gating tier 1                |
| M-B       | Tier 2 & 3 + expiry cron                                       |
| M-C       | Bonus 30-hari + tracker `daily_chat_count`                     |
| M-D       | Integrasi AdMob rewarded ad + gating enforcement               |
| M-E       | Creator mission Unlimited (extend `creator_submissions` M19)   |

---

**End of Rancangan Monetize System — KiKai**
