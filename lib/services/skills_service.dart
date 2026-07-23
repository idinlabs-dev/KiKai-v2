import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M38 — Skill Selector (single-active).
///
/// Menggantikan model multi-select M37. Sekarang user memilih SATU skill
/// aktif dari selector (mirip Gemini "Deep Research"):
///
///   - `none`           : Default, tanpa skill tambahan.
///   - `aiq_research`   : DeepResearch (NVIDIA AIQ style, mirip Gemini).
///   - `nemo_retriever` : Riset Cepat (NVIDIA NeMo Retriever style).
///
/// Backend `/api/chat` menerima `skills: { auto: false, enabled: [name] }`
/// atau `{ auto: false, enabled: [] }` untuk default.
class SkillsService {
  SkillsService._();
  static final SkillsService instance = SkillsService._();

  static const String kSkillNone = 'none';
  static const String kSkillAiqResearch = 'aiq_research';
  static const String kSkillNemoRetriever = 'nemo_retriever';

  static const String _prefsActiveKey = 'kikai_active_skill';

  /// Katalog skill yang tampil di selector. Urut sesuai UI (Default paling
  /// bawah supaya dua skill kuat lebih menonjol, mirip layout Gemini).
  static const List<SkillOption> catalog = [
    SkillOption(
      id: kSkillAiqResearch,
      label: 'DeepResearch',
      subtitle: 'Laporan mendalam multi-sumber (mirip Gemini)',
      icon: Icons.hub_rounded,
    ),
    SkillOption(
      id: kSkillNemoRetriever,
      label: 'Riset Cepat',
      subtitle: 'Retriever multi-sumber instan untuk grounding',
      icon: Icons.travel_explore_rounded,
    ),
    SkillOption(
      id: kSkillNone,
      label: 'Default',
      subtitle: 'Tanpa skill — jawaban murni dari model',
      icon: Icons.bolt_rounded,
    ),
  ];

  String _active = kSkillNone;
  bool _loaded = false;

  String get activeSkill => _active;
  bool get isDefault => _active == kSkillNone;

  SkillOption get activeOption =>
      catalog.firstWhere((s) => s.id == _active, orElse: () => catalog.last);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsActiveKey);
    if (saved != null && catalog.any((s) => s.id == saved)) {
      _active = saved;
    }
    _loaded = true;
  }

  Future<void> setActive(String id) async {
    if (!catalog.any((s) => s.id == id)) return;
    _active = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActiveKey, id);
  }

  /// Payload untuk `/api/chat`. Skill selector M38 selalu `auto: false`
  /// supaya backend tidak menembak skill lama (datetime/kalkulator/dll)
  /// otomatis — biar mode "Default" benar-benar bersih.
  Map<String, dynamic> buildOptions() => {
        'auto': false,
        'enabled': _active == kSkillNone ? const <String>[] : [_active],
      };
}

class SkillOption {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  const SkillOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}
