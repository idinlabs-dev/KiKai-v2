import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

/// M38 — Layer client untuk backend web tools KiKai:
///   - `POST {webBackendBase}/read-url` → Jina Reader proxy (FASE 1).
///   - `POST {webBackendBase}/search`   → DuckDuckGo search (FASE 2).
///
/// Semua request punya timeout keras + fallback error handling supaya
/// chat flow gak pernah nge-hang gara-gara web lemot (FASE 3).
class WebToolsService {
  WebToolsService._();
  static final WebToolsService instance = WebToolsService._();

  static const Duration _timeout = Duration(seconds: 12);

  // Regex URL: mencakup http(s):// dan www. prefix.
  static final RegExp _urlRegex = RegExp(
    r'((?:https?://|www\.)[^\s<>"' r"'" r']+)',
    caseSensitive: false,
  );

  /// Ekstrak semua URL dari teks user. Trim trailing punctuation umum.
  static List<String> extractUrls(String text) {
    final matches = _urlRegex.allMatches(text);
    final out = <String>[];
    for (final m in matches) {
      var u = m.group(1) ?? '';
      // Trim trailing punctuation yg biasanya bukan bagian URL.
      while (u.isNotEmpty && '.,);]!?»"\''.contains(u[u.length - 1])) {
        u = u.substring(0, u.length - 1);
      }
      if (u.isEmpty) continue;
      if (!u.toLowerCase().startsWith('http')) u = 'https://$u';
      if (!out.contains(u)) out.add(u);
    }
    return out;
  }

  /// FASE 1 — baca 1 URL, balikin { title, content } yg sudah bersih.
  Future<ReadUrlResult> readUrl(String url, {bool force = false}) async {
    final endpoint = Uri.parse(AppConfig.webBackendBase + '/read-url');
    try {
      final res = await http
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url, 'force': force}),
          )
          .timeout(_timeout);
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = decoded['ok'] == true && res.statusCode == 200;
      return ReadUrlResult(
        ok: ok,
        url: (decoded['url'] ?? url) as String,
        title: (decoded['title'] as String?) ?? '',
        content: (decoded['content'] as String?) ?? '',
        error: ok ? null : (decoded['error'] as String? ?? 'unknown_error'),
        cached: decoded['cached'] == true,
      );
    } on TimeoutException {
      return ReadUrlResult(ok: false, url: url, title: '', content: '', error: 'timeout');
    } catch (e) {
      return ReadUrlResult(ok: false, url: url, title: '', content: '', error: e.toString());
    }
  }

  /// FASE 2 — search DDG top-K.
  Future<SearchResult> search(String query, {int topK = 5}) async {
    final endpoint = Uri.parse(AppConfig.webBackendBase + '/search');
    try {
      final res = await http
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'q': query, 'top_k': topK}),
          )
          .timeout(_timeout);
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = decoded['ok'] == true && res.statusCode == 200;
      final rawList = (decoded['results'] as List?) ?? const [];
      final list = rawList
          .whereType<Map>()
          .map((e) => SearchHit(
                title: (e['title'] ?? '').toString(),
                url: (e['url'] ?? '').toString(),
                snippet: (e['snippet'] ?? '').toString(),
              ))
          .where((h) => h.url.isNotEmpty)
          .toList();
      return SearchResult(
        ok: ok,
        query: query,
        results: list,
        error: ok ? null : (decoded['error'] as String? ?? 'unknown_error'),
      );
    } on TimeoutException {
      return SearchResult(ok: false, query: query, results: const [], error: 'timeout');
    } catch (e) {
      return SearchResult(ok: false, query: query, results: const [], error: e.toString());
    }
  }

  /// FASE 2 — search → auto baca top-N link → gabung jadi context.
  /// Return context markdown yang siap di-prepend ke prompt user.
  Future<WebSearchContext> searchAndRead(
    String query, {
    int topK = 5,
    int readTop = 3,
  }) async {
    final s = await search(query, topK: topK);
    if (!s.ok || s.results.isEmpty) {
      return WebSearchContext(
        query: query,
        hits: const [],
        articles: const [],
        error: s.error ?? 'no_results',
      );
    }

    final subset = s.results.take(readTop).toList();
    // Baca paralel supaya cepet. Skip yg gagal / timeout.
    final reads = await Future.wait(
      subset.map((h) => readUrl(h.url)),
      eagerError: false,
    );
    final articles = <ReadUrlResult>[];
    for (var i = 0; i < reads.length; i++) {
      final r = reads[i];
      if (r.ok && r.content.trim().isNotEmpty) {
        articles.add(r);
      }
    }
    return WebSearchContext(
      query: query,
      hits: s.results,
      articles: articles,
      error: articles.isEmpty ? 'all_reads_failed' : null,
    );
  }
}

// ── Result types ──────────────────────────────────────────────────────

class ReadUrlResult {
  final bool ok;
  final String url;
  final String title;
  final String content;
  final String? error;
  final bool cached;

  const ReadUrlResult({
    required this.ok,
    required this.url,
    required this.title,
    required this.content,
    this.error,
    this.cached = false,
  });
}

class SearchHit {
  final String title;
  final String url;
  final String snippet;
  const SearchHit({required this.title, required this.url, required this.snippet});
}

class SearchResult {
  final bool ok;
  final String query;
  final List<SearchHit> results;
  final String? error;
  const SearchResult({
    required this.ok,
    required this.query,
    required this.results,
    this.error,
  });
}

class WebSearchContext {
  final String query;
  final List<SearchHit> hits;
  final List<ReadUrlResult> articles;
  final String? error;

  const WebSearchContext({
    required this.query,
    required this.hits,
    required this.articles,
    this.error,
  });

  bool get hasContent => articles.isNotEmpty;

  /// Buat blok markdown untuk di-inject sebagai konteks ke LLM.
  String toPromptContext() {
    if (articles.isEmpty && hits.isEmpty) return '';
    final b = StringBuffer();
    b.writeln('=== HASIL PENCARIAN WEB (KiKai auto-search) ===');
    b.writeln('Query: $query');
    b.writeln('');
    for (var i = 0; i < articles.length; i++) {
      final a = articles[i];
      b.writeln('[Sumber ${i + 1}] ${a.title}');
      b.writeln('URL: ${a.url}');
      b.writeln('---');
      b.writeln(a.content);
      b.writeln('');
      b.writeln('=======================================');
      b.writeln('');
    }
    if (hits.isNotEmpty) {
      b.writeln('Daftar link lain yang muncul di hasil search:');
      for (final h in hits) {
        b.writeln('- ${h.title} — ${h.url}');
      }
      b.writeln('');
    }
    b.writeln('INSTRUKSI: Jawab pertanyaan user berdasarkan sumber di atas. '
        'WAJIB cantumkan sitasi berupa nomor sumber (mis. [1], [2]) di kalimat '
        'yang mengutip, DAN di akhir jawaban tampilkan daftar "Sumber:" berisi '
        'URL lengkap. Kalau info tidak cukup, bilang jujur.');
    b.writeln('=== END HASIL PENCARIAN ===');
    return b.toString();
  }
}

/// Helper builder untuk konteks 1 URL (FASE 1).
String buildSingleUrlContext(ReadUrlResult r) {
  if (!r.ok) return '';
  final b = StringBuffer();
  b.writeln('=== KONTEN URL (KiKai auto-read) ===');
  b.writeln('Judul: ${r.title}');
  b.writeln('URL: ${r.url}');
  b.writeln('---');
  b.writeln(r.content);
  b.writeln('=== END KONTEN URL ===');
  b.writeln('');
  b.writeln('INSTRUKSI: Rangkum / jawab pertanyaan user berdasarkan isi URL '
      'di atas. Kalau user tanya di luar konteks, jawab normal saja. '
      'Cantumkan URL sumber di akhir jawaban.');
  return b.toString();
}
