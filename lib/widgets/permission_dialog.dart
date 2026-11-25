import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Pop-up izin yang dipakai bersama (lokasi dan notifikasi): kartu kaca dengan ikon bulat,
// judul, penjelasan, dan dua tombol. Warna mengikuti tema terang atau gelap.
//
// Mengembalikan true bila tombol utama ditekan, false bila tombol kedua ditekan.
Future<bool> tampilkanDialogIzin(
  BuildContext context, {
  required IconData ikon,
  required String judul,
  required String isi,
  String tombolUtama = 'Izinkan',
  String tombolKedua = 'Nanti Saja',
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DialogIzin(
      ikon: ikon,
      judul: judul,
      isi: isi,
      tombolUtama: tombolUtama,
      tombolKedua: tombolKedua,
    ),
  );
  return hasil == true;
}

class _DialogIzin extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String isi;
  final String tombolUtama;
  final String tombolKedua;

  const _DialogIzin({
    required this.ikon,
    required this.judul,
    required this.isi,
    required this.tombolUtama,
    required this.tombolKedua,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lingkaran ikon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, color: c.accent, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.text),
            ),
            const SizedBox(height: 10),
            Text(
              isi,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.45),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Tombol kedua: garis tipis, warna dari tema
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: c.textMuted,
                      side: BorderSide(color: c.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      tombolKedua,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tombol utama: latar aksen, teks onAccent agar terbaca di mode terang dan gelap
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      tombolUtama,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
