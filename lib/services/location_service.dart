import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// Jenis galat lokasi dibedakan agar layar bisa memberi respons berbeda
enum LocationError { serviceOff, denied, deniedForever }

class LocationException implements Exception {
  final LocationError type;
  final String message;

  LocationException(this.type, this.message);

  @override
  String toString() => message;
}

// Kota tempat posisi berada, hasil reverse geocoding
class InfoKota {
  // Nama untuk ditampilkan, mis. "Sleman" atau "Yogyakarta"
  final String nama;

  // Semua nama wilayah yang mungkin cocok dengan kota favorit (sudah dinormalkan)
  final List<String> kandidat;

  const InfoKota({required this.nama, required this.kandidat});
}

// Satu kota beserta jaraknya dari posisi pengguna (untuk Favorit Terdekat)
class KotaTerdekat {
  final String nama;
  final double lat;
  final double lon;
  final double meter;

  const KotaTerdekat({
    required this.nama,
    required this.lat,
    required this.lon,
    required this.meter,
  });
}

// Layanan lokasi (F15, LBS, Modul VII). Semua method static.
// Privasi: lokasi hanya dipakai untuk mencari nama kota dan mengambil cuaca, tidak disimpan.
class LocationService {
  // Cadangan bila nama kota tidak bisa dicari: posisi dianggap "di kota itu"
  // bila jaraknya ke pusat kota tidak lebih dari ini
  static const double batasKotaMeter = 3000;

  // Menghilangkan awalan "Kota" atau "Kabupaten" dan huruf besar, agar
  // "Kota Yogyakarta" dan "Yogyakarta" dianggap sama
  static String normalkanNama(String nama) {
    var hasil = nama.trim().toLowerCase();
    for (final awalan in ['kabupaten ', 'kota administrasi ', 'kota ', 'kab. ', 'kab ']) {
      if (hasil.startsWith(awalan)) {
        hasil = hasil.substring(awalan.length).trim();
        break;
      }
    }
    return hasil;
  }

  // Mengubah bagian "address" dari Nominatim menjadi InfoKota.
  // Kota atau kabupaten diambil dari field city, town, county, municipality.
  static InfoKota? infoDariAlamat(Map<String, dynamic> alamat) {
    final kandidat = <String>[];
    String? nama;
    for (final kunci in ['city', 'town', 'county', 'municipality']) {
      final nilai = alamat[kunci];
      if (nilai is! String || nilai.trim().isEmpty) continue;
      final bersih = normalkanNama(nilai);
      if (bersih.isEmpty || kandidat.contains(bersih)) continue;
      kandidat.add(bersih);
      // Nama tampilan: nilai pertama yang ada, tanpa awalan Kota/Kabupaten
      nama ??= nilai.trim().substring(nilai.trim().length - bersih.length);
    }
    if (nama == null) return null;
    return InfoKota(nama: nama, kandidat: kandidat);
  }

  // Mencari nama kota dari koordinat lewat Nominatim (OpenStreetMap, tanpa API key).
  // Mengembalikan null bila gagal (offline, timeout, atau nama tidak ditemukan).
  static Future<InfoKota?> cariKota(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'jsonv2',
        'zoom': '10',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: {
        // Nominatim meminta aplikasi memperkenalkan diri
        'User-Agent': 'PayunginPraktikum/1.0',
        'Accept-Language': 'id',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final alamat = json['address'];
      if (alamat is! Map<String, dynamic>) return null;
      return infoDariAlamat(alamat);
    } catch (_) {
      return null;
    }
  }

  // Mencari kota di daftar yang namanya cocok dengan salah satu nama kandidat.
  // Mengembalikan indeksnya, atau null bila tidak ada yang cocok.
  static int? indeksNama(List<String> daftarNama, List<String> kandidat) {
    for (var i = 0; i < daftarNama.length; i++) {
      if (kandidat.contains(normalkanNama(daftarNama[i]))) return i;
    }
    return null;
  }

  // Empat langkah: cek layanan lokasi, cek izin, minta izin, lalu ambil posisi
  static Future<Position> getCurrent() async {
    // 1. Layanan lokasi (GPS) harus menyala
    final aktif = await Geolocator.isLocationServiceEnabled();
    if (!aktif) {
      throw LocationException(LocationError.serviceOff, 'Layanan lokasi mati');
    }

    // 2. Cek dan minta izin
    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.deniedForever) {
      throw LocationException(
        LocationError.deniedForever,
        'Izin lokasi ditolak permanen',
      );
    }
    if (izin == LocationPermission.denied) {
      throw LocationException(LocationError.denied, 'Izin lokasi ditolak');
    }

    // 3. Ambil posisi sekarang (batas waktu agar tidak menggantung)
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // Apakah izin dan layanan lokasi sudah siap, tanpa memunculkan permintaan izin.
  // Dipakai Beranda untuk mengambil posisi otomatis hanya bila pengguna sudah mengizinkan.
  static Future<bool> sudahDiizinkan() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final izin = await Geolocator.checkPermission();
      return izin == LocationPermission.whileInUse || izin == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  // Mengurutkan kota dari yang terdekat ke posisi (lat, lon) dan mengambil paling banyak
  // [maks] kota (Favorit Terdekat, F15).
  static List<KotaTerdekat> urutTerdekat(
    double lat,
    double lon,
    List<({String nama, double lat, double lon})> daftar, {
    int maks = 5,
  }) {
    final hasil = [
      for (final k in daftar)
        KotaTerdekat(
          nama: k.nama,
          lat: k.lat,
          lon: k.lon,
          meter: jarak(lat, lon, k.lat, k.lon),
        ),
    ]..sort((a, b) => a.meter.compareTo(b.meter));
    return hasil.take(maks).toList();
  }

  // Jarak dua titik dalam meter (dihitung oleh paket geolocator)
  static double jarak(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Mencari kota terdekat dari posisi (lat, lon) yang jaraknya tidak lebih dari batas.
  // Mengembalikan indeksnya pada daftar, atau null bila tidak ada kota yang cukup dekat.
  static int? indeksTerdekat(
    double lat,
    double lon,
    List<({double lat, double lon})> daftar, {
    double batasMeter = batasKotaMeter,
  }) {
    int? terdekat;
    var jarakTerdekat = double.infinity;

    for (var i = 0; i < daftar.length; i++) {
      final meter = jarak(lat, lon, daftar[i].lat, daftar[i].lon);
      if (meter <= batasMeter && meter < jarakTerdekat) {
        jarakTerdekat = meter;
        terdekat = i;
      }
    }
    return terdekat;
  }

  // Di bawah 150 m: "Kamu di sini"; di bawah 1 km: meter; selebihnya kilometer
  static String formatJarak(double meter) {
    if (meter < 150) return 'Kamu di sini';
    if (meter < 1000) return '${meter.round()} m';
    return '${(meter / 1000).toStringAsFixed(1)} km';
  }
}
