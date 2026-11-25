import 'dart:math';

import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/weather_data.dart';
import '../services/pengingat_berikutnya.dart';
import '../theme/app_theme.dart';

// Bagian-bagian tambahan Beranda (F2): judul bagian, pratinjau 7 jam,
// skor aktivitas hari ini, dan pengingat berikutnya. Semuanya hanya menampilkan
// data yang diberikan; Detail tetap memuat data lengkapnya.

// Judul kecil di atas tiap bagian
class BerandaJudul extends StatelessWidget {
  final String teks;

  const BerandaJudul(this.teks, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.edge, 22, AppTheme.edge, 10),
      child: Text(
        teks,
        style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// Pratinjau 7 jam ke depan (Detail memuat 24 jam)
class PratinjauJam extends StatelessWidget {
  final WeatherData data;
  final String satuan;

  const PratinjauJam({super.key, required this.data, this.satuan = 'C'});

  String _suhu(double celsius) {
    final nilai = satuan == 'F' ? celsius * 9 / 5 + 32 : celsius;
    return '${nilai.round()}°';
  }

  // Indeks jam sekarang di daftar per jam (cocokkan "yyyy-MM-ddTHH")
  int _awal() {
    if (data.currentTime.length < 13) return 0;
    final awalan = data.currentTime.substring(0, 13);
    final i = data.hourlyTime.indexWhere((t) => t.startsWith(awalan));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final awal = _awal();
    final panjang = [
      data.hourlyTime.length,
      data.hourlyTemp.length,
      data.hourlyRain.length,
      data.hourlyCode.length,
    ].reduce(min);
    final jumlah = max(0, min(7, panjang - awal));

    if (jumlah == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
        child: Text('Data per jam tidak tersedia.', style: TextStyle(color: c.textMuted)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            for (var i = 0; i < jumlah; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      i == 0 ? 'Kini' : data.hourlyTime[awal + i].substring(11, 16).replaceAll(':', '.'),
                      style: TextStyle(color: c.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Icon(WeatherData.iconOf(data.hourlyCode[awal + i]), color: c.accent, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      _suhu(data.hourlyTemp[awal + i]),
                      style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Skor tiap aktivitas untuk jam sekarang hari ini, dari mesin Aktivitas (F7)
class SkorAktivitasHariIni extends StatelessWidget {
  final WeatherData data;

  const SkorAktivitasHariIni({super.key, required this.data});

  static const Map<String, String> _namaPendek = {
    'jemur': 'Jemur',
    'motor': 'Motor',
    'mobil': 'Mobil',
    'outdoor': 'Outdoor',
  };

  // Jam pada waktu data ("yyyy-MM-ddTHH:mm"), 0 sampai 23
  int _jam() {
    if (data.currentTime.length < 13) return DateTime.now().hour;
    return (int.tryParse(data.currentTime.substring(11, 13)) ?? DateTime.now().hour).clamp(0, 23);
  }

  // Mode gelap memakai warna tema. Mode terang memakai warna yang lebih lembut
  // agar angka skor tidak terlalu kontras di atas kartu.
  Color _warna(PayunginColors c, String tingkat, bool gelap) {
    switch (tingkat) {
      case 'Cocok':
        return gelap ? c.scoreGood : const Color(0xFF4DB784);
      case 'Cukup':
        return gelap ? c.scoreWarn : const Color(0xFFE0A93B);
      default:
        return gelap ? c.scoreBad : const Color(0xFFE57373);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final jam = _jam();

    // Satu hasil per aktivitas; yang gagal dihitung dilewati agar Beranda tidak crash
    final hasil = <MapEntry<Activity, ActivityResult>>[];
    for (final a in Activity.semua) {
      try {
        hasil.add(MapEntry(a, a.analyze(data, 0, jam)));
      } catch (_) {}
    }
    if (hasil.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            for (final e in hasil)
              Expanded(
                child: Column(
                  children: [
                    Icon(e.key.ikon, color: c.accent, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      _namaPendek[e.key.type] ?? e.key.nama,
                      style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${e.value.skor}',
                      style: TextStyle(
                        color: _warna(c, e.value.tingkat, gelap),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      e.value.tingkat,
                      style: TextStyle(
                        color: _warna(c, e.value.tingkat, gelap),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Pengingat yang akan berbunyi paling dulu
class KartuPengingatBerikutnya extends StatelessWidget {
  final PengingatBerikutnya berikutnya;
  final DateTime sekarang;

  const KartuPengingatBerikutnya({
    super.key,
    required this.berikutnya,
    required this.sekarang,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final r = berikutnya.pengingat;
    final w = berikutnya.waktu;
    final jam = '${w.hour.toString().padLeft(2, '0')}.${w.minute.toString().padLeft(2, '0')}';
    // Kota ditambahkan di belakang bila pengingat punya kota. Contoh: "Besok · 07.00 · Sleman"
    final kota = r.cityName.isNotEmpty ? ' · ${r.cityName}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.chipBg, shape: BoxShape.circle),
              child: Icon(Icons.notifications_active_outlined, color: c.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${PengingatBerikutnya.labelHari(w, sekarang)} · $jam$kota',
                    style: TextStyle(color: c.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
