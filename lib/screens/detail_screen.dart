import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../models/weather_data.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_card.dart';

// Detail Cuaca (F3): prakiraan lengkap untuk satu kota.
// Dibuka dengan Navigator.push; data dikirim lewat constructor (passing data).
class DetailScreen extends StatefulWidget {
  // Wajib: koordinat dan nama kota
  final double latitude;
  final double longitude;
  final String namaKota;

  // Opsional: satuan suhu, bawaan 'C'
  final String satuan;

  const DetailScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.namaKota,
    this.satuan = 'C',
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // Tiga keadaan: loading, sukses (_data terisi), atau gagal (_errorMessage terisi)
  WeatherData? _data;
  bool _isLoading = true;
  String? _errorMessage;

  static const List<String> _hari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  static const List<String> _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  void initState() {
    super.initState();
    // Halaman melakukan request sendiri berdasarkan koordinat yang dikirim
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final hasil = await ApiService.getWeather(widget.latitude, widget.longitude);
      if (!mounted) return;
      setState(() {
        _data = hasil;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak bisa memuat cuaca. Periksa koneksi internet.';
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _fetch();
  }

  // ---- Pembantu tampilan ----

  // Suhu Celsius -> satuan pilihan, dibulatkan. Contoh: "29°"
  String _suhu(double celsius) {
    final nilai = widget.satuan == 'F' ? celsius * 9 / 5 + 32 : celsius;
    return '${nilai.round()}°';
  }

  // "2026-11-22T14:00" -> "14.00"
  String _jam(String waktu) {
    if (waktu.length < 16) return '-';
    return waktu.substring(11, 16).replaceAll(':', '.');
  }

  // Ambil elemen list dengan aman; bila indeks di luar batas, pakai nilai bawaan
  T _ambil<T>(List<T> daftar, int indeks, T bawaan) =>
      indeks < daftar.length ? daftar[indeks] : bawaan;

  // Indeks jam sekarang di daftar per jam (cocokkan "yyyy-MM-ddTHH")
  int _indeksJamSekarang(WeatherData data) {
    if (data.currentTime.length < 13) return 0;
    final awalan = data.currentTime.substring(0, 13);
    final i = data.hourlyTime.indexWhere((t) => t.startsWith(awalan));
    return i < 0 ? 0 : i;
  }

  // "Hari ini", "Besok", lalu "Rabu, 25 Nov"
  String _namaHari(String tanggal, int indeks) {
    if (indeks == 0) return 'Hari ini';
    if (indeks == 1) return 'Besok';
    final dt = DateTime.tryParse(tanggal);
    if (dt == null) return tanggal;
    return '${_hari[dt.weekday - 1]}, ${dt.day} ${_bulan[dt.month - 1]}';
  }

  // Tingkat UV sederhana
  String _tingkatUv(double uv) {
    if (uv < 3) return 'Rendah';
    if (uv < 6) return 'Sedang';
    if (uv < 8) return 'Tinggi';
    if (uv < 11) return 'Sangat tinggi';
    return 'Ekstrem';
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(title: Text(widget.namaKota)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = context.pc;

    // 1. Loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Gagal
    final data = _data;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge * 1.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: c.textMuted),
              const SizedBox(height: 14),
              Text(
                _errorMessage ?? 'Terjadi kesalahan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontSize: 15),
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _retry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    // 3. Sukses
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.edge, 4, AppTheme.edge, AppTheme.edge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeatherCard(
            cityName: widget.namaKota,
            data: data,
            unit: widget.satuan,
          ),
          _judul(c, 'Per jam'),
          _buildPerJam(c, data),
          _judul(c, '7 Hari'),
          _buildTujuhHari(c, data),
          _judul(c, 'Ringkasan'),
          _buildRingkasan(c, data),
          _judul(c, 'Matahari'),
          _buildMatahari(c, data),
        ],
      ),
    );
  }

  Widget _judul(PayunginColors c, String teks) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        teks,
        style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }

  // Dekorasi kotak kecil bergaya kaca (tanpa blur agar daftar tetap ringan)
  BoxDecoration _kotak(PayunginColors c) {
    return BoxDecoration(
      color: c.glass,
      borderRadius: BorderRadius.circular(AppTheme.radiusChip + 6),
      border: Border.all(color: c.glassBorder),
    );
  }

  // 24 jam ke depan: ListView horizontal
  Widget _buildPerJam(PayunginColors c, WeatherData data) {
    final awal = _indeksJamSekarang(data);
    final panjang = [
      data.hourlyTime.length,
      data.hourlyTemp.length,
      data.hourlyRain.length,
      data.hourlyCode.length,
    ].reduce(min);
    final jumlah = max(0, min(24, panjang - awal));

    if (jumlah == 0) {
      return Text('Data per jam tidak tersedia.', style: TextStyle(color: c.textMuted));
    }

    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: jumlah,
        itemBuilder: (context, i) {
          final idx = awal + i;
          return Container(
            width: 74,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: _kotak(c),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  i == 0 ? 'Sekarang' : _jam(data.hourlyTime[idx]),
                  style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Icon(WeatherData.iconOf(data.hourlyCode[idx]), color: c.accent, size: 26),
                Text(
                  _suhu(data.hourlyTemp[idx]),
                  style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${data.hourlyRain[idx]}%',
                  style: TextStyle(color: c.chipText, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 7 hari: ListView.builder dengan ListTile; ikon dari internet (Image.network)
  Widget _buildTujuhHari(PayunginColors c, WeatherData data) {
    final jumlah = data.dailyTime.length;
    if (jumlah == 0) {
      return Text('Data 7 hari tidak tersedia.', style: TextStyle(color: c.textMuted));
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: jumlah,
        itemBuilder: (context, i) {
          final kode = _ambil(data.dailyCode, i, 0);
          final hujan = _ambil(data.dailyRain, i, 0);
          final mm = _ambil(data.dailyPrecipSum, i, 0.0);
          return ListTile(
            leading: Image.network(
              WeatherData.iconUrlOf(kode),
              width: 44,
              height: 44,
              // Cadangan bila gambar gagal dimuat (misalnya offline)
              errorBuilder: (context, error, stackTrace) =>
                  Icon(WeatherData.iconOf(kode), size: 32, color: c.accent),
            ),
            title: Text(
              _namaHari(data.dailyTime[i], i),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${WeatherData.conditionOf(kode)} · hujan $hujan% · ${mm.toStringAsFixed(1)} mm',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
            trailing: Text(
              '${_suhu(_ambil(data.dailyMax, i, 0.0))} / ${_suhu(_ambil(data.dailyMin, i, 0.0))}',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
    );
  }

  // Enam kotak ringkasan: GridView.builder
  Widget _buildRingkasan(PayunginColors c, WeatherData data) {
    final uv = data.uvIndex;
    final item = <({IconData ikon, String nilai, String label})>[
      (ikon: Icons.wb_sunny_outlined, nilai: uv.toStringAsFixed(1), label: 'UV ${_tingkatUv(uv)}'),
      (ikon: Icons.air_rounded, nilai: '${data.windSpeed.round()} km/j', label: 'Angin'),
      (ikon: Icons.water_drop_outlined, nilai: '${data.humidity}%', label: 'Kelembapan'),
      (
        ikon: Icons.umbrella_outlined,
        nilai: '${_ambil(data.dailyPrecipSum, 0, 0.0).toStringAsFixed(1)} mm',
        label: 'Hujan hari ini'
      ),
      (ikon: Icons.thermostat_rounded, nilai: _suhu(data.feelsLike), label: 'Terasa seperti'),
      (ikon: Icons.grain_rounded, nilai: '${data.maxRainChance}%', label: 'Peluang hujan'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: item.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final it = item[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: _kotak(c),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(it.ikon, color: c.accent, size: 24),
              const SizedBox(height: 6),
              Text(
                it.nilai,
                style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                it.label,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  // Matahari terbit dan terbenam hari ini
  Widget _buildMatahari(PayunginColors c, WeatherData data) {
    final terbit = _jam(_ambil(data.dailySunrise, 0, ''));
    final terbenam = _jam(_ambil(data.dailySunset, 0, ''));

    Widget kolom(IconData ikon, String label, String jam) {
      return Expanded(
        child: Column(
          children: [
            Icon(ikon, color: c.accent, size: 28),
            const SizedBox(height: 6),
            Text(jam, style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: c.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return GlassCard(
      child: Row(
        children: [
          kolom(Icons.wb_twilight_rounded, 'Terbit', terbit),
          kolom(Icons.nights_stay_outlined, 'Terbenam', terbenam),
        ],
      ),
    );
  }
}
