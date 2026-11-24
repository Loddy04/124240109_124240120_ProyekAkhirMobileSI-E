import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../theme/app_theme.dart';

// Kartu utama Beranda (F2): nama kota, suhu besar, kondisi cuaca,
// dan tiga info singkat (kelembapan, angin, peluang hujan).
// Hanya menampilkan data yang diberikan; loading dan error ditangani Beranda.
class WeatherCard extends StatelessWidget {
  final String cityName;
  final WeatherData data;

  // Satuan suhu dari pengaturan: 'C' atau 'F'
  final String unit;

  // Lencana kecil di pojok kanan atas, misalnya "Kota utama" (boleh kosong)
  final String? label;

  // Aksi saat kartu diketuk, misalnya membuka Detail (boleh kosong)
  final VoidCallback? onTap;

  const WeatherCard({
    super.key,
    required this.cityName,
    required this.data,
    this.unit = 'C',
    this.label,
    this.onTap,
  });

  // Mengubah suhu Celsius ke satuan pilihan lalu membulatkannya, contoh: "29°"
  String _suhu(double celsius) {
    final nilai = unit == 'F' ? celsius * 9 / 5 + 32 : celsius;
    return '${nilai.round()}°';
  }

  static const List<String> _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  // Contoh: "Data terakhir diperbarui 14.05 (offline)"; bila bukan hari ini: "22 Nov 14.05"
  String _teksOffline() {
    final waktu = data.cachedAt;
    if (waktu == null) return 'Data terakhir (offline)';

    final now = DateTime.now();
    final jam = '${waktu.hour.toString().padLeft(2, '0')}.${waktu.minute.toString().padLeft(2, '0')}';
    final hariIni = waktu.year == now.year && waktu.month == now.month && waktu.day == now.day;
    final kapan = hariIni ? jam : '${waktu.day} ${_bulan[waktu.month - 1]} $jam';
    return 'Data terakhir diperbarui $kapan (offline)';
  }

  @override
  Widget build(BuildContext context) {
    // Teks di atas HeroCard (latar biru) selalu putih
    const putih = Colors.white;
    final putihRedup = Colors.white.withAlpha(204);

    return HeroCard(
      onTap: onTap,
      // Stack: ikon cuaca besar ditempatkan di sisi kanan, di atas isi kartu
      child: Stack(
        children: [
          Positioned(
            top: 40,
            right: 0,
            child: Icon(data.icon, size: 84, color: putih),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris atas: nama kota dan lencana
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: putih),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      cityName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: putih,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (label != null)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(36),
                        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                      ),
                      child: Text(
                        label!,
                        style: const TextStyle(
                          color: putih,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Suhu besar dan kondisi (diberi ruang kosong di kanan untuk ikon)
              Padding(
                padding: const EdgeInsets.only(right: 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _suhu(data.tempC),
                      style: const TextStyle(
                        color: putih,
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.condition} · terasa ${_suhu(data.feelsLike)}',
                      style: TextStyle(color: putihRedup, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Tiga info singkat
              Row(
                children: [
                  _InfoBox(label: 'Kelembapan', value: '${data.humidity}%'),
                  const SizedBox(width: 10),
                  _InfoBox(label: 'Angin', value: '${data.windSpeed.round()} km/j'),
                  const SizedBox(width: 10),
                  _InfoBox(label: 'Hujan', value: '${data.maxRainChance}%'),
                ],
              ),
              // Penanda data dari cache saat offline (F14)
              if (data.isFromCache) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 14, color: putihRedup),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _teksOffline(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: putihRedup, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Kotak kecil berisi satu info (label dan nilai) di dalam kartu utama
class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(36),
          borderRadius: BorderRadius.circular(AppTheme.radiusChip + 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(204),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
