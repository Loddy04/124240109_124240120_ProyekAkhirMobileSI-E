import 'package:geolocator/geolocator.dart';

// Jenis galat lokasi dibedakan agar layar bisa memberi respons berbeda
enum LocationError { serviceOff, denied, deniedForever }

class LocationException implements Exception {
  final LocationError type;
  final String message;

  LocationException(this.type, this.message);

  @override
  String toString() => message;
}

// Layanan lokasi (F15, LBS, Modul VII). Semua method static.
// Privasi: lokasi hanya dipakai untuk mengambil cuaca dan tidak disimpan.
class LocationService {
  // Posisi dianggap "di kota itu" bila jaraknya ke pusat kota tidak lebih dari ini
  static const double batasKotaMeter = 10000;

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
