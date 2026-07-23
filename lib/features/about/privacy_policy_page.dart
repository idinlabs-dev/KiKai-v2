import 'package:flutter/material.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';

/// Halaman Privacy Policy KiKai. Konten statis, monokrom, konsisten dgn
/// design system app (cream + hitam). Tidak melakukan I/O apa pun.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String _lastUpdated = '19 Juli 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '${AppConfig.appName} — Kebijakan Privasi',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Terakhir diperbarui: $_lastUpdated',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            const _Paragraph(
              'Kebijakan Privasi ini menjelaskan bagaimana ${'KiKai'} '
              'mengumpulkan, menggunakan, dan melindungi data kamu ketika '
              'kamu memakai aplikasi. Dengan menggunakan aplikasi ini kamu '
              'menyetujui praktik yang dijelaskan di bawah.',
            ),
            _Section(
              title: '1. Data yang Kami Kumpulkan',
              body:
                  'Kami hanya mengumpulkan data yang benar-benar dibutuhkan '
                  'agar aplikasi berjalan, yaitu:\n'
                  '• Akun: email, nama tampilan, dan foto profil (bila login '
                  'dengan Google).\n'
                  '• Riwayat percakapan: pesan yang kamu kirim ke KiKai untuk '
                  'ditampilkan kembali di History.\n'
                  '• Data perangkat teknis: model perangkat, versi OS, versi '
                  'aplikasi untuk keperluan diagnostik & anti-abuse.\n'
                  '• Data misi & streak harian untuk fitur reward.',
            ),
            _Section(
              title: '2. Cara Kami Menggunakan Data',
              body:
                  'Data digunakan untuk: menjalankan fitur chat AI, menyimpan '
                  'riwayat percakapan kamu, mengelola akun & entitlement '
                  'premium, menampilkan misi harian, mencegah penyalahgunaan, '
                  'serta memperbaiki kualitas layanan.',
            ),
            _Section(
              title: '3. Pemrosesan oleh AI',
              body:
                  'Pesan yang kamu kirim diproses oleh model AI melalui '
                  'penyedia pihak ketiga tepercaya untuk menghasilkan '
                  'jawaban. Kami tidak menjual isi percakapan kamu, dan '
                  'penyedia inference tidak menggunakan pesanmu untuk '
                  'melatih ulang model mereka.',
            ),
            _Section(
              title: '4. Penyimpanan Data',
              body:
                  'Data akun dan riwayat percakapan disimpan di infrastruktur '
                  'cloud yang aman (Firebase / Google Cloud). Data lokal '
                  '(cache, preferensi, tema) disimpan di perangkat kamu.',
            ),
            _Section(
              title: '5. Berbagi Data',
              body:
                  'Kami TIDAK menjual data pribadi kamu ke pihak ketiga. '
                  'Data hanya dibagikan ke penyedia layanan yang mendukung '
                  'operasi aplikasi (autentikasi, penyimpanan, inference AI, '
                  'jaringan iklan), sesuai kebijakan privasi masing-masing.',
            ),
            _Section(
              title: '6. Iklan',
              body:
                  'Aplikasi menampilkan iklan pihak ketiga (mis. AdMob) di '
                  'sebagian layar. Jaringan iklan dapat menggunakan '
                  'pengenal iklan perangkat untuk menayangkan iklan yang '
                  'relevan. Kamu bisa mereset / membatasi pengenal iklan '
                  'melalui pengaturan sistem Android.',
            ),
            _Section(
              title: '7. Hak Kamu',
              body:
                  'Kamu berhak: mengakses data akun, menghapus riwayat '
                  'percakapan dari menu Settings, atau menghapus akun '
                  'sepenuhnya dengan menghubungi kami. Permintaan penghapusan '
                  'akan diproses dalam waktu wajar sesuai regulasi yang '
                  'berlaku.',
            ),
            _Section(
              title: '8. Keamanan',
              body:
                  'Kami menerapkan enkripsi in-transit (HTTPS/TLS), aturan '
                  'akses berbasis peran, serta perlindungan tambahan pada '
                  'dataset internal aplikasi. Meski demikian, tidak ada '
                  'sistem yang 100% aman — mohon jaga kredensial akunmu.',
            ),
            _Section(
              title: '9. Anak-anak',
              body:
                  'Aplikasi ini tidak ditujukan untuk pengguna di bawah 13 '
                  'tahun. Jika kamu adalah orang tua/wali dan mengetahui '
                  'anak kamu menggunakan aplikasi ini, silakan hubungi kami '
                  'agar datanya dihapus.',
            ),
            _Section(
              title: '10. Perubahan Kebijakan',
              body:
                  'Kebijakan ini dapat diperbarui sewaktu-waktu. Perubahan '
                  'signifikan akan diberitahukan lewat aplikasi. Tanggal '
                  '"Terakhir diperbarui" di atas menandai versi berlaku.',
            ),
            _Section(
              title: '11. Kontak',
              body:
                  'Pertanyaan seputar privasi bisa dikirim ke developer '
                  'melalui kanal yang tercantum di halaman About '
                  '(Instagram / LinkedIn / GitHub — Idin Iskandar).',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                'Dengan terus menggunakan KiKai, kamu dianggap membaca dan '
                'menyetujui Kebijakan Privasi ini.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          _Paragraph(body),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        height: 1.55,
        color: AppColors.textSecondary,
      ),
    );
  }
}
