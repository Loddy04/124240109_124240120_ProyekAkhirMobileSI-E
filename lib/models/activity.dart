import 'package:flutter/material.dart';

import 'weather_data.dart';

// Mesin penilaian Aktivitas (F7): sistem rekomendasi berbasis aturan (rule-based).
// Menilai apakah cuaca pada hari, jam, dan kota tertentu cocok untuk sebuah kegiatan.
// Tidak menyimpan apa pun; hanya menghitung dari data prakiraan per jam.
//
// Abstraction : Activity menetapkan alur penilaian yang sama untuk semua kegiatan.
// Inheritance : JemurActivity, MotorActivity, MobilActivity, OutdoorActivity.
// Polymorphism: layar cukup memakai tipe Activity; faktor dan teksnya beda tiap subclass.

// Status satu faktor: Bagus bernilai 100 poin, Sedang 50, Buruk 0
enum Status { bagus, sedang, buruk }

// Kelompok kondisi cuaca (dipetakan dari kode cuaca Open-Meteo)
enum KelasKondisi { cerah, kabut, gerimis, hujan, badai }

// Hasil penilaian satu faktor, misalnya "Peluang hujan 15% = Bagus"
class FactorResult {
  final String nama;
  final String nilaiTeks;
  final Status status;
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

  // hari: 0 = hari ini sampai 6; jam: 0 sampai 23
  ActivityResult analyze(WeatherData data, int hari, int jam) {
    final indeks = _indeks(data, hari, jam);
    final hitung = _hitung(data, indeks);
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
      final s = _hitung(data, _indeks(data, hari, j)).skor;
      if (s >= 25) adaJamAman = true;
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

  // Indeks jam pada daftar per jam: hari x 24 + jam, ditahan di dalam batas data
  int _indeks(WeatherData data, int hari, int jam) {
    final maks = data.hourlyTime.length - 1;
    if (maks < 0) return 0;
    final i = hari * 24 + jam;
    if (i < 0) return 0;
    if (i > maks) return maks;
    return i;
  }

  // Skor satu jam: jumlah (poin x bobot) / 100, lalu batas faktor penentu dan badai petir
  ({int skor, bool dibatasi, List<FactorResult> faktor}) _hitung(
    WeatherData data,
    int indeks,
  ) {
    final faktor = faktorPada(data, indeks);

    var total = 0;
    for (final f in faktor) {
      total += f.poin * f.bobot;
    }
    final mentah = (total / 100).round();

    // Batas: faktor penentu Buruk -> maksimal 40; badai petir -> maksimal 20
    var batas = 100;
    if (faktor.any((f) => f.penentu && f.status == Status.buruk)) batas = 40;
    final kode = ambil(data.hourlyCode, indeks, 0);
    if (kelasKondisi(kode) == KelasKondisi.badai && batas > 20) batas = 20;

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

  // Faktor yang makin kecil makin baik (hujan, angin, kelembapan)
  static Status rendahLebihBaik(num nilai, num bagusMaks, num sedangMaks) {
    if (nilai <= bagusMaks) return Status.bagus;
    if (nilai <= sedangMaks) return Status.sedang;
    return Status.buruk;
  }

  // Faktor yang makin besar makin baik (UV untuk menjemur)
  static Status tinggiLebihBaik(num nilai, num bagusMin, num sedangMin) {
    if (nilai >= bagusMin) return Status.bagus;
    if (nilai >= sedangMin) return Status.sedang;
    return Status.buruk;
  }

  // Kode cuaca -> kelompok kondisi
  static KelasKondisi kelasKondisi(int kode) {
    if (kode == 45 || kode == 48) return KelasKondisi.kabut;
    if (kode >= 51 && kode <= 57) return KelasKondisi.gerimis;
    if ((kode >= 61 && kode <= 67) || (kode >= 80 && kode <= 82)) {
      return KelasKondisi.hujan;
    }
    if (kode >= 95 && kode <= 99) return KelasKondisi.badai;
    return KelasKondisi.cerah;
  }

  // Faktor "Kondisi" dari tabel kondisi milik tiap aktivitas
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
