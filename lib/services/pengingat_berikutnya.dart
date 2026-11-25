import '../models/reminder.dart';

// Mencari pengingat aktif yang akan berbunyi paling dulu, untuk ditampilkan di Beranda.
// Aturannya sama dengan penjadwalan notifikasi: bila jamnya hari ini sudah lewat,
// pengingat tanpa tanggal dianggap berbunyi besok.
class PengingatBerikutnya {
  final Reminder pengingat;
  final DateTime waktu;

  const PengingatBerikutnya(this.pengingat, this.waktu);

  // Waktu berbunyi berikutnya untuk satu pengingat, atau null bila tidak akan berbunyi lagi
  static DateTime? waktuBerikutnya(Reminder r, DateTime sekarang) {
    final bagian = r.time.split(':');
    if (bagian.length != 2) return null;
    final jam = int.tryParse(bagian[0]);
    final menit = int.tryParse(bagian[1]);
    if (jam == null || menit == null) return null;

    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day, jam, menit);

    // Pengingat bertanggal: hanya sekali pada tanggal itu
    final tanggal = (!r.repeatDaily && r.date != null && r.date!.isNotEmpty)
        ? DateTime.tryParse(r.date!)
        : null;
    if (tanggal != null) {
      final waktu = DateTime(tanggal.year, tanggal.month, tanggal.day, jam, menit);
      return waktu.isAfter(sekarang) ? waktu : null;
    }

    // Harian, atau sekali tanpa tanggal: hari ini bila belum lewat, kalau sudah lewat besok
    return hariIni.isAfter(sekarang) ? hariIni : hariIni.add(const Duration(days: 1));
  }

  // Pengingat yang menyala (notifOn) dan berbunyi paling dulu; null bila tidak ada
  static PengingatBerikutnya? cari(Iterable<Reminder> daftar, DateTime sekarang) {
    PengingatBerikutnya? terdekat;
    for (final r in daftar) {
      if (!r.notifOn) continue;
      final waktu = waktuBerikutnya(r, sekarang);
      if (waktu == null) continue;
      if (terdekat == null || waktu.isBefore(terdekat.waktu)) {
        terdekat = PengingatBerikutnya(r, waktu);
      }
    }
    return terdekat;
  }

  // "Hari ini", "Besok", atau "Rab, 26 Nov"
  static String labelHari(DateTime waktu, DateTime sekarang) {
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final tujuan = DateTime(waktu.year, waktu.month, waktu.day);
    final selisih = tujuan.difference(hariIni).inDays;
    if (selisih == 0) return 'Hari ini';
    if (selisih == 1) return 'Besok';
    return '${hari[waktu.weekday - 1]}, ${waktu.day} ${bulan[waktu.month - 1]}';
  }
}
