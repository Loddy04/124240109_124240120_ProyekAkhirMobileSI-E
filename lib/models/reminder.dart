import 'package:hive/hive.dart';

part 'reminder.g.dart';

// Model Pengingat Cuaca dengan typeId 0 sesuai Dokumen Final Bagian 8
@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String cityName;

  @HiveField(2)
  double lat;

  @HiveField(3)
  double lon;

  @HiveField(4)
  String time; // Format string "HH:mm"

  @HiveField(5)
  String note;

  // Nilai default false agar kompatibel dengan data lama
  @HiveField(6, defaultValue: false)
  bool notifOn;

  @HiveField(7, defaultValue: false)
  bool repeatDaily;

  // Tanggal pengingat (opsional, null = sesuai repeatDaily logika).
  // Disimpan sebagai "yyyy-MM-dd" string agar kompatibel Hive.
  // Null berarti: jika repeatDaily=true→setiap hari; jika false→besok/hari ini.
  @HiveField(8, defaultValue: null)
  String? date;

  Reminder({
    required this.title,
    required this.cityName,
    required this.lat,
    required this.lon,
    required this.time,
    required this.note,
    this.notifOn = false,
    this.repeatDaily = false,
    this.date,
  });

  // Helper: kembalikan DateTime tanggal pengingat (atau null jika tidak diisi)
  DateTime? get dateTime {
    if (date == null || date!.isEmpty) return null;
    return DateTime.tryParse(date!);
  }
}


