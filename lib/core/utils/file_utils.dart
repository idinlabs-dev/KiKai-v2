/// Utility deteksi bahasa pemrograman dari ekstensi file & MIME guessing
/// ringan. Dipakai `AttachmentService` (M4) untuk auto-wrap ke fenced code
/// block sebelum dikirim ke model.
class FileUtils {
  FileUtils._();

  static const Map<String, String> _extToLanguage = {
    'dart': 'dart',
    'js': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'ts': 'typescript',
    'tsx': 'tsx',
    'jsx': 'jsx',
    'py': 'python',
    'go': 'go',
    'php': 'php',
    'java': 'java',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'swift': 'swift',
    'rb': 'ruby',
    'rs': 'rust',
    'c': 'c',
    'h': 'c',
    'cpp': 'cpp',
    'cc': 'cpp',
    'hpp': 'cpp',
    'cs': 'csharp',
    'html': 'html',
    'htm': 'html',
    'css': 'css',
    'scss': 'scss',
    'sass': 'sass',
    'json': 'json',
    'yaml': 'yaml',
    'yml': 'yaml',
    'toml': 'toml',
    'xml': 'xml',
    'sql': 'sql',
    'sh': 'bash',
    'bash': 'bash',
    'zsh': 'bash',
    'md': 'markdown',
    'markdown': 'markdown',
    'txt': 'plaintext',
    'env': 'ini',
    'gitignore': 'ini',
    'dockerfile': 'dockerfile',
    'lua': 'lua',
    'r': 'r',
    'scala': 'scala',
  };

  /// Ambil ekstensi lower-case dari filename (tanpa titik). Return `''`
  /// kalau tidak punya ekstensi.
  static String extensionOf(String filename) {
    final name = filename.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  /// Deteksi language tag untuk fenced code block. Default `plaintext`.
  static String detectLanguage(String filename) {
    final ext = extensionOf(filename);
    return _extToLanguage[ext] ?? 'plaintext';
  }

  /// Bungkus konten file ke fenced code block Markdown.
  static String wrapAsCodeBlock(String filename, String content) {
    final lang = detectLanguage(filename);
    return '```$lang\n$content\n```';
  }

  /// Cek apakah file kemungkinan berisi credential sensitif.
  /// Dipakai UI untuk kasih warning sebelum kirim (SOP §8).
  static bool looksSensitive(String filename) {
    final n = filename.toLowerCase();
    return n == '.env' ||
        n.endsWith('.env') ||
        n.contains('secret') ||
        n.contains('credential') ||
        n.contains('private_key');
  }
}
