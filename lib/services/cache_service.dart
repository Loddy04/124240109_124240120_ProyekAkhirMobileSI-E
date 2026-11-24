import 'package:hive_flutter/hive_flutter.dart';

// Cache cuaca untuk mode offline (F14, Modul Hive).
// Isi box 'weather_cache' (Box<String>): JSON cuaca terakhir per kota dan waktu simpannya.
// Semua method static. Bila box belum dibuka (mis. saat tes), cache dianggap kosong.
class CacheService {
  static const String namaBox = 'weather_cache';

  // Kunci kota: koordinat dibulatkan 2 desimal (±1 km) agar posisi GPS yang
  // sedikit berbeda memakai entri yang sama dan cache tidak menumpuk.
  static String kunci(double lat, double lon) {
    return '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
  }

  static Box<String>? get _box {
    if (!Hive.isBoxOpen(namaBox)) return null;
    return Hive.box<String>(namaBox);
  }

  // Simpan JSON cuaca beserta waktu penyimpanan. Kegagalan menyimpan tidak boleh
  // mengganggu tampilan cuaca, jadi galatnya diabaikan.
  static Future<void> save(String key, String json) async {
    final box = _box;
    if (box == null) return;
    try {
      await box.put(key, json);
      await box.put('$key:time', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // JSON cuaca terakhir untuk kota ini, atau null bila belum pernah disimpan
  static String? read(String key) {
    return _box?.get(key);
  }

  // Waktu cuaca itu disimpan, atau null bila tidak ada atau tidak terbaca
  static DateTime? readTime(String key) {
    final teks = _box?.get('$key:time');
    if (teks == null) return null;
    return DateTime.tryParse(teks);
  }
}
