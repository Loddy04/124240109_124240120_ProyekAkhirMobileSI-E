import 'package:flutter/material.dart';

import 'weather_data.dart';

// Mesin penilaian Aktivitas (F7): sistem rekomendasi berbasis aturan (rule-based).
// Menilai apakah cuaca pada hari, jam, dan kota tertentu cocok untuk sebuah kegiatan.
// Tidak menyimpan apa pun; hanya menghitung dari data prakiraan per jam.
//
// Abstraction : Activity menetapkan alur penilaian yang sama untuk semua kegiatan.
// Inheritance : JemurActivity, MotorActivity, MobilActivity, OutdoorActivity.
// Polymorphism: layar cukup memakai tipe Activity; faktor dan teksnya beda tiap subclass.

// ===========================================================================
// CARA KERJA PENILAIAN (baca ini dulu)
//
// Pertanyaan yang dijawab: "Apakah cuaca pada jam X, hari Y, di kota Z cocok untuk kegiatan ini?"
// Jawabannya berupa SKOR 0 sampai 100, dihitung dengan langkah berikut:
//
// 1. Ambil prakiraan PER JAM dari Open-Meteo (peluang hujan, kode cuaca, UV, angin, dst).
// 2. Tiap kegiatan punya beberapa FAKTOR. Contoh Jemur pakaian: hujan, kondisi langit, UV,
//    kelembapan.
// 3. Tiap faktor diberi STATUS dari ambangnya: Bagus (100 poin), Sedang (50), Buruk (0).
//    Contoh: peluang hujan <= 20% Bagus, <= 50% Sedang, di atas itu Buruk.
// 4. Tiap faktor punya BOBOT, yaitu seberapa penting faktor itu. Jumlah bobot semua faktor
//    dalam satu kegiatan selalu 100.
// 5. Skor mentah = jumlah (poin x bobot) / 100.
// 6. Ada dua BATAS agar satu faktor fatal tidak "tertutup" oleh faktor lain yang bagus:
//    - faktor penentu (penentu: true) berstatus Buruk -> skor maksimal 40
//    - badai petir                                    -> skor maksimal 20
// 7. TINGKAT dari skor: Cocok (>= 75), Cukup (>= 50), Kurang (>= 25), Hindari (< 25).
// 8. Aplikasi juga mencari JAM LEBIH BAIK (06.00 sampai 21.00, hari yang sama).
//
// Contoh perhitungan (Jemur pakaian, besok 09.00):
//   hujan 15%  -> Bagus (100), bobot 30
//   cerah      -> Bagus (100), bobot 15
//   UV 5,75    -> Bagus (100), bobot 30
//   lembap 79% -> Sedang (50), bobot 25
//   (100x30 + 100x15 + 100x30 + 50x25) / 100 = 87,5 -> dibulatkan 88 -> Cocok
//
// Contoh batas: bila hujan 60% (Buruk dan penentu), hujan dan kondisi menjadi 0 poin, sisa
//   total 42,5 -> dibulatkan 43, tetapi dipotong batas 40 -> skor 40 -> Kurang.
// ===========================================================================

// Status satu faktor: Bagus bernilai 100 poin, Sedang 50, Buruk 0
enum Status { bagus, sedang, buruk }

// Kelompok kondisi cuaca (dipetakan dari kode cuaca Open-Meteo)
enum KelasKondisi { cerah, kabut, gerimis, hujan, badai }

// Hasil penilaian satu faktor, misalnya "Peluang hujan 15% = Bagus"
class FactorResult {
  final String nama;
  final String nilaiTeks; // nilai yang ditampilkan, mis. "15%" atau "5,8"
  final Status status;

  // Seberapa penting faktor ini dalam skor (jumlah bobot satu kegiatan = 100)
  final int bobot;

  // Faktor penentu (bertanda bintang di dokumen): bila Buruk, skor dibatasi 40
  final bool penentu;

  const FactorResult({
    required this.nama,
    required this.nilaiTeks,
    required this.status,
    required this.bobot,
    this.penentu = false,
  });

  // Status diubah menjadi angka poin: Bagus 100, Sedang 50, Buruk 0.
  // Poin dikalikan bobot saat skor dihitung (lihat Activity._hitung).
  int get poin {
    switch (status) {
      case Status.bagus:
        return 100;
      case Status.sedang:
        return 50;
      case Status.buruk:
        return 0;
    }
  }
}

// Hasil akhir sebuah analisis
class ActivityResult {
  final String namaAktivitas;
  final int skor; // 0 sampai 100
  final String tingkat; // Cocok, Cukup, Kurang, atau Hindari
  final List<FactorResult> faktor;
  final List<String> saran;
  final int jamDinilai;

  // true bila skor dibatasi faktor penentu atau badai petir
  final bool dibatasi;

  // Jam lain (06.00 sampai 21.00, hari yang sama) dengan skor lebih tinggi; null bila tidak ada
  final int? jamLebihBaik;
  final int? skorLebihBaik;

  // true bila semua jam 06.00 sampai 21.00 pada hari itu berskor di bawah 25
  final bool tidakAdaJamAman;

  const ActivityResult({
    required this.namaAktivitas,
    required this.skor,
    required this.tingkat,
    required this.faktor,
    required this.saran,
    required this.jamDinilai,
    required this.dibatasi,
    required this.jamLebihBaik,
    required this.skorLebihBaik,
    required this.tidakAdaJamAman,
  });

  // Jam yang disarankan untuk pengingat: jam yang lebih baik bila ada, kalau tidak jam yang
  // dinilai. Null bila pengingat tidak berguna (tidak ada jam aman, atau jam dinilai
  // berstatus Hindari dan tidak ada jam yang lebih baik).
  int? get jamPengingat {
    if (tidakAdaJamAman) return null;
    if (jamLebihBaik != null) return jamLebihBaik;
    return tingkat == 'Hindari' ? null : jamDinilai;
  }

  // Ringkasan satu baris, dipakai kartu pengingat dan notifikasi
  String get ringkasan =>
      '$namaAktivitas pukul ${Activity.formatJam(jamDinilai)}: $tingkat ($skor)';
}

// Kelas induk semua kegiatan. Alur penilaian (analyze) ditulis SEKALI di sini; tiap kegiatan
// (subclass) hanya mengisi bagian yang berbeda: faktor, ambang, bobot, dan kalimat saran.
// Pola ini disebut Template Method, dan layar cukup memanggil analyze() pada tipe Activity
// tanpa peduli kegiatan apa yang sedang dipilih (polimorfisme).
abstract class Activity {
  const Activity();

  // Pengenal singkat: 'jemur', 'motor', 'mobil', atau 'outdoor'
  String get type;
  String get nama;
  IconData get ikon;

  // Subclass mengisi: faktor, ambang, dan bobot untuk satu jam (indeks pada daftar per jam)
  List<FactorResult> faktorPada(WeatherData data, int indeks);

  // Subclass mengisi: kalimat rekomendasi menurut tingkat, dan saran dari faktor yang Buruk
  String teksTingkat(String tingkat);
  String? saranUntuk(FactorResult faktor);

  // Jam yang dicari untuk saran "jam lebih baik": 06.00 sampai 21.00
  static const int jamSaranAwal = 6;
  static const int jamSaranAkhir = 21;

  // Daftar semua aktivitas, untuk dropdown
  static const List<Activity> semua = [
    JemurActivity(),
    MotorActivity(),
    MobilActivity(),
    OutdoorActivity(),
  ];

  // Mencari aktivitas dari pengenalnya; null untuk 'umum' atau pengenal tak dikenal
  static Activity? fromType(String type) {
    for (final a in semua) {
      if (a.type == type) return a;
    }
    return null;
  }

  // ---- Alur penilaian (sama untuk semua aktivitas) ----

  // Menilai satu kegiatan pada hari dan jam tertentu.
  // hari: 0 = hari ini sampai 6 (tujuh hari ke depan); jam: 0 sampai 23.
  ActivityResult analyze(WeatherData data, int hari, int jam) {
    // Langkah 1: cari posisi jam itu di daftar prakiraan per jam
    final indeks = _indeks(data, hari, jam);
    // Langkah 2: hitung skor (faktor, bobot, batas penentu dan badai)
    final hitung = _hitung(data, indeks);
    // Langkah 3: ubah skor menjadi tingkat (Cocok, Cukup, Kurang, Hindari)
    final tingkat = tingkatDari(hitung.skor);

    // Saran: kalimat menurut tingkat, lalu saran dari tiap faktor yang Buruk
    final saran = <String>[teksTingkat(tingkat)];
    for (final f in hitung.faktor) {
      if (f.status == Status.buruk) {
        final s = saranUntuk(f);
        if (s != null) saran.add(s);
      }
    }

    // Jam lebih baik: skor tertinggi pada jam 06.00 sampai 21.00 di hari yang sama
    int? jamBaik;
    int? skorBaik;
    var adaJamAman = false;
    for (var j = jamSaranAwal; j <= jamSaranAkhir; j++) {
      // Skor tiap jam dari 06.00 sampai 21.00 pada hari yang sama
      final s = _hitung(data, _indeks(data, hari, j)).skor;
      // Jam dianggap aman bila skornya minimal 25 (tingkat Kurang ke atas)
      if (s >= 25) adaJamAman = true;
      // Simpan jam dengan skor tertinggi sejauh ini
      if (skorBaik == null || s > skorBaik) {
        skorBaik = s;
        jamBaik = j;
      }
    }
    // Hanya ditampilkan bila benar-benar lebih baik dari jam yang dinilai
    if (skorBaik != null && skorBaik <= hitung.skor) {
      jamBaik = null;
      skorBaik = null;
    }

    return ActivityResult(
      namaAktivitas: nama,
      skor: hitung.skor,
      tingkat: tingkat,
      faktor: hitung.faktor,
      saran: saran,
      jamDinilai: jam,
      dibatasi: hitung.dibatasi,
      jamLebihBaik: jamBaik,
      skorLebihBaik: skorBaik,
      tidakAdaJamAman: !adaJamAman,
    );
  }

  // Posisi sebuah jam di daftar prakiraan per jam.
  // Open-Meteo memberi 7 hari x 24 jam = 168 data berurutan, dimulai pukul 00.00 hari ini.
  // Jadi indeks = hari x 24 + jam. Contoh: besok (hari 1) pukul 09.00 -> 1 x 24 + 9 = 33.
  // Nilai ditahan di dalam batas data agar tidak error bila data kurang.
  int _indeks(WeatherData data, int hari, int jam) {
    final maks = data.hourlyTime.length - 1;
    if (maks < 0) return 0;
    final i = hari * 24 + jam;
    if (i < 0) return 0;
    if (i > maks) return maks;
    return i;
  }

  // Skor satu jam: jumlah (poin x bobot) / 100, lalu batas faktor penentu dan badai petir.
  // Mengembalikan skor akhir, apakah skor dipotong batas (dibatasi), dan daftar faktornya.
  ({int skor, bool dibatasi, List<FactorResult> faktor}) _hitung(
    WeatherData data,
    int indeks,
  ) {
    // Faktor dan statusnya diisi oleh subclass (beda tiap kegiatan)
    final faktor = faktorPada(data, indeks);

    // Jumlahkan poin x bobot. Contoh: Bagus (100) x bobot 30 = 3000
    var total = 0;
    for (final f in faktor) {
      total += f.poin * f.bobot;
    }
    // Dibagi 100 karena jumlah bobot = 100, hasilnya langsung skala 0 sampai 100
    final mentah = (total / 100).round();

    // Batas: faktor penentu Buruk -> maksimal 40; badai petir -> maksimal 20
    var batas = 100;
    if (faktor.any((f) => f.penentu && f.status == Status.buruk)) batas = 40;
    final kode = ambil(data.hourlyCode, indeks, 0);
    if (kelasKondisi(kode) == KelasKondisi.badai && batas > 20) batas = 20;

    // Skor akhir tidak boleh melewati batas. dibatasi = true bila skor benar-benar dipotong
    final skor = mentah > batas ? batas : mentah;
    return (skor: skor, dibatasi: skor < mentah, faktor: faktor);
  }

  // Cocok (75 ke atas), Cukup (50-74), Kurang (25-49), Hindari (di bawah 25)
  static String tingkatDari(int skor) {
    if (skor >= 75) return 'Cocok';
    if (skor >= 50) return 'Cukup';
    if (skor >= 25) return 'Kurang';
    return 'Hindari';
  }

  // ---- Pembantu untuk subclass ----

  // Ambil elemen list dengan aman; bila indeks di luar batas, pakai nilai bawaan
  static T ambil<T>(List<T> daftar, int indeks, T bawaan) =>
      indeks >= 0 && indeks < daftar.length ? daftar[indeks] : bawaan;

  // Faktor yang makin kecil makin baik (hujan, angin, kelembapan).
  // Contoh rendahLebihBaik(hujan, 20, 50): sampai 20 Bagus, 21 sampai 50 Sedang, di atas 50 Buruk.
  static Status rendahLebihBaik(num nilai, num bagusMaks, num sedangMaks) {
    if (nilai <= bagusMaks) return Status.bagus;
    if (nilai <= sedangMaks) return Status.sedang;
    return Status.buruk;
  }

  // Faktor yang makin besar makin baik (UV untuk menjemur).
  // Contoh tinggiLebihBaik(uv, 5, 3): UV 5 ke atas Bagus, 3 sampai 4,9 Sedang, di bawah 3 Buruk.
  static Status tinggiLebihBaik(num nilai, num bagusMin, num sedangMin) {
    if (nilai >= bagusMin) return Status.bagus;
    if (nilai >= sedangMin) return Status.sedang;
    return Status.buruk;
  }

  // Kode cuaca Open-Meteo (standar WMO) -> kelompok kondisi:
  // 45 dan 48 kabut; 51 sampai 57 gerimis; 61 sampai 67 dan 80 sampai 82 hujan;
  // 95 sampai 99 badai petir; kode lain (cerah, cerah berawan, berawan) dianggap cerah.
  static KelasKondisi kelasKondisi(int kode) {
    if (kode == 45 || kode == 48) return KelasKondisi.kabut;
    if (kode >= 51 && kode <= 57) return KelasKondisi.gerimis;
    if ((kode >= 61 && kode <= 67) || (kode >= 80 && kode <= 82)) {
      return KelasKondisi.hujan;
    }
    if (kode >= 95 && kode <= 99) return KelasKondisi.badai;
    return KelasKondisi.cerah;
  }

  // Faktor "Kondisi" dari tabel kondisi milik tiap aktivitas (_peta di tiap subclass):
  // kelompok kondisi -> status. Contoh Jemur: cerah Bagus, kabut Sedang, hujan Buruk.
  static FactorResult faktorKondisi(
    int kode,
    Map<KelasKondisi, Status> peta,
    int bobot, {
    bool penentu = false,
  }) {
    return FactorResult(
      nama: 'Kondisi',
      nilaiTeks: WeatherData.conditionOf(kode),
      status: peta[kelasKondisi(kode)] ?? Status.sedang,
      bobot: bobot,
      penentu: penentu,
    );
  }

  // Angka satu desimal dengan koma, contoh 5,8
  static String angka1(double nilai) => nilai.toStringAsFixed(1).replaceAll('.', ',');

  // 9 -> "09.00"
  static String formatJam(int jam) => '${jam.toString().padLeft(2, '0')}.00';
}

// ---------------------------------------------------------------------------
// Jemur pakaian: butuh kering, UV cukup, dan udara tidak lembap
// ---------------------------------------------------------------------------
class JemurActivity extends Activity {
  const JemurActivity();

  // Faktor Jemur (jumlah bobot 100):
  //   Peluang hujan 30 (PENENTU): sampai 20% Bagus, sampai 50% Sedang, di atas itu Buruk
  //   Kondisi       15          : cerah Bagus, kabut Sedang, gerimis/hujan/badai Buruk
  //   UV            30          : 5 ke atas Bagus, 3 sampai 4,9 Sedang, di bawah 3 Buruk
  //   Kelembapan    25          : sampai 65% Bagus, sampai 80% Sedang, di atas itu Buruk
  // Hujan dijadikan penentu karena sepanas apa pun, jemuran yang kehujanan basah lagi.

  static const Map<KelasKondisi, Status> _peta = {
    KelasKondisi.cerah: Status.bagus,
    KelasKondisi.kabut: Status.sedang,
    KelasKondisi.gerimis: Status.buruk,
    KelasKondisi.hujan: Status.buruk,
    KelasKondisi.badai: Status.buruk,
  };

  @override
  String get type => 'jemur';

  @override
  String get nama => 'Jemur pakaian';

  @override
  IconData get ikon => Icons.checkroom_rounded;

  @override
  List<FactorResult> faktorPada(WeatherData data, int indeks) {
    final hujan = Activity.ambil(data.hourlyRain, indeks, 0);
    final kode = Activity.ambil(data.hourlyCode, indeks, 0);
    final uv = Activity.ambil(data.hourlyUv, indeks, 0.0);
    final lembap = Activity.ambil(data.hourlyHumidity, indeks, 0);

    return [
      FactorResult(
        nama: 'Peluang hujan',
        nilaiTeks: '$hujan%',
        status: Activity.rendahLebihBaik(hujan, 20, 50),
        bobot: 30,
        penentu: true,
      ),
      Activity.faktorKondisi(kode, _peta, 15),
      FactorResult(
        nama: 'UV',
        nilaiTeks: Activity.angka1(uv),
        status: Activity.tinggiLebihBaik(uv, 5, 3),
        bobot: 30,
      ),
      FactorResult(
        nama: 'Kelembapan',
        nilaiTeks: '$lembap%',
        status: Activity.rendahLebihBaik(lembap, 65, 80),
        bobot: 25,
      ),
    ];
  }

  @override
  String teksTingkat(String tingkat) {
    switch (tingkat) {
      case 'Cocok':
        return 'Waktu yang baik untuk menjemur pakaian.';
      case 'Cukup':
        return 'Bisa menjemur, tetap pantau awan.';
      case 'Kurang':
        return 'Sebaiknya tunda atau jemur di tempat teduh.';
      default:
        return 'Jangan menjemur, cucian bisa basah lagi.';
    }
  }

  @override
  String? saranUntuk(FactorResult faktor) {
    switch (faktor.nama) {
      case 'Peluang hujan':
        return 'Siapkan penutup dan angkat jemuran bila mendung.';
      case 'Kondisi':
        return 'Cuaca tidak mendukung untuk menjemur.';
      case 'UV':
        return 'Sinar matahari lemah atau tidak ada, cucian lebih lama kering.';
      case 'Kelembapan':
        return 'Udara lembap, cucian lama kering.';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Berkendara motor: sangat terganggu hujan, kabut, dan angin kencang
// ---------------------------------------------------------------------------
class MotorActivity extends Activity {
  const MotorActivity();

  // Faktor Motor (jumlah bobot 100):
  //   Peluang hujan 40 (PENENTU): sampai 20% Bagus, sampai 50% Sedang, di atas itu Buruk
  //   Kondisi       35 (PENENTU): cerah Bagus, gerimis Sedang, kabut/hujan/badai Buruk
  //   Angin         25          : sampai 20 km/j Bagus, sampai 35 Sedang, di atas itu Buruk
  // Dua faktor penentu karena motor paling terganggu hujan dan jarak pandang.

  static const Map<KelasKondisi, Status> _peta = {
    KelasKondisi.cerah: Status.bagus,
    KelasKondisi.kabut: Status.buruk,
    KelasKondisi.gerimis: Status.sedang,
    KelasKondisi.hujan: Status.buruk,
    KelasKondisi.badai: Status.buruk,
  };

  @override
  String get type => 'motor';

  @override
  String get nama => 'Berkendara motor';

  @override
  IconData get ikon => Icons.two_wheeler_rounded;

  @override
  List<FactorResult> faktorPada(WeatherData data, int indeks) {
    final hujan = Activity.ambil(data.hourlyRain, indeks, 0);
    final kode = Activity.ambil(data.hourlyCode, indeks, 0);
    final angin = Activity.ambil(data.hourlyWind, indeks, 0.0);

    return [
      FactorResult(
        nama: 'Peluang hujan',
        nilaiTeks: '$hujan%',
        status: Activity.rendahLebihBaik(hujan, 20, 50),
        bobot: 40,
        penentu: true,
      ),
      Activity.faktorKondisi(kode, _peta, 35, penentu: true),
      FactorResult(
        nama: 'Angin',
        nilaiTeks: '${angin.round()} km/j',
        status: Activity.rendahLebihBaik(angin, 20, 35),
        bobot: 25,
      ),
    ];
  }

  @override
  String teksTingkat(String tingkat) {
    switch (tingkat) {
      case 'Cocok':
        return 'Kondisi baik untuk berkendara motor.';
      case 'Cukup':
        return 'Cukup aman, tetap waspada di jalan.';
      case 'Kurang':
        return 'Sebaiknya tunda atau siapkan jas hujan.';
      default:
        return 'Tidak disarankan berkendara motor.';
    }
  }

  @override
  String? saranUntuk(FactorResult faktor) {
    switch (faktor.nama) {
      case 'Peluang hujan':
        return 'Siapkan jas hujan dan hindari jalan licin.';
      case 'Kondisi':
        return 'Jarak pandang atau jalan bisa terganggu, kurangi kecepatan.';
      case 'Angin':
        return 'Angin kencang, waspada saat melaju.';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Berkendara mobil: lebih toleran terhadap hujan biasa
// ---------------------------------------------------------------------------
class MobilActivity extends Activity {
  const MobilActivity();

  // Faktor Mobil (jumlah bobot 100):
  //   Peluang hujan 30: sampai 40% Bagus, sampai 70% Sedang, di atas itu Buruk
  //   Kondisi       50: cerah dan gerimis Bagus, kabut dan hujan Sedang, badai Buruk
  //   Angin         20: sampai 30 km/j Bagus, sampai 50 Sedang, di atas itu Buruk
  // Tidak ada faktor penentu karena mobil lebih toleran; hanya badai petir yang membatasi skor.

  static const Map<KelasKondisi, Status> _peta = {
    KelasKondisi.cerah: Status.bagus,
    KelasKondisi.kabut: Status.sedang,
    KelasKondisi.gerimis: Status.bagus,
    KelasKondisi.hujan: Status.sedang,
    KelasKondisi.badai: Status.buruk,
  };

  @override
  String get type => 'mobil';

  @override
  String get nama => 'Berkendara mobil';

  @override
  IconData get ikon => Icons.directions_car_rounded;

  @override
  List<FactorResult> faktorPada(WeatherData data, int indeks) {
    final hujan = Activity.ambil(data.hourlyRain, indeks, 0);
    final kode = Activity.ambil(data.hourlyCode, indeks, 0);
    final angin = Activity.ambil(data.hourlyWind, indeks, 0.0);

    return [
      FactorResult(
        nama: 'Peluang hujan',
        nilaiTeks: '$hujan%',
        status: Activity.rendahLebihBaik(hujan, 40, 70),
        bobot: 30,
      ),
      Activity.faktorKondisi(kode, _peta, 50),
      FactorResult(
        nama: 'Angin',
        nilaiTeks: '${angin.round()} km/j',
        status: Activity.rendahLebihBaik(angin, 30, 50),
        bobot: 20,
      ),
    ];
  }

  @override
  String teksTingkat(String tingkat) {
    switch (tingkat) {
      case 'Cocok':
        return 'Kondisi baik untuk berkendara.';
      case 'Cukup':
        return 'Cukup aman, perhatikan jarak pandang.';
      case 'Kurang':
        return 'Berkendaralah dengan hati-hati.';
      default:
        return 'Sebaiknya tunda perjalanan bila bisa.';
    }
  }

  @override
  String? saranUntuk(FactorResult faktor) {
    switch (faktor.nama) {
      case 'Peluang hujan':
        return 'Nyalakan lampu dan jaga jarak aman.';
      case 'Kondisi':
        return 'Kurangi kecepatan, jarak pandang terbatas.';
      case 'Angin':
        return 'Angin kencang, waspada terutama di jalan terbuka.';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Aktivitas outdoor: hujan, suhu, dan UV menentukan kenyamanan
// ---------------------------------------------------------------------------
class OutdoorActivity extends Activity {
  const OutdoorActivity();

  // Faktor Outdoor (jumlah bobot 100):
  //   Peluang hujan 30 (PENENTU): sampai 20% Bagus, sampai 50% Sedang, di atas itu Buruk
  //   Kondisi       20 (PENENTU): cerah Bagus, kabut dan gerimis Sedang, hujan/badai Buruk
  //   Suhu          30          : 22 sampai 30 Bagus, 18 sampai 21 atau 31 sampai 34 Sedang,
  //                               di bawah 18 atau 35 ke atas Buruk
  //   UV            20          : sampai 5 Bagus, 6 sampai 7 Sedang, 8 ke atas Buruk

  static const Map<KelasKondisi, Status> _peta = {
    KelasKondisi.cerah: Status.bagus,
    KelasKondisi.kabut: Status.sedang,
    KelasKondisi.gerimis: Status.sedang,
    KelasKondisi.hujan: Status.buruk,
    KelasKondisi.badai: Status.buruk,
  };

  @override
  String get type => 'outdoor';

  @override
  String get nama => 'Aktivitas outdoor';

  @override
  IconData get ikon => Icons.directions_run_rounded;

  // Suhu: Bagus 22-30, Sedang 18-21 atau 31-34, Buruk di bawah 18 atau 35 ke atas
  Status _statusSuhu(double suhu) {
    if (suhu >= 22 && suhu <= 30) return Status.bagus;
    if (suhu < 18 || suhu >= 35) return Status.buruk;
    return Status.sedang;
  }

  @override
  List<FactorResult> faktorPada(WeatherData data, int indeks) {
    final hujan = Activity.ambil(data.hourlyRain, indeks, 0);
    final kode = Activity.ambil(data.hourlyCode, indeks, 0);
    final suhu = Activity.ambil(data.hourlyTemp, indeks, 26.0);
    final uv = Activity.ambil(data.hourlyUv, indeks, 0.0);

    return [
      FactorResult(
        nama: 'Peluang hujan',
        nilaiTeks: '$hujan%',
        status: Activity.rendahLebihBaik(hujan, 20, 50),
        bobot: 30,
        penentu: true,
      ),
      Activity.faktorKondisi(kode, _peta, 20, penentu: true),
      FactorResult(
        nama: 'Suhu',
        nilaiTeks: '${suhu.round()}°C',
        status: _statusSuhu(suhu),
        bobot: 30,
      ),
      FactorResult(
        nama: 'UV',
        nilaiTeks: Activity.angka1(uv),
        // UV: Bagus sampai 5, Sedang 6-7, Buruk 8 ke atas
        status: Activity.rendahLebihBaik(uv, 5, 7.99),
        bobot: 20,
      ),
    ];
  }

  @override
  String teksTingkat(String tingkat) {
    switch (tingkat) {
      case 'Cocok':
        return 'Waktu yang baik untuk beraktivitas di luar.';
      case 'Cukup':
        return 'Bisa beraktivitas, siapkan perlengkapan.';
      case 'Kurang':
        return 'Sebaiknya pindah ke dalam ruangan atau tunda.';
      default:
        return 'Tidak disarankan beraktivitas di luar.';
    }
  }

  @override
  String? saranUntuk(FactorResult faktor) {
    switch (faktor.nama) {
      case 'Peluang hujan':
        return 'Siapkan jas hujan atau tempat berteduh.';
      case 'Kondisi':
        return 'Cuaca tidak mendukung kegiatan di luar.';
      case 'Suhu':
        return 'Suhu kurang nyaman, atur pakaian dan bawa minum.';
      case 'UV':
        return 'UV tinggi, pakai tabir surya dan topi.';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Isian awal form Pengingat dari hasil Aktivitas (PBI-087). Murni data, tanpa layar,
// sehingga mudah diuji.
class IsianPengingat {
  final String judul;
  final String jam; // "HH:mm"
  final DateTime tanggal;
  final String catatan;
  final String jenis; // 'jemur', 'motor', 'mobil', atau 'outdoor'

  const IsianPengingat({
    required this.judul,
    required this.jam,
    required this.tanggal,
    required this.catatan,
    required this.jenis,
  });

  // Null bila pengingat tidak berguna (lihat ActivityResult.jamPengingat).
  // hari: 0 = hari ini sampai 6. sekarang hanya diisi saat tes.
  static IsianPengingat? dari({
    required Activity aktivitas,
    required ActivityResult hasil,
    required int hari,
    required String namaKota,
    DateTime? sekarang,
  }) {
    final jamPilihan = hasil.jamPengingat;
    if (jamPilihan == null) return null;

    final now = sekarang ?? DateTime.now();
    final tanggal = DateTime(now.year, now.month, now.day).add(Duration(days: hari));

    // Skor pada jam yang dipilih: jam lebih baik memakai skornya sendiri
    final lebihBaik = hasil.jamLebihBaik != null && jamPilihan == hasil.jamLebihBaik;
    final skor = lebihBaik ? (hasil.skorLebihBaik ?? hasil.skor) : hasil.skor;

    return IsianPengingat(
      judul: '${aktivitas.nama} · $namaKota',
      jam: '${jamPilihan.toString().padLeft(2, '0')}:00',
      tanggal: tanggal,
      catatan: 'Skor ${Activity.tingkatDari(skor)} ($skor) pada pukul ${Activity.formatJam(jamPilihan)}.',
      jenis: aktivitas.type,
    );
  }
}
