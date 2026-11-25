import 'package:flutter_test/flutter_test.dart';
import 'package:payungin/models/reminder.dart';
import 'package:payungin/services/location_service.dart';
import 'package:payungin/services/pengingat_berikutnya.dart';

// Tes logika bagian tambahan Beranda: Favorit Terdekat dan pengingat berikutnya.

typedef Kota = ({String nama, double lat, double lon});

Reminder pengingat({
  String jam = '07:00',
  bool aktif = true,
  bool harian = false,
  String? tanggal,
  String judul = 'Tes',
}) {
  return Reminder(
    title: judul,
    cityName: '',
    lat: 0,
    lon: 0,
    time: jam,
    note: '',
    notifOn: aktif,
    repeatDaily: harian,
    date: tanggal,
  );
}

void main() {
  group('urutTerdekat (Favorit Terdekat)', () {
    const sleman = (nama: 'Sleman', lat: -7.7171, lon: 110.3549);
    const yogya = (nama: 'Yogyakarta', lat: -7.7956, lon: 110.3695);
    const semarang = (nama: 'Semarang', lat: -6.9667, lon: 110.4167);
    const jakarta = (nama: 'Jakarta', lat: -6.2088, lon: 106.8456);
    const bandung = (nama: 'Bandung', lat: -6.9175, lon: 107.6191);
    const surabaya = (nama: 'Surabaya', lat: -7.2575, lon: 112.7521);
    const bali = (nama: 'Denpasar', lat: -8.65, lon: 115.2167);

    test('diurutkan dari yang terdekat', () {
      final hasil = LocationService.urutTerdekat(
        -7.72, 110.35, <Kota>[jakarta, yogya, semarang, sleman],
      );
      expect(
        [for (final k in hasil) k.nama],
        ['Sleman', 'Yogyakarta', 'Semarang', 'Jakarta'],
      );
    });

    test('maksimal 5 kota', () {
      final hasil = LocationService.urutTerdekat(
        -7.72, 110.35,
        <Kota>[sleman, yogya, semarang, jakarta, bandung, surabaya, bali],
      );
      expect(hasil.length, 5);
      expect(hasil.first.nama, 'Sleman');
      // Denpasar paling jauh sehingga tidak ikut
      expect(hasil.any((k) => k.nama == 'Denpasar'), isFalse);
    });

    test('kurang dari 5 favorit: semuanya tampil', () {
      final hasil = LocationService.urutTerdekat(-7.72, 110.35, <Kota>[yogya, sleman]);
      expect(hasil.length, 2);
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(LocationService.urutTerdekat(-7.72, 110.35, const <Kota>[]), isEmpty);
    });

    test('jarak terisi dan makin jauh makin besar', () {
      final hasil = LocationService.urutTerdekat(-7.72, 110.35, <Kota>[yogya, sleman]);
      expect(hasil[0].meter, lessThan(hasil[1].meter));
      expect(hasil[0].meter, lessThan(1000));
    });
  });

  group('PengingatBerikutnya', () {
    final sekarang = DateTime(2026, 11, 25, 10, 0);

    test('tidak ada pengingat menghasilkan null', () {
      expect(PengingatBerikutnya.cari(const [], sekarang), isNull);
    });

    test('pengingat yang tidak menyala diabaikan', () {
      final r = pengingat(jam: '12:00', aktif: false);
      expect(PengingatBerikutnya.cari([r], sekarang), isNull);
    });

    test('harian dengan jam yang belum lewat berbunyi hari ini', () {
      final r = pengingat(jam: '12:30', harian: true);
      final hasil = PengingatBerikutnya.cari([r], sekarang)!;
      expect(hasil.waktu, DateTime(2026, 11, 25, 12, 30));
    });

    test('harian dengan jam yang sudah lewat berbunyi besok', () {
      final r = pengingat(jam: '07:00', harian: true);
      final hasil = PengingatBerikutnya.cari([r], sekarang)!;
      expect(hasil.waktu, DateTime(2026, 11, 26, 7, 0));
    });

    test('bertanggal di masa lalu tidak akan berbunyi lagi', () {
      final r = pengingat(jam: '07:00', tanggal: '2026-11-24');
      expect(PengingatBerikutnya.cari([r], sekarang), isNull);
    });

    test('bertanggal di masa depan berbunyi pada tanggal itu', () {
      final r = pengingat(jam: '08:15', tanggal: '2026-11-27');
      expect(
        PengingatBerikutnya.cari([r], sekarang)!.waktu,
        DateTime(2026, 11, 27, 8, 15),
      );
    });

    test('memilih yang berbunyi paling dulu', () {
      final lambat = pengingat(jam: '18:00', judul: 'Sore', tanggal: '2026-11-25');
      final cepat = pengingat(jam: '11:00', judul: 'Siang', tanggal: '2026-11-25');
      final besok = pengingat(jam: '06:00', judul: 'Besok', tanggal: '2026-11-26');
      final hasil = PengingatBerikutnya.cari([lambat, besok, cepat], sekarang)!;
      expect(hasil.pengingat.title, 'Siang');
    });

    test('jam rusak diabaikan, tidak crash', () {
      final r = pengingat(jam: 'bukan-jam', harian: true);
      expect(PengingatBerikutnya.cari([r], sekarang), isNull);
    });

    test('label hari: hari ini, besok, dan lainnya', () {
      expect(PengingatBerikutnya.labelHari(DateTime(2026, 11, 25, 15), sekarang), 'Hari ini');
      expect(PengingatBerikutnya.labelHari(DateTime(2026, 11, 26, 7), sekarang), 'Besok');
      expect(PengingatBerikutnya.labelHari(DateTime(2026, 11, 28, 7), sekarang), 'Sab, 28 Nov');
    });
  });
}
