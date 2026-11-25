import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';
import '../models/activity.dart';
import '../models/favorite_city.dart';
import 'add_reminder_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_card.dart';

// Satu pilihan kota pada dropdown: kota Beranda atau salah satu Tempat Saya
class _PilihanKota {
  final String label;
  final String nama;
  final double lat;
  final double lon;

  const _PilihanKota({
    required this.label,
    required this.nama,
    required this.lat,
    required this.lon,
  });
}

// Aktivitas (F7, tab 2): memilih kegiatan, hari, jam, dan kota, lalu aplikasi
// menilai kelayakannya dari prakiraan cuaca. Tidak menyimpan apa pun.
class ActivityScreen extends StatefulWidget {
  // Dipanggil setelah pengingat dari hasil analisis berhasil disimpan;
  // Root memakainya untuk berpindah ke tab Pengingat
  final VoidCallback? onReminderSaved;

  const ActivityScreen({super.key, this.onReminderSaved});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Pilihan pengguna
  Activity _aktivitas = Activity.semua.first;
  int _hari = 0; // 0 = hari ini sampai 6
  TimeOfDay _waktu = TimeOfDay.now();
  int _indeksKota = 0;

  // Hasil terakhir: tiga keadaan loading, hasil, atau gagal
  ActivityResult? _hasil;
  Activity? _aktivitasHasil;
  String? _keterangan;
  bool _hariJauh = false;

  // Kota dan hari pada hasil terakhir, untuk mengisi form pengingat
  _PilihanKota? _kotaHasil;
  int _hariHasil = 0;

  // true bila hasil dihitung dari data cache saat offline (F14)
  bool _dariCache = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _namaHari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  static const List<String> _namaBulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  // Jam yang dipilih dibulatkan ke jam terdekat karena data cuaca per jam.
  // Menit 30 ke atas naik ke jam berikutnya (maksimal 23). Contoh: 09.20 -> 9, 09.40 -> 10.
  int get _jamDinilai {
    final jam = _waktu.minute >= 30 ? _waktu.hour + 1 : _waktu.hour;
    return jam > 23 ? 23 : jam;
  }

  String _labelHari(int hari) {
    if (hari == 0) return 'Hari ini';
    if (hari == 1) return 'Besok';
    final tanggal = DateTime.now().add(Duration(days: hari));
    return '${_namaHari[tanggal.weekday - 1]}, ${tanggal.day} ${_namaBulan[tanggal.month - 1]}';
  }

  String _formatWaktu(TimeOfDay waktu) {
    final jam = waktu.hour.toString().padLeft(2, '0');
    final menit = waktu.minute.toString().padLeft(2, '0');
    return '$jam.$menit';
  }

  // Kota favorit (Tempat Saya), nama yang sama hanya sekali. Tidak ada kota bawaan.
  List<_PilihanKota> _daftarKota() {
    final daftar = <_PilihanKota>[];
    final sudahAda = <String>{};
    final favorit = Hive.box<FavoriteCity>('favorites');
    for (final kota in favorit.values) {
      if (!sudahAda.add(kota.name.toLowerCase())) continue;
      daftar.add(_PilihanKota(label: kota.name, nama: kota.name, lat: kota.lat, lon: kota.lon));
    }
    return daftar;
  }

  Future<void> _pilihJam() async {
    final hasil = await showTimePicker(context: context, initialTime: _waktu);
    if (hasil != null) {
      setState(() => _waktu = hasil);
    }
  }

  Future<void> _analisis() async {
    // Untuk hari ini, jam yang sudah lewat tidak berguna untuk direncanakan
    if (_hari == 0 && _jamDinilai < DateTime.now().hour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam itu sudah lewat. Pilih jam sekarang atau sesudahnya.')),
      );
      return;
    }

    final daftar = _daftarKota();
    if (daftar.isEmpty) return;
    final kota = daftar[_indeksKota < daftar.length ? _indeksKota : 0];

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1) Ambil prakiraan per jam kota ini (memakai cache bila offline)
      final data = await ApiService.getWeather(kota.lat, kota.lon);
      // 2) Nilai aktivitas pada hari dan jam terpilih dengan mesin Activity (models/activity.dart)
      final hasil = _aktivitas.analyze(data, _hari, _jamDinilai);
      if (!mounted) return;
      setState(() {
        _hasil = hasil;
        _aktivitasHasil = _aktivitas;
        _keterangan = '${_labelHari(_hari)} · ${kota.nama}';
        _hariJauh = _hari >= 3;
        _kotaHasil = kota;
        _hariHasil = _hari;
        _dariCache = data.isFromCache;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak bisa memuat cuaca. Periksa koneksi internet.';
      });
    }
  }

  // Tombol "Buat pengingat": buka form terisi dari hasil, lalu beri kabar bila tersimpan
  Future<void> _buatPengingat() async {
    final hasil = _hasil;
    final aktivitas = _aktivitasHasil;
    final kota = _kotaHasil;
    if (hasil == null || aktivitas == null || kota == null) return;

    final isian = IsianPengingat.dari(
      aktivitas: aktivitas,
      hasil: hasil,
      hari: _hariHasil,
      namaKota: kota.nama,
    );
    if (isian == null) return;

    final tersimpan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          judulAwal: isian.judul,
          kotaAwal: kota.nama,
          jenisAwal: isian.jenis,
          jamAwal: isian.jam,
          tanggalAwal: isian.tanggal,
          latAwal: kota.lat,
          lonAwal: kota.lon,
          catatanAwal: isian.catatan,
        ),
      ),
    );

    if (tersimpan == true && mounted) {
      final pindahTab = widget.onReminderSaved;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pindahTab != null
                ? 'Pengingat berhasil dibuat.'
                : 'Pengingat dibuat. Lihat di tab Pengingat.',
          ),
        ),
      );
      // Pindah ke tab Pengingat (bila Root menyediakan callback)
      pindahTab?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final daftarKota = _daftarKota();
    final indeksKota = _indeksKota < daftarKota.length ? _indeksKota : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.edge, 4, AppTheme.edge, AppTheme.edge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cek apakah cuaca cocok untuk kegiatanmu.',
              style: TextStyle(color: c.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Jenis aktivitas
                  DropdownButtonFormField<Activity>(
                    initialValue: _aktivitas,
                    isExpanded: true,
                    dropdownColor: c.bgMid,
                    style: TextStyle(color: c.text, fontSize: 15),
                    decoration: const InputDecoration(labelText: 'Aktivitas'),
                    items: [
                      for (final a in Activity.semua)
                        DropdownMenuItem(
                          value: a,
                          child: Row(
                            children: [
                              Icon(a.ikon, size: 20, color: c.accent),
                              const SizedBox(width: 10),
                              Text(a.nama),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (a) {
                      if (a != null) setState(() => _aktivitas = a);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Hari: hari ini sampai 6 hari ke depan
                  DropdownButtonFormField<int>(
                    initialValue: _hari,
                    isExpanded: true,
                    dropdownColor: c.bgMid,
                    style: TextStyle(color: c.text, fontSize: 15),
                    decoration: const InputDecoration(labelText: 'Hari'),
                    items: [
                      for (var i = 0; i < 7; i++)
                        DropdownMenuItem(value: i, child: Text(_labelHari(i))),
                    ],
                    onChanged: (i) {
                      if (i != null) setState(() => _hari = i);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Jam: pemilih jam 24 jam, dinilai pada jam terdekat
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusField),
                    onTap: _pilihJam,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Jam',
                        suffixIcon: Icon(Icons.access_time_rounded),
                      ),
                      child: Text(
                        '${_formatWaktu(_waktu)}  ·  dinilai pukul ${Activity.formatJam(_jamDinilai)}',
                        style: TextStyle(color: c.text, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kota: kota Beranda dan Tempat Saya. Bila belum ada satu pun, beri petunjuk.
                  if (daftarKota.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Belum ada kota. Tambah kota favorit di tab Kota dulu.',
                        style: TextStyle(color: c.textMuted, fontSize: 13.5),
                      ),
                    )
                  else
                  DropdownButtonFormField<int>(
                    initialValue: indeksKota,
                    isExpanded: true,
                    dropdownColor: c.bgMid,
                    style: TextStyle(color: c.text, fontSize: 15),
                    decoration: const InputDecoration(labelText: 'Kota'),
                    items: [
                      for (var i = 0; i < daftarKota.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(daftarKota[i].label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (i) {
                      if (i != null) setState(() => _indeksKota = i);
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: (_isLoading || daftarKota.isEmpty) ? null : _analisis,
                    child: const Text('Analisis'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.gap + 4),
            _buildHasil(c),
          ],
        ),
      ),
    );
  }

  // Area hasil: loading, gagal, atau kartu hasil
  Widget _buildHasil(PayunginColors c) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: c.text)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _analisis, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    final hasil = _hasil;
    final aktivitas = _aktivitasHasil;
    if (hasil == null || aktivitas == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActivityCard(
          aktivitas: aktivitas,
          hasil: hasil,
          keterangan: _keterangan ?? '',
          catatanJauh: _hariJauh,
          onBuatPengingat: _buatPengingat,
        ),
        // Penanda bila penilaian memakai data terakhir yang tersimpan (offline)
        if (_dariCache)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 16, color: c.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Memakai data terakhir yang tersimpan (offline)',
                    style: TextStyle(color: c.textMuted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
