import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../models/weather_data.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/advice_card.dart';
import '../widgets/weather_card.dart';

// Beranda (tab 1): ringkasan cuaca kota utama beserta Skor Payung (F2, F9).
class HomeScreen extends StatefulWidget {
  // Nama lengkap dari Root untuk sapaan. Opsional agar Beranda tetap jalan sendiri.
  final String namaLengkap;

  const HomeScreen({super.key, this.namaLengkap = 'Pengguna'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tiga keadaan: loading, sukses (_data terisi), atau gagal (_errorMessage terisi)
  WeatherData? _data;
  bool _isLoading = true;
  String? _errorMessage;

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
    // Ambil cuaca begitu layar dibuka
    fetchWeather();
  }

  // Mengambil cuaca kota utama dari ApiService (juga dipakai tarik-untuk-refresh)
  Future<void> fetchWeather() async {
    try {
      final hasil = await ApiService.getWeather(
        SettingsService.mainLat,
        SettingsService.mainLon,
      );
      // Layar bisa sudah ditutup selama menunggu internet
      if (!mounted) return;
      setState(() {
        _data = hasil;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_data == null) {
        // Belum ada data sama sekali: tampilkan layar error dengan tombol Coba lagi
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tidak bisa memuat cuaca. Periksa koneksi internet.';
        });
      } else {
        // Sudah ada data lama: pertahankan dan beri tahu lewat SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui cuaca.')),
        );
      }
    }
  }

  // Tombol Coba lagi: tampilkan loading lalu ambil ulang
  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    fetchWeather();
  }

  // Contoh hasil: "Kamis, 5 November"
  String _tanggalHariIni() {
    final now = DateTime.now();
    return '${_hari[now.weekday - 1]}, ${now.day} ${_bulan[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = context.pc;

    // 1. Loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Gagal (belum ada data)
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
    return RefreshIndicator(
      onRefresh: fetchWeather,
      child: SingleChildScrollView(
        // Tetap bisa ditarik untuk refresh walau isinya pendek
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.edge),
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
            const SizedBox(height: AppTheme.gap + 4),
            WeatherCard(
              cityName: SettingsService.mainCity,
              data: data,
              unit: SettingsService.unit,
              label: 'Kota utama',
            ),
            const SizedBox(height: AppTheme.gap),
            AdviceCard(data.advice),
          ],
        ),
      ),
    );
  }
}
