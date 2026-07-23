# Skills (M37)

Skills adalah kemampuan stateless yang dijalankan backend NVIDIA proxy
(`nvidia-out/nvidia-api`) secara on-demand setiap ada request chat. Tidak
ada database, tidak ada API key tambahan, dan tidak perlu server nyala 24/7.

## Backend

- `nvidia-out/nvidia-api/lib/skills.js` — registry & implementasi skill.
- `nvidia-out/nvidia-api/api/skills.js` — `GET /api/skills` (discovery).
- `nvidia-out/nvidia-api/api/chat.js` — integrasi skill di `/api/chat`.

### Skill yang tersedia

| Skill | Trigger contoh | Sumber data |
|---|---|---|
| `datetime` | "jam berapa", "tanggal berapa" | Server clock (Asia/Jakarta) |
| `calculator` | "berapa 12 * 5", "hitung" | Ekspresi matematika aman |
| `url_fetch` | pesan mengandung `http://...` | Fetch URL + strip HTML |
| `wikipedia` | "apa itu X", "siapa Y" | Wikipedia REST API |
| `web_search` | "cari", "info terbaru" | DuckDuckGo public API |

### Request body

Tambahkan field `skills` di body `/api/chat`:

```json
{
  "model": "nvidia-ultra",
  "messages": [...],
  "skills": { "auto": true, "enabled": ["datetime", "calculator"] }
}
```

- `auto` — deteksi otomatis berdasarkan isi pesan user.
- `enabled` — daftar skill yang selalu diaktifkan (selain auto).

### SSE event

Event tambahan yang dikirim di awal stream:

```text
data: {"type":"skills","skills":[{"name":"datetime","status":"ok"}]}
```

## Flutter

- `out/lib/services/skills_service.dart` — pengaturan & payload builder.
- `out/lib/services/nvidia_client_service.dart` — menerima event `skills`
  dan meneruskan `skillsOptions` ke backend.
- `out/lib/services/ai_client_service.dart` — auto-wire `SkillsService`
  untuk semua request NVIDIA.

### Penggunaan UI

```dart
final skills = await SkillsService.instance.fetchAvailableSkills();
SkillsService.instance.setAuto(true);
SkillsService.instance.toggle('web_search', true);
```

`AiClientService.instance.streamMessage(...)` otomatis mengirim opsi skill
terkini ke backend tanpa perubahan di controller/chat UI.
