import 'package:flutter/material.dart';

import 'weather_advice.dart';

// Model data cuaca dari Open-Meteo (dipakai F2, F3, F9, F14, F15, F16).
// Pemetaan weather_code ditulis sekali di sini dan dipakai semua halaman.
class WeatherData {
  // Suhu saat ini dalam Celsius. Dibuat private agar hanya bisa diubah
  // lewat setter yang memeriksa nilainya (encapsulation).
  double _temperature;

  // Cuaca saat ini (objek "current" pada respons)
  final double feelsLike;
  final int humidity;
  final int weatherCode;
  final double windSpeed;
  final String currentTime;

  // Prakiraan per jam ("hourly"): list paralel, indeks yang sama = jam yang sama
  final List<String> hourlyTime;
  final List<double> hourlyTemp;
  final List<int> hourlyRain;
  final List<int> hourlyCode;
  // Tambahan per jam untuk Detail dan penilaian Aktivitas (F3, F7)
  final List<double> hourlyUv;
  final List<double> hourlyWind;
  final List<int> hourlyHumidity;

  // Prakiraan harian ("daily"): list paralel, indeks yang sama = hari yang sama
  final List<String> dailyTime;
  final List<int> dailyCode;
  final List<double> dailyMax;
  final List<double> dailyMin;
  final List<int> dailyRain;
  final List<double> dailyUv;
  // Tambahan harian: matahari terbit dan terbenam ("yyyy-MM-ddTHH:mm") serta jumlah hujan (mm)
  final List<String> dailySunrise;
  final List<String> dailySunset;
  final List<double> dailyPrecipSum;

  // true bila data berasal dari cache saat offline (F14)
  final bool isFromCache;

  // Waktu data cache itu terakhir diperbarui (hanya terisi bila isFromCache)
  final DateTime? cachedAt;

  // Generative constructor utama
  WeatherData({
    required this._temperature,
    required this.feelsLike,
    required this.humidity,
    required this.weatherCode,
    required this.windSpeed,
    required this.currentTime,
    required this.hourlyTime,
    required this.hourlyTemp,
    required this.hourlyRain,
    required this.hourlyCode,
    required this.hourlyUv,
    required this.hourlyWind,
    required this.hourlyHumidity,
    required this.dailyTime,
    required this.dailyCode,
    required this.dailyMax,
    required this.dailyMin,
    required this.dailyRain,
    required this.dailyUv,
    required this.dailySunrise,
    required this.dailySunset,
    required this.dailyPrecipSum,
    this.isFromCache = false,
    this.cachedAt,
  });

  // Redirecting constructor: data kosong dengan nilai awal, lewat constructor utama
  WeatherData.empty()
      : this(
          temperature: 0,
          feelsLike: 0,
          humidity: 0,
          weatherCode: 0,
          windSpeed: 0,
          currentTime: '',
          hourlyTime: const [],
          hourlyTemp: const [],
          hourlyRain: const [],
          hourlyCode: const [],
          hourlyUv: const [],
          hourlyWind: const [],
          hourlyHumidity: const [],
          dailyTime: const [],
          dailyCode: const [],
          dailyMax: const [],
          dailyMin: const [],
          dailyRain: const [],
          dailyUv: const [],
          dailySunrise: const [],
          dailySunset: const [],
          dailyPrecipSum: const [],
        );

  // Factory constructor: mengubah hasil jsonDecode menjadi objek WeatherData.
  // Nilai null pada list diganti 0 agar tidak crash.
  factory WeatherData.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
    DateTime? cachedAt,
  }) {
    // "current" wajib ada; bila tidak ada, error ditangkap oleh pemanggil
    final current = json['current'] as Map<String, dynamic>;
    final hourly = (json['hourly'] as Map<String, dynamic>?) ?? {};
    final daily = (json['daily'] as Map<String, dynamic>?) ?? {};

    return WeatherData(
      temperature: _toDouble(current['temperature_2m']),
      feelsLike: _toDouble(current['apparent_temperature']),
      humidity: _toInt(current['relative_humidity_2m']),
      weatherCode: _toInt(current['weather_code']),
      windSpeed: _toDouble(current['wind_speed_10m']),
      currentTime: (current['time'] ?? '').toString(),
      hourlyTime: _toStrings(hourly['time']),
      hourlyTemp: _toDoubles(hourly['temperature_2m']),
      hourlyRain: _toInts(hourly['precipitation_probability']),
      hourlyCode: _toInts(hourly['weather_code']),
      hourlyUv: _toDoubles(hourly['uv_index']),
      hourlyWind: _toDoubles(hourly['wind_speed_10m']),
      hourlyHumidity: _toInts(hourly['relative_humidity_2m']),
      dailyTime: _toStrings(daily['time']),
      dailyCode: _toInts(daily['weather_code']),
      dailyMax: _toDoubles(daily['temperature_2m_max']),
      dailyMin: _toDoubles(daily['temperature_2m_min']),
      dailyRain: _toInts(daily['precipitation_probability_max']),
      dailyUv: _toDoubles(daily['uv_index_max']),
      dailySunrise: _toStrings(daily['sunrise']),
      dailySunset: _toStrings(daily['sunset']),
      dailyPrecipSum: _toDoubles(daily['precipitation_sum']),
      isFromCache: fromCache,
      cachedAt: cachedAt,
    );
  }

  // ---- Suhu (encapsulation) ----

  double get tempC => _temperature;

  // Setter menolak suhu yang tidak masuk akal (di luar -90 sampai 60 derajat C)
  set tempC(double value) {
    if (value < -90 || value > 60) return;
    _temperature = value;
  }

  double get tempFahrenheit => _temperature * 9 / 5 + 32;

  // ---- Kondisi cuaca (pemetaan weather_code) ----

  String get condition => conditionOf(weatherCode);

  IconData get icon => iconOf(weatherCode);

  // Static agar bisa dipakai juga untuk kode per jam dan per hari di Detail
  static String conditionOf(int code) {
    if (code == 0) return 'Cerah';
    if (code == 1) return 'Cerah berawan';
    if (code == 2) return 'Berawan sebagian';
    if (code == 3) return 'Berawan';
    if (code == 45 || code == 48) return 'Berkabut';
    if (code >= 51 && code <= 57) return 'Gerimis';
    if (code >= 61 && code <= 67) return 'Hujan';
    if (code >= 80 && code <= 82) return 'Hujan lokal';
    if (code >= 95 && code <= 99) return 'Badai petir';
    return 'Tidak diketahui';
  }

  static IconData iconOf(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1) return Icons.wb_sunny_rounded;
    if (code == 2 || code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 57) return Icons.water_rounded;       // gerimis → ikon tetes air halus
    if (code >= 61 && code <= 67) return Icons.cloudy_snowing;      // hujan → awan + butiran hujan
    if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  // Alamat gambar ikon cuaca publik (tanpa kunci) untuk Image.network di Detail (F3).
  // Pemetaan kode cuaca ke nama ikon ditulis di sini, sekali saja.
  static String iconUrlOf(int code) =>
      'https://openweathermap.org/img/wn/${_iconName(code)}@2x.png';

  static String _iconName(int code) {
    if (code == 0) return '01d'; // cerah
    if (code == 1) return '02d'; // cerah berawan
    if (code == 2) return '03d'; // berawan sebagian
    if (code == 3) return '04d'; // berawan
    if (code == 45 || code == 48) return '50d'; // kabut
    if (code >= 51 && code <= 57) return '09d'; // gerimis
    if (code >= 61 && code <= 67) return '10d'; // hujan
    if (code >= 80 && code <= 82) return '09d'; // hujan lokal
    if (code >= 95 && code <= 99) return '11d'; // badai petir
    return '03d';
  }

  // ---- Data turunan untuk Beranda dan Skor Payung ----

  // Indeks UV maksimum hari ini (elemen pertama daftar harian)
  double get uvIndex => dailyUv.isNotEmpty ? dailyUv.first : 0;

  // Peluang hujan terbesar pada jam aktif 06.00 sampai 22.00 hari ini.
  // Dipakai untuk rumus Skor Payung (F9) dan info peluang hujan di Beranda.
  int get maxRainChance {
    if (currentTime.length < 10) return 0;
    final today = currentTime.substring(0, 10);
    var maks = 0;

    for (var i = 0; i < hourlyTime.length && i < hourlyRain.length; i++) {
      final waktu = hourlyTime[i];
      if (waktu.length < 13 || !waktu.startsWith(today)) continue;

      final jam = int.tryParse(waktu.substring(11, 13)) ?? -1;
      if (jam >= 6 && jam <= 22 && hourlyRain[i] > maks) {
        maks = hourlyRain[i];
      }
    }
    return maks;
  }

  // Skor Payung 0 sampai 100 (F9):
  // 70% dari peluang hujan terbesar + bonus kode cuaca + bonus angin, maksimal 100
  int get umbrellaScore {
    final bonusAngin = windSpeed >= 30 ? 10 : 0;
    final skor = (maxRainChance * 0.7).round() + _codeBonus(weatherCode) + bonusAngin;
    return skor > 100 ? 100 : skor;
  }

  // Saran payung dari skor; tipenya WeatherAdvice (polymorphism)
  WeatherAdvice get advice => WeatherAdvice.fromScore(umbrellaScore);

  // Bonus skor menurut kode cuaca: gerimis 10, hujan 20, badai 30
  static int _codeBonus(int code) {
    if (code >= 95 && code <= 99) return 30;
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return 20;
    if (code >= 51 && code <= 57) return 10;
    return 0;
  }

  // Cuaca ekstrem: badai petir (kode 95-99), angin >= 40 km/jam, atau UV >= 8
  bool get isExtreme =>
      (weatherCode >= 95 && weatherCode <= 99) ||
      windSpeed >= 40 ||
      uvIndex >= 8;

  // ---- Pembantu parsing: nilai null atau tipe lain diganti nilai bawaan ----

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  static int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  static List<double> _toDoubles(dynamic list) =>
      ((list as List?) ?? []).map(_toDouble).toList();

  static List<int> _toInts(dynamic list) =>
      ((list as List?) ?? []).map(_toInt).toList();

  static List<String> _toStrings(dynamic list) =>
      ((list as List?) ?? []).map((e) => e.toString()).toList();
}
