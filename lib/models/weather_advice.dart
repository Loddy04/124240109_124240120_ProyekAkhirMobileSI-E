// Saran payung berdasarkan Skor Payung 0 sampai 100 (F9).
//
// Abstraction : WeatherAdvice menetapkan apa yang harus ada, tanpa isinya.
// Inheritance : RainAdvice, CloudyAdvice, SunnyAdvice mewarisi WeatherAdvice.
// Polymorphism: layar cukup memakai tipe WeatherAdvice; isinya berbeda per subclass.
abstract class WeatherAdvice {
  // Skor Payung (0 sampai 100)
  final int score;

  WeatherAdvice(this.score);

  // Dasar tampilan kartu saran (AdviceCard) dan isi notifikasi (F16)
  String get title;
  String get message;
  bool get needUmbrella;
  List<String> get recommendations;

  // Factory constructor: memilih subclass yang sesuai dengan skor
  factory WeatherAdvice.fromScore(int s) {
    if (s >= 60) return RainAdvice(s);
    if (s >= 30) return CloudyAdvice(s);
    return SunnyAdvice(s);
  }
}

// Skor 60 ke atas: peluang hujan tinggi
class RainAdvice extends WeatherAdvice {
  RainAdvice(super.score);

  @override
  String get title => 'Bawa payung!';

  @override
  String get message => 'Peluang hujan tinggi hari ini.';

  @override
  bool get needUmbrella => true;

  @override
  List<String> get recommendations => ['Jas hujan', 'Sepatu anti-air'];
}

// Skor 30 sampai 59: berawan, hujan mungkin turun
class CloudyAdvice extends WeatherAdvice {
  CloudyAdvice(super.score);

  @override
  String get title => 'Sedia payung lipat';

  @override
  String get message => 'Cuaca berawan, hujan mungkin turun.';

  @override
  bool get needUmbrella => false;

  @override
  List<String> get recommendations => ['Payung lipat', 'Jaket tipis'];
}

// Skor di bawah 30: kecil kemungkinan hujan
class SunnyAdvice extends WeatherAdvice {
  SunnyAdvice(super.score);

  @override
  String get title => 'Aman tanpa payung';

  @override
  String get message => 'Cuaca cerah, kecil kemungkinan hujan.';

  @override
  bool get needUmbrella => false;

  @override
  List<String> get recommendations => ['Tabir surya', 'Topi'];
}
