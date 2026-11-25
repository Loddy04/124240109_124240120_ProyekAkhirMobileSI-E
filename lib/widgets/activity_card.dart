import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../theme/app_theme.dart';

// Kartu hasil analisis Aktivitas (F7): skor, tingkat, rincian tiap faktor,
// saran, dan jam yang lebih baik. Hanya menampilkan hasil dari mesin Activity.
class ActivityCard extends StatelessWidget {
  final Activity aktivitas;
  final ActivityResult hasil;

  // Keterangan singkat, misalnya "Besok · Yogyakarta"
  final String keterangan;

  // true bila hari yang dinilai jauh (prakiraan kurang akurat)
  final bool catatanJauh;

  // Aksi tombol "Buat pengingat"; bila kosong tombol tidak ditampilkan
  final VoidCallback? onBuatPengingat;

  const ActivityCard({
    super.key,
    required this.aktivitas,
    required this.hasil,
    required this.keterangan,
    this.catatanJauh = false,
    this.onBuatPengingat,
  });

  // Warna tingkat: Cocok hijau, Cukup kuning, Kurang dan Hindari merah
  Color _warnaTingkat(PayunginColors c) {
    switch (hasil.tingkat) {
      case 'Cocok':
        return c.scoreGood;
      case 'Cukup':
        return c.scoreWarn;
      default:
        return c.scoreBad;
    }
  }

  Color _warnaStatus(PayunginColors c, Status s) {
    switch (s) {
      case Status.bagus:
        return c.scoreGood;
      case Status.sedang:
        return c.scoreWarn;
      case Status.buruk:
        return c.scoreBad;
    }
  }

  IconData _ikonStatus(Status s) {
    switch (s) {
      case Status.bagus:
        return Icons.check_circle_rounded;
      case Status.sedang:
        return Icons.error_outline_rounded;
      case Status.buruk:
        return Icons.cancel_rounded;
    }
  }

  String _labelStatus(Status s) {
    switch (s) {
      case Status.bagus:
        return 'Bagus';
      case Status.sedang:
        return 'Sedang';
      case Status.buruk:
        return 'Buruk';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final warna = _warnaTingkat(c);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul: ikon aktivitas, nama, dan keterangan
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.chipBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(aktivitas.ikon, color: c.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasil.namaAktivitas,
                      style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      keterangan,
                      style: TextStyle(color: c.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Cincin skor dan tingkat
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: hasil.skor / 100,
                        strokeWidth: 8,
                        backgroundColor: c.textMuted.withAlpha(50),
                        valueColor: AlwaysStoppedAnimation<Color>(warna),
                      ),
                    ),
                    Text(
                      '${hasil.skor}',
                      style: TextStyle(color: c.text, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasil.tingkat.toUpperCase(),
                      style: TextStyle(
                        color: warna,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dinilai pada pukul ${Activity.formatJam(hasil.jamDinilai)}',
                      style: TextStyle(color: c.textMuted, fontSize: 12.5),
                    ),
                    if (hasil.dibatasi)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Skor dibatasi oleh faktor penentu',
                          style: TextStyle(color: c.textMuted, fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rekomendasi: kalimat utama, lalu saran dari faktor yang Buruk
          Text(
            hasil.saran.first,
            style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          for (final saran in hasil.saran.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: c.textMuted)),
                  Expanded(
                    child: Text(
                      saran,
                      style: TextStyle(color: c.textMuted, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Divider(color: c.glassBorder, height: 1),
          const SizedBox(height: 14),

          // Rincian tiap faktor beserta statusnya
          Text(
            'Rincian faktor',
            style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final f in hasil.faktor)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(_ikonStatus(f.status), color: _warnaStatus(c, f.status), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.nama,
                      style: TextStyle(color: c.text, fontSize: 14),
                    ),
                  ),
                  Text(
                    f.nilaiTeks,
                    style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Text(
                      _labelStatus(f.status),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: _warnaStatus(c, f.status),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Jam yang lebih baik pada hari yang sama
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.chipBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusChip + 2),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: c.chipText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _teksJamLebihBaik(),
                    style: TextStyle(color: c.chipText, fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          if (catatanJauh)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Prakiraan untuk hari yang jauh kurang akurat.',
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),

          // Buat pengingat dari hasil ini (tidak ditampilkan bila tidak ada jam yang aman)
          if (onBuatPengingat != null && hasil.jamPengingat != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onBuatPengingat,
                icon: const Icon(Icons.notifications_active_outlined, size: 20),
                label: Text('Buat pengingat pukul ${Activity.formatJam(hasil.jamPengingat!)}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _teksJamLebihBaik() {
    if (hasil.tidakAdaJamAman) return 'Tidak ada jam yang aman pada hari itu.';
    if (hasil.jamLebihBaik != null) {
      return 'Jam lebih baik: ${Activity.formatJam(hasil.jamLebihBaik!)} (skor ${hasil.skorLebihBaik})';
    }
    return 'Jam ini sudah yang terbaik pada hari itu.';
  }
}
