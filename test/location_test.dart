import 'package:flutter_test/flutter_test.dart';
import 'package:payungin/services/location_service.dart';

// Tes logika Lokasi Saya (F15) tanpa GPS: pencari kota terdekat dan format jarak.
// Koordinat pusat kota sebenarnya (derajat).

typedef Titik = ({double lat, double lon});

void main() {
  const yogyakarta = (lat: -7.79, lon: 110.36);
  const sleman = (lat: -7.7156, lon: 110.3556);
  const semarang = (lat: -6.9667, lon: 110.4167);
  const jakarta = (lat: -6.2088, lon: 106.8456);
  final daftar = <Titik>[yogyakarta, sleman, semarang, jakarta];

  group('indeksTerdekat', () {
    test('posisi di pusat kota memilih kota itu', () {
      expect(LocationService.indeksTerdekat(yogyakarta.lat, yogyakarta.lon, daftar), 0);
      expect(LocationService.indeksTerdekat(jakarta.lat, jakarta.lon, daftar), 3);
    });

    test('memilih kota yang paling dekat bila ada beberapa dalam batas', () {
      // Dekat Sleman (sekitar 1 km), sedangkan Yogyakarta sekitar 8 km (juga dalam 10 km)
      final i = LocationService.indeksTerdekat(-7.724, 110.357, daftar);
      expect(i, 1);
    });

    test('posisi jauh dari semua kota menghasilkan null (kartu sementara)', () {
      // Bandung: lebih dari 10 km dari semua kota di daftar
      expect(LocationService.indeksTerdekat(-6.92, 107.61, daftar), isNull);
    });

    test('batas jarak bisa disetel', () {
      // Semarang sekitar 90 km dari Yogyakarta: tidak cocok pada 10 km, cocok pada 150 km
      final lat = yogyakarta.lat;
      final lon = yogyakarta.lon;
      final hanyaSemarang = <Titik>[semarang];
      expect(LocationService.indeksTerdekat(lat, lon, hanyaSemarang), isNull);
      expect(
        LocationService.indeksTerdekat(lat, lon, hanyaSemarang, batasMeter: 150000),
        0,
      );
    });

    test('daftar kosong menghasilkan null', () {
      expect(LocationService.indeksTerdekat(-7.79, 110.36, const []), isNull);
    });
  });

  group('radius cadangan 3 km', () {
    test('warga Sleman (8 km dari pusat Yogyakarta) tidak lagi dianggap di Yogyakarta', () {
      final i = LocationService.indeksTerdekat(
        sleman.lat, sleman.lon, <Titik>[yogyakarta],
      );
      expect(i, isNull);
    });

    test('titik dekat UGM (sekitar 3 km) tetap dianggap di Yogyakarta', () {
      final i = LocationService.indeksTerdekat(-7.77, 110.375, <Titik>[yogyakarta]);
      expect(i, 0);
    });
  });

  group('normalkanNama', () {
    test('awalan Kota dan Kabupaten dibuang, huruf dikecilkan', () {
      expect(LocationService.normalkanNama('Kota Yogyakarta'), 'yogyakarta');
      expect(LocationService.normalkanNama('Kabupaten Sleman'), 'sleman');
      expect(LocationService.normalkanNama('Sleman'), 'sleman');
      expect(LocationService.normalkanNama('  Bantul '), 'bantul');
    });

    test('nama yang diawali kata mirip tidak ikut terpotong', () {
      expect(LocationService.normalkanNama('Kotamobagu'), 'kotamobagu');
    });
  });

  group('infoDariAlamat (hasil Nominatim)', () {
    test('Sleman kota: town dan county sama, nama Sleman', () {
      final info = LocationService.infoDariAlamat(
        {'village': 'Tridadi', 'town': 'Sleman', 'county': 'Sleman'},
      );
      expect(info!.nama, 'Sleman');
      expect(info.kandidat, ['sleman']);
    });

    test('Condongcatur: hanya county, jadi kabupaten Sleman bukan Yogyakarta', () {
      final info = LocationService.infoDariAlamat(
        {'village': 'Condongcatur', 'county': 'Sleman', 'state': 'Daerah Istimewa Yogyakarta'},
      );
      expect(info!.nama, 'Sleman');
      expect(info.kandidat, ['sleman']);
    });

    test('Kota Yogyakarta: awalan Kota dibuang dari nama tampilan', () {
      final info = LocationService.infoDariAlamat(
        {'suburb': 'Suryatmajan', 'city': 'Kota Yogyakarta', 'district': 'Depok'},
      );
      expect(info!.nama, 'Yogyakarta');
      expect(info.kandidat, ['yogyakarta']);
    });

    test('tanpa kota atau kabupaten menghasilkan null', () {
      expect(LocationService.infoDariAlamat({'state': 'Jawa Tengah'}), isNull);
      expect(LocationService.infoDariAlamat({'county': '  '}), isNull);
    });
  });

  group('indeksNama (cocokkan kota GPS dengan slider)', () {
    test('GPS di Sleman dan favorit Sleman ada: geser ke Sleman', () {
      final i = LocationService.indeksNama(
        ['Yogyakarta', 'Sleman', 'Semarang'],
        ['sleman'],
      );
      expect(i, 1);
    });

    test('nama di slider berawalan Kota tetap cocok', () {
      final i = LocationService.indeksNama(['Kota Yogyakarta'], ['yogyakarta']);
      expect(i, 0);
    });

    test('GPS di Sleman tapi hanya Yogyakarta di slider: tidak cocok (kartu sementara)', () {
      final i = LocationService.indeksNama(['Yogyakarta', 'Semarang'], ['sleman']);
      expect(i, isNull);
    });
  });

  group('jarak dan formatJarak', () {
    test('jarak Yogyakarta ke Sleman sekitar 8 km', () {
      final meter = LocationService.jarak(
        yogyakarta.lat, yogyakarta.lon, sleman.lat, sleman.lon,
      );
      expect(meter, inInclusiveRange(7000, 10000));
    });

    test('di bawah 150 m ditulis "Kamu di sini"', () {
      expect(LocationService.formatJarak(0), 'Kamu di sini');
      expect(LocationService.formatJarak(149), 'Kamu di sini');
    });

    test('di bawah 1 km ditulis dalam meter', () {
      expect(LocationService.formatJarak(150), '150 m');
      expect(LocationService.formatJarak(999), '999 m');
    });

    test('1 km ke atas ditulis dalam kilometer satu desimal', () {
      expect(LocationService.formatJarak(1000), '1.0 km');
      expect(LocationService.formatJarak(12400), '12.4 km');
    });
  });
}
