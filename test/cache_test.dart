import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:payungin/models/weather_data.dart';
import 'package:payungin/services/cache_service.dart';

// Tes cache cuaca offline (F14): simpan, baca, kunci kota, dan data dari cache.

// JSON cuaca minimal (bentuk respons Open-Meteo yang dipakai WeatherData.fromJson)
const String _jsonContoh = '''
{
  "current": {
    "time": "2026-11-24T10:00",
    "temperature_2m": 30.5,
    "apparent_temperature": 34.0,
    "relative_humidity_2m": 70,
    "weather_code": 2,
    "wind_speed_10m": 8.0
  },
  "hourly": {"time": [], "temperature_2m": [], "precipitation_probability": [],
             "weather_code": [], "uv_index": [], "wind_speed_10m": [],
             "relative_humidity_2m": []},
  "daily": {"time": [], "weather_code": [], "temperature_2m_max": [],
            "temperature_2m_min": [], "precipitation_probability_max": [],
            "uv_index_max": [], "sunrise": [], "sunset": [], "precipitation_sum": []}
}
''';

void main() {
  group('tanpa box Hive (belum dibuka)', () {
    test('read dan readTime mengembalikan null, save tidak melempar error', () async {
      expect(CacheService.read('a'), isNull);
      expect(CacheService.readTime('a'), isNull);
      await CacheService.save('a', '{}');
      expect(CacheService.read('a'), isNull);
    });
  });

  group('dengan box Hive', () {
    late Directory folder;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('payungin_cache_test');
      Hive.init(folder.path);
      await Hive.openBox<String>(CacheService.namaBox);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });

    test('data yang disimpan bisa dibaca kembali', () async {
      await CacheService.save('kota', _jsonContoh);
      expect(CacheService.read('kota'), _jsonContoh);
    });

    test('kota yang belum pernah disimpan menghasilkan null', () {
      expect(CacheService.read('belum-ada'), isNull);
      expect(CacheService.readTime('belum-ada'), isNull);
    });

    test('waktu simpan tercatat dan baru saja', () async {
      await CacheService.save('kota', _jsonContoh);
      final waktu = CacheService.readTime('kota');
      expect(waktu, isNotNull);
      expect(DateTime.now().difference(waktu!).inSeconds, lessThan(5));
    });

    test('menyimpan ulang menimpa data lama', () async {
      await CacheService.save('kota', 'lama');
      await CacheService.save('kota', 'baru');
      expect(CacheService.read('kota'), 'baru');
    });

    test('dua kota berbeda tidak tertukar', () async {
      final jogja = CacheService.kunci(-7.79, 110.36);
      final jakarta = CacheService.kunci(-6.21, 106.85);
      await CacheService.save(jogja, 'data-jogja');
      await CacheService.save(jakarta, 'data-jakarta');
      expect(CacheService.read(jogja), 'data-jogja');
      expect(CacheService.read(jakarta), 'data-jakarta');
    });
  });

  group('kunci', () {
    test('koordinat dibulatkan 2 desimal sehingga posisi berdekatan memakai kunci sama', () {
      expect(
        CacheService.kunci(-7.7901, 110.3602),
        CacheService.kunci(-7.7949, 110.3551),
      );
    });

    test('koordinat berjauhan memakai kunci berbeda', () {
      expect(
        CacheService.kunci(-7.79, 110.36),
        isNot(CacheService.kunci(-6.21, 106.85)),
      );
    });
  });

  group('WeatherData dari cache', () {
    test('tanda isFromCache dan cachedAt terisi', () {
      final waktu = DateTime(2026, 11, 24, 9, 30);
      final data = WeatherData.fromJson(
        {
          'current': {
            'time': '2026-11-24T10:00',
            'temperature_2m': 30.5,
            'apparent_temperature': 34.0,
            'relative_humidity_2m': 70,
            'weather_code': 2,
            'wind_speed_10m': 8.0,
          },
        },
        fromCache: true,
        cachedAt: waktu,
      );
      expect(data.isFromCache, isTrue);
      expect(data.cachedAt, waktu);
    });

    test('data online tidak ditandai dari cache', () {
      final data = WeatherData.fromJson({
        'current': {
          'time': '2026-11-24T10:00',
          'temperature_2m': 30.5,
          'apparent_temperature': 34.0,
          'relative_humidity_2m': 70,
          'weather_code': 2,
          'wind_speed_10m': 8.0,
        },
      });
      expect(data.isFromCache, isFalse);
      expect(data.cachedAt, isNull);
    });
  });
}
