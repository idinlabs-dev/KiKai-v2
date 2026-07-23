import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';

/// Persistensi lokal thread & message via sqflite.
///
/// v2 (M39): tambah kolom `hiddenPromptContext` & `sources` ke tabel
/// messages supaya konteks web search bisa disimpan tapi tidak di-render
/// ke UI, dan sitasi tetap muncul saat thread di-reload.
///
/// v3 (M40): tambah kolom `followUps` untuk menyimpan chips saran
/// pertanyaan lanjutan mirip ChatGPT.
class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  static const int _dbVersion = 4;

  Database? _db;
  Completer<Database>? _opening;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!.future;
    _opening = Completer<Database>();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'claude48.db');
      final db = await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE threads(
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              modelId TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL,
              pinned INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE messages(
              id TEXT PRIMARY KEY,
              threadId TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              hiddenPromptContext TEXT,
              sources TEXT NOT NULL DEFAULT '[]',
              followUps TEXT NOT NULL DEFAULT '[]',
              isResearchReport INTEGER NOT NULL DEFAULT 0,
              attachments TEXT NOT NULL DEFAULT '[]',
              createdAt TEXT NOT NULL,
              FOREIGN KEY (threadId) REFERENCES threads(id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_msg_thread ON messages(threadId, createdAt)');
        },
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) {
            // Tambah kolom baru untuk M39. `ALTER TABLE ADD COLUMN` idempotent-safe
            // via try/catch supaya migrasi ganda tidak crash.
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN hiddenPromptContext TEXT');
            } catch (_) {}
            try {
              await db.execute(
                  "ALTER TABLE messages ADD COLUMN sources TEXT NOT NULL DEFAULT '[]'");
            } catch (_) {
              // Beberapa versi sqlite tidak izinkan NOT NULL DEFAULT saat ALTER.
              // Fallback: kolom nullable.
              try {
                await db.execute(
                    'ALTER TABLE messages ADD COLUMN sources TEXT');
              } catch (_) {}
            }
          }
          if (oldV < 3) {
            // M40 — kolom followUps untuk chips saran pertanyaan lanjutan.
            try {
              await db.execute(
                  "ALTER TABLE messages ADD COLUMN followUps TEXT NOT NULL DEFAULT '[]'");
            } catch (_) {
              try {
                await db.execute(
                    'ALTER TABLE messages ADD COLUMN followUps TEXT');
              } catch (_) {}
            }
          }
          if (oldV < 4) {
            // M41 — flag isResearchReport supaya kartu DeepResearch tetap
            // muncul saat thread di-reload dari history.
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN isResearchReport INTEGER NOT NULL DEFAULT 0');
            } catch (_) {
              try {
                await db.execute(
                    'ALTER TABLE messages ADD COLUMN isResearchReport INTEGER');
              } catch (_) {}
            }
          }
        },
      );
      _db = db;
      _opening!.complete(db);
      return db;
    } catch (e, st) {
      _opening!.completeError(e, st);
      _opening = null;
      rethrow;
    }
  }

  // ── Threads ──────────────────────────────────────────────────────────────

  Future<List<ChatThread>> listThreads() async {
    final db = await _open();
    final rows = await db.query(
      'threads',
      orderBy: 'pinned DESC, datetime(updatedAt) DESC',
    );
    return rows.map(ChatThread.fromMap).toList();
  }

  Future<ChatThread?> getThread(String id) async {
    final db = await _open();
    final rows = await db.query('threads', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ChatThread.fromMap(rows.first);
  }

  Future<void> upsertThread(ChatThread t) async {
    final db = await _open();
    await db.insert(
      'threads',
      t.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> renameThread(String id, String title) async {
    final db = await _open();
    await db.update(
      'threads',
      {
        'title': title.trim().isEmpty ? 'Percakapan baru' : title.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> togglePin(String id, bool pinned) async {
    final db = await _open();
    await db.update(
      'threads',
      {'pinned': pinned ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> touchThread(String id, {String? modelId}) async {
    final db = await _open();
    await db.update(
      'threads',
      {
        'updatedAt': DateTime.now().toIso8601String(),
        if (modelId != null) 'modelId': modelId,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteThread(String id) async {
    final db = await _open();
    await db.delete('messages', where: 'threadId=?', whereArgs: [id]);
    await db.delete('threads', where: 'id=?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.delete('messages');
    await db.delete('threads');
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> listMessages(String threadId) async {
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'threadId=?',
      whereArgs: [threadId],
      orderBy: 'datetime(createdAt) ASC',
    );
    return rows.map(_messageFromRow).toList();
  }

  Future<void> upsertMessage(ChatMessage m) async {
    final db = await _open();
    await db.insert(
      'messages',
      {
        'id': m.id,
        'threadId': m.threadId,
        'role': m.role.name,
        'content': m.content,
        'hiddenPromptContext': m.hiddenPromptContext,
        'sources': jsonEncode(m.sources.map((s) => s.toMap()).toList()),
        'followUps': jsonEncode(m.followUps),
        'attachments': jsonEncode(m.attachments.map((a) => a.toMap()).toList()),
        'createdAt': m.createdAt.toIso8601String(),
        'isResearchReport': m.isResearchReport ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await _open();
    await db.delete('messages', where: 'id=?', whereArgs: [id]);
  }

  ChatMessage _messageFromRow(Map<String, dynamic> r) {
    final attachRaw = r['attachments'] as String? ?? '[]';
    List<Attachment> atts = const [];
    try {
      final decoded = jsonDecode(attachRaw);
      if (decoded is List) {
        atts = decoded
            .whereType<Map>()
            .map((e) => Attachment.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      atts = const [];
    }

    final sourcesRaw = r['sources'] as String? ?? '[]';
    List<MessageSource> sources = const [];
    try {
      final decoded = jsonDecode(sourcesRaw);
      if (decoded is List) {
        sources = decoded
            .whereType<Map>()
            .map((e) => MessageSource.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      sources = const [];
    }

    // M40 — followUps
    final followUpsRaw = r['followUps'] as String? ?? '[]';
    List<String> followUps = const [];
    try {
      final decoded = jsonDecode(followUpsRaw);
      if (decoded is List) {
        followUps = decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
      followUps = const [];
    }

    return ChatMessage(
      id: r['id'] as String,
      threadId: r['threadId'] as String? ?? '',
      role: ChatRole.values.firstWhere(
        (e) => e.name == (r['role'] as String? ?? 'user'),
        orElse: () => ChatRole.user,
      ),
      content: r['content'] as String? ?? '',
      hiddenPromptContext: r['hiddenPromptContext'] as String?,
      sources: sources,
      followUps: followUps,
      attachments: atts,
      createdAt: DateTime.tryParse(r['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isResearchReport: ((r['isResearchReport'] as num?)?.toInt() ?? 0) != 0,
    );
  }
}
