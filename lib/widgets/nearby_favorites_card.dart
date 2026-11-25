import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

// Keadaan bagian Favorit Terdekat
enum StatusTerdekat {
  mencari, // sedang mengambil posisi
  perluIzin, // lokasi belum diizinkan atau belum diambil
  tanpaFavorit, // belum ada kota favorit
  siap, // daftar tampil
}

// Satu baris: kota, jaraknya, dan cuacanya (null selama masih dimuat atau gagal)
class ItemTerdekat {
  final KotaTerdekat kota;
  final WeatherData? cuaca;

  const ItemTerdekat(this.kota, this.cuaca);
}

// Favorit Terdekat (F15): nama, jarak, dan kondisi cuaca tiap kota.
// Hanya menampilkan data yang diberikan; Beranda yang mengambil posisi dan cuacanya.
class KartuFavoritTerdekat extends StatelessWidget {
  final StatusTerdekat status;
  final List<ItemTerdekat> daftar;
  final String satuan;
  final VoidCallback? onAktifkan;
  final void Function(KotaTerdekat kota)? onTapKota;

  const KartuFavoritTerdekat({
    super.key,
    required this.status,
    this.daftar = const [],
    this.satuan = 'C',
    this.onAktifkan,
    this.onTapKota,
  });

  String _suhu(double celsius) {
    final nilai = satuan == 'F' ? celsius * 9 / 5 + 32 : celsius;
    return '${nilai.round()}°';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.edge),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _isi(c),
      ),
    );
  }

  Widget _isi(PayunginColors c) {
    switch (status) {
      case StatusTerdekat.mencari:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              ),
              const SizedBox(width: 12),
              Text('Mencari lokasimu...', style: TextStyle(color: c.textMuted, fontSize: 13.5)),
            ],
          ),
        );

      case StatusTerdekat.perluIzin:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined, color: c.textMuted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aktifkan lokasi untuk melihat favorit terdekat.',
                  style: TextStyle(color: c.textMuted, fontSize: 13.5),
                ),
              ),
              TextButton(onPressed: onAktifkan, child: const Text('Aktifkan')),
            ],
          ),
        );

      case StatusTerdekat.tanpaFavorit:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(Icons.favorite_border_rounded, color: c.textMuted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum ada kota favorit. Tambahkan di tab Kota.',
                  style: TextStyle(color: c.textMuted, fontSize: 13.5),
                ),
              ),
            ],
          ),
        );

      case StatusTerdekat.siap:
        return Column(
          children: [
            for (var i = 0; i < daftar.length; i++) ...[
              if (i > 0) Divider(color: c.glassBorder, height: 1),
              _baris(c, daftar[i]),
            ],
          ],
        );
    }
  }

  Widget _baris(PayunginColors c, ItemTerdekat item) {
    final cuaca = item.cuaca;
    return InkWell(
      onTap: onTapKota == null ? null : () => onTapKota!(item.kota),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.favorite_rounded, color: c.favorite, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.kota.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    LocationService.formatJarak(item.kota.meter),
                    style: TextStyle(color: c.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (cuaca == null)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.textMuted),
              )
            else ...[
              Icon(cuaca.icon, color: c.accent, size: 20),
              const SizedBox(width: 6),
              Text(
                _suhu(cuaca.tempC),
                style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
