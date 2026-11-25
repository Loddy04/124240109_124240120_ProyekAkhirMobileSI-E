import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Layanan pengaturan aplikasi (Shared Preferences) - F8 / PBI-021
// Menyediakan getter sinkron untuk Loddy dan Salsabila setelah init() dipanggil di main.dart
class SettingsService {
  static SharedPreferences? _prefs;

  // Notifier tema untuk update real-time di seluruh aplikasi (PBI-061)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  // Inisialisasi instance SharedPreferences saat aplikasi mulai
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Getter satuan suhu ('C' atau 'F'), default 'C'
  static String get unit => _prefs?.getString('tempUnit') ?? 'C';

  // Suhu Celsius -> teks sesuai satuan pilihan di Profil, dibulatkan.
  // Contoh: 30 derajat C menjadi "30°" bila satuan C, dan "86°" bila satuan F.
  static String formatSuhu(double celsius) {
    final nilai = unit == 'F' ? celsius * 9 / 5 + 32 : celsius;
    return '${nilai.round()}°';
  }

  // Getter status tema gelap, default false (tema terang)
  static bool get darkMode => _prefs?.getBool('darkMode') ?? false;

  // Apakah kota utama sudah ditentukan (dari lokasi GPS saat pertama dibuka).
  // Tidak ada kota bawaan: sebelum diatur, Beranda tidak menampilkan kota utama.
  static bool get hasMainCity => (_prefs?.getString('mainCity') ?? '').isNotEmpty;

  // Getter nama kota utama Beranda; kosong bila belum diatur (cek hasMainCity)
  static String get mainCity => _prefs?.getString('mainCity') ?? '';

  // Getter latitude kota utama. Nilai cadangan (Jakarta) hanya dipakai bila kota utama
  // belum diatur, misalnya pada form pengingat; tidak pernah ditampilkan sebagai kota utama.
  static double get mainLat => _prefs?.getDouble('mainLat') ?? -6.2088;

  // Getter longitude kota utama (cadangan Jakarta bila belum diatur)
  static double get mainLon => _prefs?.getDouble('mainLon') ?? 106.8456;

  // Getter nama lengkap pengguna, default 'Administrator Payungin'
  static String get fullName => _prefs?.getString('fullName') ?? 'Administrator Payungin';

  // Getter username pengguna aktif, default 'adminpayungin'
  static String get username => _prefs?.getString('username') ?? 'adminpayungin';

  // Setter nama lengkap pengguna (bisa diedit di profil)
  static Future<void> setFullName(String name) async {
    await _prefs?.setString('fullName', name);
  }

  // Setter satuan suhu
  static Future<void> setUnit(String newUnit) async {
    await _prefs?.setString('tempUnit', newUnit);
  }

  // Setter status tema gelap
  static Future<void> setDarkMode(bool isDark) async {
    await _prefs?.setBool('darkMode', isDark);
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Setter kota utama Beranda beserta koordinatnya
  static Future<void> setMainCity(String city, double lat, double lon) async {
    await _prefs?.setString('mainCity', city);
    await _prefs?.setDouble('mainLat', lat);
    await _prefs?.setDouble('mainLon', lon);
  }

  // Getter jalur file foto profil pengguna
  static String? get profileImagePath => _prefs?.getString('profileImagePath');

  // Setter jalur file foto profil pengguna
  static Future<void> setProfileImagePath(String? path) async {
    if (path == null) {
      await _prefs?.remove('profileImagePath');
    } else {
      await _prefs?.setString('profileImagePath', path);
    }
  }

  // ── Sesi Login (PBI-083 tambahan) ──────────────────────────────────────────

  // Simpan timestamp saat berhasil login (milidetik epoch)
  static Future<void> saveLoginTimestamp() async {
    await _prefs?.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
  }

  // Hapus timestamp saat logout
  static Future<void> clearLoginTimestamp() async {
    await _prefs?.remove('loginTimestamp');
  }

  // Cek apakah sesi sudah kadaluarsa (> 7 hari)
  static bool get sessionExpired {
    final ts = _prefs?.getInt('loginTimestamp');
    if (ts == null) return true; // belum pernah login = anggap expired
    final loginTime = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(loginTime).inDays >= 7;
  }

  // Cek apakah user sudah pernah menyetujui izin notifikasi
  static bool get notifPermissionGranted =>
      _prefs?.getBool('notifPermissionGranted') ?? false;

  // Simpan status bahwa user telah mengizinkan notifikasi
  static Future<void> setNotifPermissionGranted(bool granted) async {
    await _prefs?.setBool('notifPermissionGranted', granted);
  }
}
