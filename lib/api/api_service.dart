import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/city_result.dart';
import '../models/weather_data.dart';

// Layanan pengambilan data dari internet (Open-Meteo, tanpa API key).
// Semua method static agar bisa dipanggil tanpa membuat objek: ApiService.getWeather(...)
class ApiService {
  // Tiga fase data (Modul V): Fetch (http.get), Parse (jsonDecode lalu fromJson),
  // Render (dilakukan oleh layar yang memanggil).
  static Future<WeatherData> getWeather(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m',
      // Per jam: tambahan uv_index, angin, dan kelembapan untuk Detail dan Aktivitas (F3, F7)
      'hourly':
          'temperature_2m,precipitation_probability,weather_code,uv_index,wind_speed_10m,relative_humidity_2m',
      // Harian: tambahan matahari terbit dan terbenam serta jumlah hujan (F2, F3)
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,sunrise,sunset,precipitation_sum',
      'timezone': 'auto',
    });

    try {
      // Fetch: batas waktu 10 detik agar loading tidak menggantung
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      // Parse: teks JSON -> Map -> objek WeatherData
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return WeatherData.fromJson(json);
    } catch (e) {
      // F14 (Sprint 4): di sini nanti membaca cache terakhir sebelum melempar error
      throw Exception('Gagal mengambil data cuaca: $e');
    }
  }

  // Cari kota dari nama yang diketik (F4). Hasil kosong bila kota tidak ditemukan.
  static Future<List<CityResult>> searchCity(String query) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query.trim(),
      'count': '10',
      'language': 'id',
      // Hanya kota di Indonesia
      'countryCode': 'ID',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Bila tidak ada hasil, kunci "results" tidak ada, jadi dianggap list kosong
      final hasil = (json['results'] as List?) ?? [];
      final daftar = hasil
          .map((e) => CityResult.fromJson(e as Map<String, dynamic>))
          .toList();

      // Buang duplikat dengan nama dan provinsi sama agar kartu tidak kembar
      final sudahAda = <String>{};
      return daftar
          .where((k) => sudahAda.add('${k.name}|${k.province}'.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Gagal mencari kota: $e');
    }
  }
}
