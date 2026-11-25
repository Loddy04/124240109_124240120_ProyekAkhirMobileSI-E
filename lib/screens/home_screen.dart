import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';
import '../models/favorite_city.dart';
import '../models/weather_data.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/advice_card.dart';
import '../widgets/weather_card.dart';
import 'detail_screen.dart';

// Satu halaman pada slider Beranda: kota favorit atau kartu sementara Lokasi Saya
class _KotaBeranda {
  final String nama;
  final double lat;
  final double lon;

  // true untuk kartu Lokasi Saya yang tidak disimpan dan hilang saat Beranda dibuat ulang
  final bool sementara;

  // Teks lencana kartu sementara; bila kosong dipakai koordinat
  final String? keterangan;

  const _KotaBeranda({
    required this.nama,
    required this.lat,
    required this.lon,
    this.sementara = false,
    this.keterangan,
  });

  // Pengenal untuk menyimpan cuaca kota ini
  String get kunci => '$lat,$lon';

  // Koordinat singkat untuk lencana kartu sementara
  String get koordinatTeks => '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
}

// Beranda (tab 1): kartu cuaca yang bisa digeser antar kota favorit
// beserta Skor Payung kota yang sedang tampil (F2, F9).
class HomeScreen extends StatefulWidget {
  // Nama lengkap dari Root untuk sapaan. Opsional agar Beranda tetap jalan sendiri.
  final String namaLengkap;

  const HomeScreen({super.key, this.namaLengkap = 'Pengguna'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Daftar kota pada slider: favorit, dan kartu sementara Lokasi Saya di depan bila ada
  late final List<_KotaBeranda> _kota;
  late final PageController _controller;
  int _halaman = 0;

  // Lokasi Saya: sedang mencari posisi
  bool _mencariLokasi = false;

  // Diingat selama aplikasi berjalan. Beranda dibuat ulang tiap pindah tab, jadi
  // kartu terakhir yang dilihat disimpan di sini agar tidak kembali ke kartu pertama.
  // Kartu sementara tidak diingat.
  static String? _kartuTerakhir;

  // Dialog privasi cukup ditunjukkan sekali, dan lokasi otomatis dicoba sekali
  static bool _privasiDitunjukkan = false;
  static bool _otomatisDicoba = false;

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
    // Kembali ke kartu terakhir yang dilihat; bila tidak ada lagi, mulai dari kartu pertama
    final awal = _kota.indexWhere((k) => k.kunci == _kartuTerakhir);
    _halaman = awal < 0 ? 0 : awal;
    // Satu halaman selebar layar: tepi kartu kota lain tidak terlihat
    _controller = PageController(initialPage: _halaman);
    // Muat kota yang tampil dan satu di sebelahnya setelah layar siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _muat(_halaman);
      _muat(_halaman + 1);
      // Belum ada kota favorit: tampilkan cuaca di lokasimu, sekali per aplikasi dibuka
      if (_kota.isEmpty && !_otomatisDicoba) {
        _otomatisDicoba = true;
        _lokasiSaya();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Kota favorit (nama yang sama hanya sekali). Tidak ada kota bawaan.
  List<_KotaBeranda> _susunKota() {
    final daftar = <_KotaBeranda>[];
    final sudahAda = <String>{};
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

  // ---- Lokasi Saya (F15, LBS) ----

  void _pesan(String teks) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  // Dialog privasi sebelum meminta izin; true bila pengguna melanjutkan
  Future<bool> _setujuPrivasi() async {
    if (_privasiDitunjukkan) return true;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Izin lokasi'),
        content: const Text(
          'Lokasi dipakai untuk mencari nama kotamu (lewat OpenStreetMap) dan mengambil cuaca dari Open-Meteo. Lokasi tidak disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (lanjut == true) _privasiDitunjukkan = true;
    return lanjut == true;
  }

  // Dialog dengan tombol menuju pengaturan (GPS mati atau izin ditolak permanen)
  Future<void> _dialogPengaturan({
    required String judul,
    required String isi,
    required String tombol,
    required Future<bool> Function() buka,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              buka();
            },
            child: Text(tombol),
          ),
        ],
      ),
    );
  }

  // Tombol Lokasi Saya: izin, ambil posisi, cari nama kotanya, lalu tampilkan kartunya.
  // Kota dari GPS tidak pernah disimpan.
  Future<void> _lokasiSaya() async {
    if (!await _setujuPrivasi() || !mounted) return;

    setState(() => _mencariLokasi = true);
    try {
      final posisi = await LocationService.getCurrent();
      // Cari kota tempat posisi berada (null bila gagal, mis. offline)
      final info = await LocationService.cariKota(posisi.latitude, posisi.longitude);
      if (!mounted) return;
      _tampilkanLokasi(posisi.latitude, posisi.longitude, info);
    } on LocationException catch (e) {
      if (!mounted) return;
      switch (e.type) {
        case LocationError.serviceOff:
          await _dialogPengaturan(
            judul: 'Layanan lokasi mati',
            isi: 'Nyalakan GPS agar cuaca di posisimu bisa ditampilkan.',
            tombol: 'Buka pengaturan lokasi',
            buka: Geolocator.openLocationSettings,
          );
        case LocationError.denied:
          _pesan('Izin lokasi ditolak. Kamu bisa mencobanya lagi.');
        case LocationError.deniedForever:
          await _dialogPengaturan(
            judul: 'Izin lokasi ditolak permanen',
            isi: 'Izinkan lokasi lewat pengaturan aplikasi agar fitur ini bisa dipakai.',
            tombol: 'Buka pengaturan aplikasi',
            buka: Geolocator.openAppSettings,
          );
      }
    } catch (e) {
      if (mounted) _pesan('Tidak bisa mengambil lokasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _mencariLokasi = false);
    }
  }

  // Bila kota GPS ada di slider: geser ke kartu itu. Bila tidak: kartu sementara di depan.
  void _tampilkanLokasi(double lat, double lon, InfoKota? info) {
    // Buang kartu sementara lama, lalu cari kota GPS di slider
    final tetap = _kota.where((k) => !k.sementara).toList();
    final int? i;
    if (info != null) {
      // Dicocokkan lewat nama kota, bukan jarak ke pusat kota
      i = LocationService.indeksNama([for (final k in tetap) k.nama], info.kandidat);
    } else {
      // Nama kota tidak bisa dicari: cadangan memakai jarak ke pusat kota
      i = LocationService.indeksTerdekat(
        lat,
        lon,
        [for (final k in tetap) (lat: k.lat, lon: k.lon)],
      );
    }

    setState(() {
      _kota
        ..clear()
        ..addAll(tetap);
      if (i == null) {
        _kota.insert(
          0,
          _KotaBeranda(
            nama: info?.nama ?? 'Lokasi Saya',
            lat: lat,
            lon: lon,
            sementara: true,
            keterangan: info != null ? 'Lokasi Saya' : null,
          ),
        );
      }
      _halaman = i ?? 0;
    });

    final tujuan = i ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      if (i != null) {
        _controller.animateToPage(
          tujuan,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        _controller.jumpToPage(0);
      }
    });

    _muat(tujuan);
    _muat(tujuan + 1);
    if (i != null) {
      _pesan('Kamu berada di ${tetap[i].nama}.');
    } else if (info != null) {
      _pesan('Kamu berada di ${info.nama}. Kota ini belum ada di favorit.');
    } else {
      _pesan('Menampilkan cuaca di lokasimu.');
    }
  }

  // Tombol kecil di bawah sapaan
  Widget _tombolLokasi(PayunginColors c) {
    final radius = BorderRadius.circular(AppTheme.radiusChip + 6);
    return InkWell(
      borderRadius: radius,
      onTap: _mencariLokasi ? null : _lokasiSaya,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: c.chipBg, borderRadius: radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _mencariLokasi
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.chipText),
                  )
                : Icon(Icons.my_location_rounded, size: 18, color: c.chipText),
            const SizedBox(width: 8),
            Text(
              _mencariLokasi ? 'Mencari lokasi...' : 'Lokasi Saya',
              style: TextStyle(
                color: c.chipText,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
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
    final aktif = _kota.isEmpty ? null : _cuaca[_kota[_halaman].kunci];

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
                      const SizedBox(height: 10),
                      _tombolLokasi(c),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap + 4),

                // Belum ada kota sama sekali: ajakan memilih kota
                if (_kota.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
                    child: _kartuKosong(),
                  ),

                // Slider kartu cuaca: geser untuk berganti kota
                if (_kota.isNotEmpty)
                SizedBox(
                  height: 270,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _kota.length,
                    onPageChanged: (i) {
                      // Ingat kartu ini (kecuali yang sementara) untuk saat kembali ke Beranda
                      _kartuTerakhir = _kota[i].sementara ? null : _kota[i].kunci;
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

  // Kartu saat belum ada kota: sedang mencari lokasi, atau ajakan memilih kota
  Widget _kartuKosong() {
    return HeroCard(
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_mencariLokasi) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 14),
              const Text(
                'Mencari lokasimu...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ] else ...[
              const Icon(Icons.location_off_rounded, color: Colors.white, size: 34),
              const SizedBox(height: 8),
              const Text(
                'Belum ada kota',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ketuk Lokasi Saya, atau tambah kota di tab Kota',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12.5),
              ),
            ],
          ],
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
        label: kota.sementara ? (kota.keterangan ?? kota.koordinatTeks) : null,
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
