import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';
import '../models/favorite_city.dart';
import '../models/weather_data.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/advice_card.dart';
import '../widgets/weather_card.dart';
import 'detail_screen.dart';

// Satu halaman pada slider Beranda: kota Beranda atau salah satu kota favorit
class _KotaBeranda {
  final String nama;
  final double lat;
  final double lon;
  final bool utama;

  const _KotaBeranda({
    required this.nama,
    required this.lat,
    required this.lon,
    this.utama = false,
  });

  // Pengenal untuk menyimpan cuaca kota ini
  String get kunci => '$lat,$lon';
}

// Beranda (tab 1): kartu cuaca yang bisa digeser antar kota (kota Beranda dan favorit)
// beserta Skor Payung kota yang sedang tampil (F2, F9).
class HomeScreen extends StatefulWidget {
  // Nama lengkap dari Root untuk sapaan. Opsional agar Beranda tetap jalan sendiri.
  final String namaLengkap;

  const HomeScreen({super.key, this.namaLengkap = 'Pengguna'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Daftar kota pada slider: kota Beranda dulu, lalu favorit
  late final List<_KotaBeranda> _kota;
  late final PageController _controller;
  int _halaman = 0;

  // Keadaan tiap kota: sudah dimuat, sedang dimuat, atau gagal
  final Map<String, WeatherData> _cuaca = {};
  final Set<String> _sedangMuat = {};
  final Set<String> _gagal = {};

  static const List<String> _hari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  static const List<String> _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _kota = _susunKota();
    // Satu halaman selebar layar: tepi kartu kota lain tidak terlihat
    _controller = PageController();
    // Muat kota yang tampil dan satu di sebelahnya setelah layar siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _muat(0);
      _muat(1);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Kota Beranda lebih dulu, lalu favorit yang namanya berbeda
  List<_KotaBeranda> _susunKota() {
    final utama = SettingsService.mainCity;
    final daftar = <_KotaBeranda>[
      _KotaBeranda(
        nama: utama,
        lat: SettingsService.mainLat,
        lon: SettingsService.mainLon,
        utama: true,
      ),
    ];

    final sudahAda = <String>{utama.toLowerCase()};
    for (final kota in Hive.box<FavoriteCity>('favorites').values) {
      if (sudahAda.add(kota.name.toLowerCase())) {
        daftar.add(_KotaBeranda(nama: kota.name, lat: kota.lat, lon: kota.lon));
      }
    }
    return daftar;
  }

  // Memuat cuaca satu kota (juga dipakai tombol coba lagi dan tarik-untuk-refresh)
  Future<void> _muat(int indeks, {bool paksa = false}) async {
    if (indeks < 0 || indeks >= _kota.length) return;
    final kota = _kota[indeks];
    final kunci = kota.kunci;
    if (_sedangMuat.contains(kunci)) return;
    if (!paksa && _cuaca.containsKey(kunci)) return;

    setState(() {
      _sedangMuat.add(kunci);
      _gagal.remove(kunci);
    });

    try {
      final data = await ApiService.getWeather(kota.lat, kota.lon);
      if (!mounted) return;
      setState(() {
        _cuaca[kunci] = data;
        _sedangMuat.remove(kunci);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sedangMuat.remove(kunci);
        // Bila sudah ada data lama, tetap dipakai; hanya tandai gagal bila belum ada
        if (!_cuaca.containsKey(kunci)) _gagal.add(kunci);
      });
    }
  }

  // Tarik-untuk-refresh: muat ulang kota yang tampil dan tetangganya
  Future<void> _muatUlang() async {
    final dekat = <int>{_halaman - 1, _halaman, _halaman + 1}
        .where((i) => i >= 0 && i < _kota.length)
        .toList();
    await Future.wait([for (final i in dekat) _muat(i, paksa: true)]);
  }

  void _bukaDetail(_KotaBeranda kota) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          latitude: kota.lat,
          longitude: kota.lon,
          namaKota: kota.nama,
          satuan: SettingsService.unit,
        ),
      ),
    );
  }

  // Contoh hasil: "Kamis, 5 November"
  String _tanggalHariIni() {
    final now = DateTime.now();
    return '${_hari[now.weekday - 1]}, ${now.day} ${_bulan[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final banyak = _kota.length > 1;
    final aktif = _cuaca[_kota[_halaman].kunci];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _muatUlang,
          child: SingleChildScrollView(
            // Tetap bisa ditarik untuk refresh walau isinya pendek
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppTheme.edge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tanggalHariIni(),
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Halo, ${widget.namaLengkap}!',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap + 4),

                // Slider kartu cuaca: geser untuk berganti kota
                SizedBox(
                  height: 270,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _kota.length,
                    onPageChanged: (i) {
                      setState(() => _halaman = i);
                      _muat(i);
                      _muat(i + 1);
                    },
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
                        // Align melonggarkan tinggi agar kartu setinggi isinya
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _kartuKota(i),
                        ),
                      );
                    },
                  ),
                ),

                // Titik penanda halaman (hanya bila ada lebih dari satu kota)
                if (banyak)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _kota.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _halaman ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _halaman ? c.accent : c.textMuted.withAlpha(90),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Skor Payung kota yang sedang tampil
                if (aktif != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.edge, AppTheme.gap, AppTheme.edge, 0,
                    ),
                    child: AdviceCard(aktif.advice),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Isi satu halaman slider: kartu cuaca, loading, atau pesan gagal
  Widget _kartuKota(int i) {
    final kota = _kota[i];
    final data = _cuaca[kota.kunci];

    if (data != null) {
      return WeatherCard(
        cityName: kota.nama,
        data: data,
        unit: SettingsService.unit,
        label: kota.utama ? 'Kota utama' : null,
        onTap: () => _bukaDetail(kota),
      );
    }

    final gagal = _gagal.contains(kota.kunci);
    return HeroCard(
      onTap: gagal ? () => _muat(i, paksa: true) : null,
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kota.nama,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (gagal) ...[
              const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 34),
              const SizedBox(height: 8),
              const Text(
                'Tidak bisa memuat cuaca',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                'Ketuk untuk coba lagi',
                style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12),
              ),
            ] else
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
