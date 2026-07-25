import '../../services/skills_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';



import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/ai_models.dart';
import '../../core/constants/app_config.dart';
import '../../models/ai_model.dart';
import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';
import '../../services/ai_client_service.dart';
import '../../services/ads_service.dart';
import '../../services/history_service.dart';
import '../../services/vision_client_service.dart';
import '../../services/web_tools_service.dart';

/// Chat controller M2: persist thread & messages ke sqflite via
/// [HistoryService]. Menyimpan state thread aktif + daftar semua thread
/// (untuk sidebar), auto-title dari pesan pertama user, dan operasi
/// rename/pin/delete.
class ChatController extends ChangeNotifier {
  ChatController({HistoryService? history})
      : _history = history ?? HistoryService.instance {
    _model = findModelById(AppConfig.defaultModelId) ?? kDefaultFreeModel;
  }

  static final _uuid = Uuid();
  final HistoryService _history;

  // ── State thread aktif ────────────────────────────────────────────────
  ChatThread? _current; // null = draft (belum di-persist ke DB)
  final List<ChatMessage> _messages = [];
  late AiModel _model;

  // ── State list thread (sidebar) ───────────────────────────────────────
  List<ChatThread> _threads = const [];
  bool _threadsLoading = false;

  // ── State streaming ───────────────────────────────────────────────────
  bool _isSending = false;
  String? _error;
  StreamSubscription<String>? _sub;

  // ── Getters ───────────────────────────────────────────────────────────
  ChatThread? get currentThread => _current;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatThread> get threads => List.unmodifiable(_threads);
  bool get threadsLoading => _threadsLoading;
  bool get isSending => _isSending;
  bool get isEmpty => _messages.isEmpty;
  String? get error => _error;
  AiModel get model => _model;

  // ── M38 — Web tools (URL read + web search) ──────────────────────────
  bool _webSearchEnabled = false;
  String? _webStatus; // ex: "KiKai lagi googling..."
  final List<WebCitation> _lastCitations = [];

  bool get webSearchEnabled => _webSearchEnabled;
  String? get webStatus => _webStatus;
  List<WebCitation> get lastCitations => List.unmodifiable(_lastCitations);

  void setWebSearchEnabled(bool v) {
    if (_webSearchEnabled == v) return;
    _webSearchEnabled = v;
    notifyListeners();
  }

  void toggleWebSearch() => setWebSearchEnabled(!_webSearchEnabled);

  void _setWebStatus(String? msg) {
    _webStatus = msg;
    notifyListeners();
  }

  // ── Init ──────────────────────────────────────────────────────────────

  /// Panggil di `initState`. Load list thread; auto-open thread paling
  /// baru kalau ada, kalau tidak biarkan draft kosong.
  Future<void> loadInitial() async {
    await refreshThreads();
    if (_threads.isNotEmpty) {
      await openThread(_threads.first.id);
    }
  }

  Future<void> refreshThreads() async {
    _threadsLoading = true;
    notifyListeners();
    try {
      _threads = await _history.listThreads();
    } finally {
      _threadsLoading = false;
      notifyListeners();
    }
  }

  // ── Operasi thread ────────────────────────────────────────────────────

  Future<void> openThread(String id) async {
    if (_isSending) await stopGenerating();
    final t = await _history.getThread(id);
    if (t == null) return;
    _current = t;
    _messages
      ..clear()
      ..addAll(await _history.listMessages(id));
    final m = findModelById(t.modelId);
    if (m != null) _model = m;
    _error = null;
    notifyListeners();
  }

  /// Buka draft baru (belum di-persist sampai user kirim pesan pertama).
  Future<void> newDraft() async {
    if (_isSending) await stopGenerating();
    _current = null;
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> renameThread(String id, String title) async {
    await _history.renameThread(id, title);
    if (_current?.id == id) {
      _current = _current!.copyWith(
        title: title.trim().isEmpty ? 'Percakapan baru' : title.trim(),
        updatedAt: DateTime.now(),
      );
    }
    await refreshThreads();
  }

  Future<void> togglePin(String id) async {
    final t = _threads.firstWhere(
      (e) => e.id == id,
      orElse: () => ChatThread(
        id: id,
        title: '',
        modelId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await _history.togglePin(id, !t.pinned);
    await refreshThreads();
  }

  Future<void> deleteThread(String id) async {
    await _history.deleteThread(id);
    if (_current?.id == id) {
      _current = null;
      _messages.clear();
    }
    await refreshThreads();
    // Auto pindah ke thread paling baru kalau ada.
    if (_current == null && _threads.isNotEmpty) {
      await openThread(_threads.first.id);
    }
  }

  void setModel(AiModel m) {
    _model = m;
    notifyListeners();
    // Kalau thread aktif sudah persisted, update modelId di DB.
    final c = _current;
    if (c != null) {
      unawaited(_history.upsertThread(c.copyWith(modelId: m.id)));
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // ── Kirim pesan ───────────────────────────────────────────────────────

  Future<void> sendUserMessage(String text) async {
    var trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    // ── M43 — Extract inline image blobs (from composer) ───────────────
    // Composer menyisipkan sentinel:
    //   <<<KIKAI_IMAGE_BLOB mime="image/png" data="BASE64">>>
    // Kita pisahkan supaya:
    //   - `trimmed` (visible di bubble user) bersih dari base64.
    //   - `visionImages` dipakai VisionClientService untuk request ke kie.ai.
    final visionImages = <VisionImage>[];
    // M44 — sentinel tunggal: <<<KIKAI_IMAGE mime="..." name="..." size="..." data="B64">>>
    // Kita EXTRACT bytes-nya utk dikirim ke kie.ai vision proxy, tapi TETAP
    // simpan sentinel di userMsg.content supaya message_bubble bisa render
    // thumbnail preview (mirip ChatGPT). Sentinel di-strip nanti pas build
    // LLM history (_toLlmHistory) supaya nggak nge-bloat request text-only.
    final blobRe = RegExp(
      r'<<<KIKAI_IMAGE\s+mime="([^"]+)"\s+name="[^"]*"\s+size="[^"]*"\s+data="([^"]+)">>>',
    );
    for (final m in blobRe.allMatches(trimmed)) {
      try {
        visionImages.add(VisionImage(
          mime: m.group(1)!,
          bytes: base64Decode(m.group(2)!),
        ));
      } catch (_) {}
    }
    final hasImages = visionImages.isNotEmpty;

    // ── M39 — Preprocessing web tools (bubble user tetap BERSIH) ──────
    // Hasil search / read-url tidak lagi di-inject ke `trimmed` (yang
    // ditampilkan di bubble user). Semua konteks disimpan sebagai
    // `hiddenPromptContext` di userMsg dan hanya dikirim ke LLM.
    // Sitasi ditempel ke assistantMsg.sources untuk render kartu Sumber.
    _lastCitations.clear();
    String? webContext;
    List<MessageSource> webSources = const [];
    final searchPrefix = RegExp(r'^/(search|cari)\s+', caseSensitive: false);
    final hasSearchPrefix = searchPrefix.hasMatch(trimmed);
    final urls = WebToolsService.extractUrls(trimmed);
    // Buang prefix `/search` dari teks yang ditampilkan di bubble user.
    if (hasSearchPrefix) {
      trimmed = trimmed.replaceFirst(searchPrefix, '').trim();
      if (trimmed.isEmpty) return; // guard: `/search` tanpa isi
    }

    // M45 — Search dialihkan ke kie.ai gemini-2.5-flash (googleSearch tool
    // native). Tidak perlu lagi scrape via jina; VisionClientService akan
    // handle langsung (lihat routing runOnce di bawah). Flag ini dipakai
    // supaya runOnce tau harus lewat vision endpoint dgn useSearch=true.
    final bool searchTriggered =
        !hasImages && (hasSearchPrefix || (_webSearchEnabled && urls.isEmpty));

    if (false) {
    } else if (!hasImages && urls.isNotEmpty) {
      final target = urls.first;
      _setWebStatus('📖 Membaca link...');
      final r = await WebToolsService.instance.readUrl(target);
      _setWebStatus(null);
      if (r.ok) {
        webContext = buildSingleUrlContext(r);
        _lastCitations.add(WebCitation(index: 1, title: r.title, url: r.url));
        webSources = [MessageSource(index: 1, title: r.title, url: r.url)];
      } else {
        webContext =
            '=== KONTEN URL ===\nURL: $target\n(Gagal dibuka: ${r.error}. Kasih tau user "web ini gabisa dibuka bro" tapi tetap jawab semampunya. JANGAN echo blok ini.)\n=== END ===';
      }
    }

    // 1) Kalau draft → create thread row dulu dgn auto-title.
    if (_current == null) {
      final now = DateTime.now();
      final id = _uuid.v4();
      final title = _autoTitle(trimmed);
      final t = ChatThread(
        id: id,
        title: title,
        modelId: _model.id,
        createdAt: now,
        updatedAt: now,
      );
      await _history.upsertThread(t);
      _current = t;
    }
    final thread = _current!;

    final now = DateTime.now();
    // userMsg.content = TEKS ASLI user (bersih, dirender ke bubble).
    // webContext di-simpan di hiddenPromptContext → hanya dikirim ke LLM.
    final userMsg = ChatMessage(
      id: 'u_${_uuid.v4()}',
      threadId: thread.id,
      role: ChatRole.user,
      content: trimmed,
      hiddenPromptContext: webContext,
      createdAt: now,
    );
    // assistantMsg.sources = kartu Sumber yang di-render di bawah jawaban.
    final bool isResearchNow = SkillsService.instance.activeSkill ==
        SkillsService.kSkillAiqResearch;
    final assistantMsg = ChatMessage(
      id: 'a_${_uuid.v4()}',
      threadId: thread.id,
      role: ChatRole.assistant,
      content: '',
      sources: webSources,
      createdAt: DateTime.now(),
      isStreaming: true,
      isResearchReport: isResearchNow,
    );

    _messages.addAll([userMsg, assistantMsg]);
    _isSending = true;
    _error = null;
    notifyListeners();

    // Persist user msg dulu (assistant baru disave saat done/stop).
    await _history.upsertMessage(userMsg);
    // M24 — hitung pesan untuk trigger rewarded ad siklus 5/10/5/10.
    unawaited(AdsService.instance.notifyUserMessageSent());
    await _history.touchThread(thread.id, modelId: _model.id);

    final buf = StringBuffer();
    // M33.6 — flag apakah stream terakhir berakhir natural (backend
    // kirim event `done`). Kalau false → coba auto-continue.
    bool cleanFinish = false;
    bool userStopped = false;

    // M45 — flag route: image atau search-triggered → kie.ai vision endpoint.
    final bool useVisionRoute = hasImages || searchTriggered;
    Future<void> runOnce({required List<ChatMessage> historyOverride}) async {
      cleanFinish = false;
      final completer = Completer<void>();
      // M43/44 — kalau user melampirkan gambar, route ke kie.ai vision proxy.
      // Sentinel <<<KIKAI_IMAGE ...>>> di-strip dari prompt & history supaya
      // base64 nggak double-dikirim (bytes udah lewat images param).
      // M45 — Route ke VisionClientService (kie.ai gemini-2.5-flash) untuk
      // 2 kasus: (a) user upload gambar, (b) user trigger search (prefix
      // /search atau toggle web search aktif tanpa URL). Selain itu tetap
      // pakai AiClientService biasa.
      final Stream<String> src = useVisionRoute
          ? VisionClientService.instance.streamMessage(
              prompt: _stripImageSentinels(trimmed),
              images: visionImages,
              useSearch: true,
              history: historyOverride
                  .where((m) => m.id != assistantMsg.id)
                  .map((m) => m.copyWith(
                      content: _stripImageSentinels(m.content)))
                  .toList(),
              onFinish: (clean) => cleanFinish = clean,
            )
          : AiClientService.instance.streamMessage(
              history: _toLlmHistory(historyOverride),
              model: _model,
              onFinish: (clean) => cleanFinish = clean,
            );
      _sub = src.listen(
        (chunk) {
          buf.write(chunk);
          _updateAssistant(assistantMsg.id, buf.toString(), streaming: true);
        },
        onError: (Object e, _) {
          _error = e is AiClientException ? e.message : e.toString();
          _updateAssistant(
            assistantMsg.id,
            buf.isEmpty ? '⚠️ $_error' : buf.toString(),
            streaming: false,
          );
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
      // Kalau user menekan stop, stopGenerating() sudah set _isSending=false.
      // Deteksi SEBELUM kita reset _sub sendiri.
      if (!_isSending) userStopped = true;
      await _sub?.cancel();
      _sub = null;
    }

    try {
      // Pass awal — kirim history apa adanya.
      await runOnce(
        historyOverride:
            _messages.where((m) => m.id != assistantMsg.id).toList(),
      );

      // M33.7 — auto-continue kalau stream putus di tengah (bukan `done`)
      // dan bukan karena user menekan stop / error. Ditingkatkan supaya
      // artikel super panjang & source code besar tidak pernah ke-cut:
      //   - max 10 sambungan (dulu 4)
      //   - prompt lanjutan bawa "tail anchor" 400 char terakhir
      //   - deteksi code fence terbuka → suruh model tetap di dalam fence
      //   - hasil sambungan di-strip kalau ternyata mengulang tail anchor
      const maxContinues = 10;
      var continues = 0;
      while (!useVisionRoute &&
          !cleanFinish &&
          !userStopped &&
          _error == null &&
          buf.isNotEmpty &&
          continues < maxContinues) {
        continues++;

        final currentText = buf.toString();
        final tailLen = currentText.length < 400 ? currentText.length : 400;
        final tail = currentText.substring(currentText.length - tailLen);

        // Deteksi apakah code fence (```) masih terbuka di jawaban partial.
        final fenceCount = '```'.allMatches(currentText).length;
        final insideCodeBlock = fenceCount.isOdd;

        final continueInstruction = StringBuffer()
          ..writeln('Jawaban kamu sebelumnya terputus di tengah karena batas '
              'waktu server. Lanjutkan PERSIS dari karakter terakhir tadi '
              'sampai jawaban benar-benar selesai penuh.')
          ..writeln('')
          ..writeln('ATURAN KETAT:')
          ..writeln('1. JANGAN mengulang kalimat, paragraf, atau baris kode '
              'yang sudah ada.')
          ..writeln('2. JANGAN memakai pembuka baru ("Baik", "Tentu", '
              '"Melanjutkan", "Berikut", dst).')
          ..writeln('3. JANGAN menutup lalu membuka ulang code fence '
              '(```) — sambung langsung isinya.')
          ..writeln('4. Output kamu harus bisa di-append mentah-mentah ke '
              'akhir teks di bawah tanpa mengubah maknanya.');
        if (insideCodeBlock) {
          continueInstruction
            ..writeln('5. Saat ini kamu SEDANG di dalam code block yang '
                'belum ditutup. Teruskan menulis kode dulu, lalu tutup '
                'dengan ``` di akhir setelah kode selesai.');
        }
        continueInstruction
          ..writeln('')
          ..writeln('=== 400 KARAKTER TERAKHIR JAWABAN KAMU ===')
          ..writeln(tail)
          ..writeln('=== SAMBUNG DARI SINI ===');

        final baseHistory =
            _messages.where((m) => m.id != assistantMsg.id).toList();
        final partialAssistant = ChatMessage(
          id: 'a_partial_${_uuid.v4()}',
          threadId: thread.id,
          role: ChatRole.assistant,
          content: currentText,
          createdAt: DateTime.now(),
        );
        final continueUser = ChatMessage(
          id: 'u_cont_${_uuid.v4()}',
          threadId: thread.id,
          role: ChatRole.user,
          content: continueInstruction.toString(),
          createdAt: DateTime.now(),
        );

        // Tandai posisi awal sambungan supaya bisa dibersihkan kalau
        // model malah mengulang tail anchor.
        final beforeLen = buf.length;
        await runOnce(
          historyOverride: [...baseHistory, partialAssistant, continueUser],
        );
        _dedupeContinuation(buf, beforeLen, tail);
        _updateAssistant(assistantMsg.id, buf.toString(), streaming: true);
      }

      // Finalize
      final finalText = buf.toString().trim();
      _updateAssistant(
        assistantMsg.id,
        finalText.isEmpty ? '(Respons kosong dari server.)' : finalText,
        streaming: false,
      );
    } finally {
      await _sub?.cancel();
      _sub = null;
      _isSending = false;
      // Persist assistant final + touch thread.
      final idx = _messages.indexWhere((m) => m.id == assistantMsg.id);
      if (idx != -1) {
        await _history.upsertMessage(_messages[idx]);
      }
      await _history.touchThread(thread.id);
      await refreshThreads();
      notifyListeners();

      // M40 — generate follow-up suggestion chips (background, non-blocking).
      // Skip kalau user menekan stop atau ada error.
      if (!userStopped && _error == null) {
        unawaited(_generateFollowUps(
          assistantId: assistantMsg.id,
          userQuestion: trimmed,
        ));
      }
    }
  }

  /// M40 — Generate 3 follow-up questions berdasarkan Q&A terakhir.
  /// Panggilan singkat ke LLM (non-streaming collect) — kalau gagal
  /// atau parse error, chip tidak dimunculkan (silent-fail).
  Future<void> _generateFollowUps({
    required String assistantId,
    required String userQuestion,
  }) async {
    final idx = _messages.indexWhere((m) => m.id == assistantId);
    if (idx == -1) return;
    final assistant = _messages[idx];
    final answer = assistant.content.trim();
    if (answer.length < 40) return; // terlalu singkat → skip

    // Ringkas jawaban supaya prompt tidak kepanjangan.
    final answerSnippet = answer.length > 1200
        ? '${answer.substring(0, 1200)}...'
        : answer;

    final prompt = '''
Kamu adalah generator SARAN PERTANYAAN LANJUTAN untuk sebuah aplikasi chat AI.
Peran kamu di sini BUKAN menjawab dan BUKAN menyapa. Tugasmu HANYA
membuat 3 kalimat pertanyaan yang WAJAR DIUCAPKAN USER kepada AI sebagai
tindak lanjut dari jawaban di bawah — yaitu pertanyaan yang meminta AI
menjelaskan / memperluas / membandingkan / memberi contoh terkait topik
yang sedang dibahas.

Aturan WAJIB:
- Setiap item adalah pertanyaan dari sudut pandang USER kepada AI.
- Diakhiri tanda tanya "?".
- Maksimal 10 kata per pertanyaan, singkat & natural.
- Ikuti bahasa yang dipakai user (Indonesia / gaul / Inggris).
- JANGAN pakai kalimat sapaan atau tawaran bantuan dari sisi AI
  (contoh DILARANG: "Ada yang bisa saya bantu?", "Mau lanjut ke topik apa?",
  "Kamu mau saya buatkan…?", "Ada yang ingin ditanyakan lagi?").
- JANGAN mengulang persis pertanyaan user sebelumnya.
- Ketiga pertanyaan harus BERVARIASI sudut pandang (mis. detail teknis,
  contoh nyata, perbandingan, konsekuensi, langkah berikutnya).

Output HANYA JSON array of string, TANPA penjelasan / markdown / prefix.
Format persis: ["...?", "...?", "...?"]

=== Pertanyaan user sebelumnya ===
$userQuestion

=== Jawaban AI ===
$answerSnippet

JSON:''';

    final syntheticUser = ChatMessage(
      id: 'fu_${_uuid.v4()}',
      threadId: assistant.threadId,
      role: ChatRole.user,
      content: prompt,
      createdAt: DateTime.now(),
    );

    final buf = StringBuffer();
    try {
      await AiClientService.instance
          .streamMessage(
            history: [syntheticUser],
            model: _model,
          )
          .listen(buf.write)
          .asFuture<void>();
    } catch (_) {
      return;
    }

    final raw = buf.toString().trim();
    if (raw.isEmpty) return;

    final parsed = _parseFollowUpsJson(raw);
    if (parsed.isEmpty) return;

    // Pastikan pesan masih ada (thread bisa saja sudah dihapus / di-switch).
    final freshIdx = _messages.indexWhere((m) => m.id == assistantId);
    if (freshIdx == -1) return;
    _messages[freshIdx] = _messages[freshIdx].copyWith(followUps: parsed);
    notifyListeners();
    await _history.upsertMessage(_messages[freshIdx]);
  }

  /// Ekstrak JSON array pertama dari string bebas + parse ke List<String>.
  /// Toleran terhadap fence ```json, prefix, atau trailing junk.
  List<String> _parseFollowUpsJson(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    final slice = raw.substring(start, end + 1);
    try {
      final decoded = jsonDecode(slice);
      if (decoded is! List) return const [];
      final list = decoded
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length <= 120)
          .toList();
      if (list.length < 2) return const [];
      // Cap ke 3 chip supaya UI tetap rapi.
      return list.take(3).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> stopGenerating() async {
    await _sub?.cancel();
    _sub = null;
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      if (last.role == ChatRole.assistant && last.isStreaming) {
        _updateAssistant(
          last.id,
          last.content.isEmpty ? '(Dihentikan.)' : last.content,
          streaming: false,
        );
        await _history.upsertMessage(_messages.last);
      }
    }
    _isSending = false;
    notifyListeners();
  }

  /// Reset percakapan sekarang. Kalau thread sudah tersimpan → tetap ada
  /// di DB (bisa dibuka lagi dari sidebar); hanya bikin draft baru.
  void resetThread() {
    unawaited(newDraft());
  }

  /// M39 — Transform history sebelum dikirim ke LLM:
  /// untuk pesan yang punya `hiddenPromptContext`, gabungkan sebagai
  /// content efektif (context + "\nPertanyaan user:\n" + teks asli).
  /// Pesan tanpa hiddenPromptContext dilewatkan apa adanya.
  List<ChatMessage> _toLlmHistory(List<ChatMessage> src) {
    return src.map((m) {
      final ctx = m.hiddenPromptContext;
      final cleaned = _stripImageSentinels(m.content);
      if (ctx == null || ctx.isEmpty) {
        return cleaned == m.content ? m : m.copyWith(content: cleaned);
      }
      return m.copyWith(
        content: ctx + '\n\nPertanyaan user:\n' + cleaned,
        clearHiddenPromptContext: true,
      );
    }).toList();
  }

  /// M44 — Buang sentinel `<<<KIKAI_IMAGE ... data="...">>>` (base64 bisa
  /// ratusan KB) dari content sebelum dikirim ke LLM text-only atau
  /// dipakai sebagai history di vision request.
  static final RegExp _imageSentinelRe = RegExp(
    r'<<<KIKAI_IMAGE\s+mime="[^"]+"\s+name="[^"]*"\s+size="[^"]*"\s+data="[^"]+">>>',
  );
  String _stripImageSentinels(String s) {
    return s.replaceAll(_imageSentinelRe, '[gambar]').trim();
  }

  void _updateAssistant(String id, String content, {required bool streaming}) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(
      content: content,
      isStreaming: streaming,
    );
    notifyListeners();
  }

  /// M33.7 — bersihkan sambungan supaya tidak double-print bagian akhir
  /// jawaban lama. Kalau model malah mengulang tail anchor (mis. seluruh
  /// paragraf terakhir / beberapa baris kode terakhir), potong prefix
  /// duplikatnya sebelum di-append.
  void _dedupeContinuation(StringBuffer buf, int beforeLen, String tail) {
    if (buf.length <= beforeLen) return;
    final added = buf.toString().substring(beforeLen);
    if (added.isEmpty || tail.isEmpty) return;

    // Cari overlap maksimal antara akhir `tail` dan awal `added`
    // (mengulang mundur dari panjang tail).
    final maxOverlap = tail.length < added.length ? tail.length : added.length;
    var overlap = 0;
    for (var n = maxOverlap; n >= 8; n--) {
      if (added.startsWith(tail.substring(tail.length - n))) {
        overlap = n;
        break;
      }
    }
    if (overlap == 0) return;

    final cleaned = added.substring(overlap);
    final rebuilt = buf.toString().substring(0, beforeLen) + cleaned;
    buf
      ..clear()
      ..write(rebuilt);
  }

  String _autoTitle(String firstMessage) {
    // Ambil baris pertama, potong 40 char, trim trailing punctuation.
    final firstLine = firstMessage.split('\n').first.trim();
    if (firstLine.length <= 40) return firstLine;
    return '${firstLine.substring(0, 40).trimRight()}…';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// M38 — Sitasi hasil web search / URL read.
class WebCitation {
  final int index;
  final String title;
  final String url;
  const WebCitation({required this.index, required this.title, required this.url});
}
