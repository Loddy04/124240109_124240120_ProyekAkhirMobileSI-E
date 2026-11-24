import 'package:flutter_test/flutter_test.dart';
import 'package:payungin/models/activity.dart';
import 'package:payungin/models/weather_data.dart';

// Tes mesin penilaian Aktivitas (F7) tanpa internet.
// Angka diambil dari contoh hitungan di Dokumen Final (data asli Yogyakarta, November 2026).

typedef Jam = ({int hujan, int kode, double uv, int lembap, double angin, double suhu});

// Membuat 7 hari data per jam (168 jam) dengan nilai bawaan, lalu menimpa jam tertentu.
// Nilai bawaan: cerah, tanpa hujan, UV 0 (malam), lembap 50%, angin 5 km/j, suhu 26 C.
WeatherData buatData(Map<int, Jam> jamKhusus) {
  const bawaan = (hujan: 0, kode: 0, uv: 0.0, lembap: 50, angin: 5.0, suhu: 26.0);
  final jam = List<Jam>.generate(168, (i) => jamKhusus[i] ?? bawaan);

  return WeatherData(
    temperature: 28,
    feelsLike: 30,
    humidity: 70,
    weatherCode: 0,
    windSpeed: 5,
    currentTime: '2026-11-16T10:00',
    hourlyTime: List.generate(168, (i) => '2026-11-16T${(i % 24).toString().padLeft(2, '0')}:00'),
    hourlyTemp: jam.map((j) => j.suhu).toList(),
    hourlyRain: jam.map((j) => j.hujan).toList(),
    hourlyCode: jam.map((j) => j.kode).toList(),
    hourlyUv: jam.map((j) => j.uv).toList(),
    hourlyWind: jam.map((j) => j.angin).toList(),
    hourlyHumidity: jam.map((j) => j.lembap).toList(),
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
}

// Indeks jam: hari x 24 + jam
int idx(int hari, int jam) => hari * 24 + jam;

void main() {
  const jemur = JemurActivity();

  group('Jemur pakaian (contoh di dokumen)', () {
    test('besok 09.00: hujan 15%, cerah, UV 5,75, lembap 79% -> 88 Cocok', () {
      final data = buatData({
        idx(1, 9): (hujan: 15, kode: 3, uv: 5.75, lembap: 79, angin: 3.0, suhu: 28.8),
      });
      final hasil = jemur.analyze(data, 1, 9);
      expect(hasil.skor, 88);
      expect(hasil.tingkat, 'Cocok');
      expect(hasil.dibatasi, isFalse);
      expect(hasil.faktor.length, 4);
    });

    test('hari ini 09.00: hujan 60%, gerimis -> 42,5 dibatasi faktor penentu jadi 40 Kurang', () {
      final data = buatData({
        idx(0, 9): (hujan: 60, kode: 51, uv: 5.55, lembap: 80, angin: 6.3, suhu: 29.0),
      });
      final hasil = jemur.analyze(data, 0, 9);
      expect(hasil.skor, 40);
      expect(hasil.tingkat, 'Kurang');
      expect(hasil.dibatasi, isTrue);
    });

    test('besok 15.00: hujan 100%, gerimis, UV 3,5, lembap 81% -> 15 Hindari', () {
      final data = buatData({
        idx(1, 15): (hujan: 100, kode: 51, uv: 3.5, lembap: 81, angin: 3.4, suhu: 28.0),
      });
      final hasil = jemur.analyze(data, 1, 15);
      expect(hasil.skor, 15);
      expect(hasil.tingkat, 'Hindari');
    });
  });

  test('jam yang sama, empat aktivitas menghasilkan penilaian berbeda', () {
    // Besok 12.00: hujan 80%, gerimis, UV 6,8, lembap 77%, angin 5,9 km/j, suhu 29,4
    final data = buatData({
      idx(1, 12): (hujan: 80, kode: 51, uv: 6.8, lembap: 77, angin: 5.9, suhu: 29.4),
    });
    expect(const JemurActivity().analyze(data, 1, 12).skor, 40);
    expect(const MotorActivity().analyze(data, 1, 12).skor, 40);
    expect(const OutdoorActivity().analyze(data, 1, 12).skor, 40);

    final mobil = const MobilActivity().analyze(data, 1, 12);
    expect(mobil.skor, 70);
    expect(mobil.tingkat, 'Cukup');
  });

  test('badai petir membatasi skor maksimal 20 untuk semua aktivitas', () {
    // Selain badai, faktor mobil sebenarnya baik (hujan 0%, angin 5 km/j)
    final data = buatData({
      idx(0, 10): (hujan: 0, kode: 95, uv: 6.0, lembap: 50, angin: 5.0, suhu: 26.0),
    });
    for (final a in Activity.semua) {
      final hasil = a.analyze(data, 0, 10);
      expect(hasil.skor <= 20, isTrue, reason: '${a.nama} harus dibatasi 20');
      expect(hasil.dibatasi, isTrue);
    }
  });

  group('Jam yang lebih baik', () {
    test('mencari jam terbaik hanya pada 06.00 sampai 21.00', () {
      final data = buatData({
        idx(1, 9): (hujan: 15, kode: 3, uv: 5.75, lembap: 79, angin: 3.0, suhu: 28.8), // 88
        idx(1, 15): (hujan: 100, kode: 51, uv: 3.5, lembap: 81, angin: 3.4, suhu: 28.0), // 15
        idx(1, 3): (hujan: 0, kode: 0, uv: 8.0, lembap: 50, angin: 2.0, suhu: 24.0), // 100, jam 03.00
      });
      final hasil = jemur.analyze(data, 1, 15);
      expect(hasil.jamLebihBaik, 9, reason: 'jam 03.00 berskor 100 tetapi di luar 06.00-21.00');
      expect(hasil.skorLebihBaik, 88);
    });

    test('tidak ada saran bila jam yang dinilai sudah yang terbaik', () {
      final data = buatData({
        idx(1, 9): (hujan: 15, kode: 3, uv: 5.75, lembap: 79, angin: 3.0, suhu: 28.8), // 88
      });
      final hasil = jemur.analyze(data, 1, 9);
      expect(hasil.jamLebihBaik, isNull);
    });

    test('tidak ada jam aman bila semua jam 06.00-21.00 berskor di bawah 25', () {
      final hujanSeharian = <int, Jam>{
        for (var j = 0; j < 24; j++)
          idx(2, j): (hujan: 100, kode: 65, uv: 0.0, lembap: 95, angin: 5.0, suhu: 24.0),
      };
      final hasil = jemur.analyze(buatData(hujanSeharian), 2, 10);
      expect(hasil.tidakAdaJamAman, isTrue);
    });
  });

  group('Daftar dan pencarian aktivitas', () {
    test('ada empat aktivitas dan fromType mengenalinya', () {
      expect(Activity.semua.length, 4);
      expect(Activity.fromType('jemur'), isA<JemurActivity>());
      expect(Activity.fromType('motor'), isA<MotorActivity>());
      expect(Activity.fromType('mobil'), isA<MobilActivity>());
      expect(Activity.fromType('outdoor'), isA<OutdoorActivity>());
    });

    test("fromType('umum') dan pengenal asing menghasilkan null", () {
      expect(Activity.fromType('umum'), isNull);
      expect(Activity.fromType('lainnya'), isNull);
    });
  });

  test('indeks di luar data ditahan, tidak crash', () {
    final data = buatData({});
    expect(() => jemur.analyze(data, 6, 23), returnsNormally);
    expect(() => jemur.analyze(data, 9, 23), returnsNormally);
  });

  test('ringkasan memuat nama, jam, tingkat, dan skor', () {
    final data = buatData({
      idx(1, 9): (hujan: 15, kode: 3, uv: 5.75, lembap: 79, angin: 3.0, suhu: 28.8),
    });
    expect(jemur.analyze(data, 1, 9).ringkasan, 'Jemur pakaian pukul 09.00: Cocok (88)');
  });
}
