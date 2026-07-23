/// Estimasi token (approx). Aturan kasar: 1 token ≈ 4 karakter untuk teks
/// latin. Cukup untuk indikator UI, bukan billing.
class TokenUtils {
  TokenUtils._();

  static int estimate(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 4).ceil();
  }

  /// Format ke label ringkas (`1.2k`, `340`).
  static String format(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }
}
