import 'package:flutter/material.dart';

import 'weather_data.dart';

// Model data kota populer Indonesia untuk fitur Kota dan Favorit
class PopularCity {
  final String name;
  final String province;
  final double lat;
  final double lon;

  const PopularCity({
    required this.name,
    required this.province,
    required this.lat,
    required this.lon,
  });
}

// Pembantu klasifikasi suhu meteorologis yang adaptif terhadap tema (terang/gelap)
class WeatherCategoryHelper {
  // Warna ikon berbasis KONDISI CUACA (weather code), bukan suhu.
  // Konsisten dengan gradien kartu: Cerah=biru, Berawan=abu, Hujan=slate, Badai=ungu.
  static Color weatherIconColor(int weatherCode, bool isDark) {
    if (weatherCode == 0) {
      // Cerah → kuning hangat / biru golden
      return isDark ? const Color(0xFFFDD663) : const Color(0xFFE8A000);
    } else if (weatherCode == 1 || weatherCode == 2) {
      // Cerah berawan → biru soft
      return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2);
    } else if (weatherCode == 3 || weatherCode == 45 || weatherCode == 48) {
      // Berawan / berkabut → abu-abu biru
      return isDark ? const Color(0xFFB0BEC5) : const Color(0xFF607D8B);
    } else if (weatherCode >= 51 && weatherCode <= 57) {
      // Gerimis → biru teal muda
      return isDark ? const Color(0xFF80DEEA) : const Color(0xFF0097A7);
    } else if (weatherCode >= 61 && weatherCode <= 82) {
      // Hujan → biru slate
      return isDark ? const Color(0xFF82B1FF) : const Color(0xFF1565C0);
    } else if (weatherCode >= 95 && weatherCode <= 99) {
      // Badai petir → ungu
      return isDark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
    }
    return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);
  }

  // Warna aksen suhu: Sejuk (<25°C), Hangat (25-30°C), Panas (>=31°C)
  // Dipertahankan untuk keperluan lain jika dibutuhkan.
  static Color tempColor(double temp, bool isDark) {
    if (temp >= 31) {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
    } else if (temp >= 25) {
      return isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00796B);
    } else {
      return isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD);
    }
  }

  static String tempCategory(double temp) {
    if (temp >= 31) return 'Panas';
    if (temp >= 25) return 'Hangat';
    return 'Sejuk';
  }

  // Gradien cuaca atmosferik adaptif terhadap mode terang/gelap (tidak nabrak)
  static LinearGradient atmosphericGradient(WeatherData? weather, bool isDark) {
    if (weather == null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1E2D4A), Color(0xFF131D33)]
            : const [Color(0xFF3B68B5), Color(0xFF285098)],
      );
    }

    final code = weather.weatherCode;

    // 1. Cerah (kode 0)
    if (code == 0) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF104A8E), Color(0xFF0D3261), Color(0xFF092040)]
            : const [Color(0xFF2180E8), Color(0xFF1E70CF), Color(0xFF3892F3)],
      );
    }

    // 2. Cerah Berawan / Berawan Sebagian (kode 1-2)
    if (code == 1 || code == 2) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1E3A5F), Color(0xFF162A45), Color(0xFF0F1D30)]
            : const [Color(0xFF3A7BC8), Color(0xFF4E8CD4), Color(0xFF679EE0)],
      );
    }

    // 3. Berawan Penuh / Kabut (kode 3, 45, 48)
    if (code == 3 || code == 45 || code == 48) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF2C394B), Color(0xFF1F2837), Color(0xFF151C26)]
            : const [Color(0xFF506882), Color(0xFF627B97), Color(0xFF758EAA)],
      );
    }

    // 4. Gerimis / Hujan (kode 51-67, 80-82)
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1A3254), Color(0xFF13243D), Color(0xFF0E1A2C)]
            : const [Color(0xFF2B5B84), Color(0xFF3A71A0), Color(0xFF4A84B3)],
      );
    }

    // 5. Badai Petir (kode 95-99)
    if (code >= 95 && code <= 99) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF2B1B47), Color(0xFF1C1130), Color(0xFF120B1F)]
            : const [Color(0xFF4A346E), Color(0xFF583F83), Color(0xFF694C9C)],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF1B2838), Color(0xFF111A24)]
          : const [Color(0xFF385573), Color(0xFF4A6B8E)],
    );
  }
}

// Daftar 20 kota populer di Indonesia
const List<PopularCity> popularCities = [
  PopularCity(name: 'Jakarta', province: 'DKI Jakarta', lat: -6.2088, lon: 106.8456),
  PopularCity(name: 'Bandung', province: 'Jawa Barat', lat: -6.9175, lon: 107.6191),
  PopularCity(name: 'Yogyakarta', province: 'D.I. Yogyakarta', lat: -7.7956, lon: 110.3695),
  PopularCity(name: 'Sleman', province: 'D.I. Yogyakarta', lat: -7.7171, lon: 110.3549),
  PopularCity(name: 'Solo', province: 'Jawa Tengah', lat: -7.5755, lon: 110.8243),
  PopularCity(name: 'Semarang', province: 'Jawa Tengah', lat: -6.9932, lon: 110.4203),
  PopularCity(name: 'Surabaya', province: 'Jawa Timur', lat: -7.2575, lon: 112.7521),
  PopularCity(name: 'Malang', province: 'Jawa Timur', lat: -7.9797, lon: 112.6304),
  PopularCity(name: 'Denpasar', province: 'Bali', lat: -8.6705, lon: 115.2126),
  PopularCity(name: 'Medan', province: 'Sumatera Utara', lat: 3.5952, lon: 98.6722),
  PopularCity(name: 'Makassar', province: 'Sulawesi Selatan', lat: -5.1477, lon: 119.4327),
  PopularCity(name: 'Palembang', province: 'Sumatera Selatan', lat: -2.9761, lon: 104.7754),
  PopularCity(name: 'Pekanbaru', province: 'Riau', lat: 0.5071, lon: 101.4478),
  PopularCity(name: 'Batam', province: 'Kepulauan Riau', lat: 1.1301, lon: 104.0529),
  PopularCity(name: 'Balikpapan', province: 'Kalimantan Timur', lat: -1.2654, lon: 116.8312),
  PopularCity(name: 'Pontianak', province: 'Kalimantan Barat', lat: -0.0263, lon: 109.3425),
  PopularCity(name: 'Manado', province: 'Sulawesi Utara', lat: 1.4748, lon: 124.8421),
  PopularCity(name: 'Kupang', province: 'Nusa Tenggara Timur', lat: -10.1718, lon: 123.6075),
  PopularCity(name: 'Jayapura', province: 'Papua', lat: -2.5916, lon: 140.6690),
  PopularCity(name: 'Aceh', province: 'Aceh', lat: 5.5483, lon: 95.3238),
];
