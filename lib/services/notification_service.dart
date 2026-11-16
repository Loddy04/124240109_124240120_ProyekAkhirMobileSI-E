import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

// Layanan notifikasi pengingat cuaca (F16) — PBI-043
// Pola OOP Singleton sesuai Dokumen Final Bagian 7.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  // Factory constructor yang selalu mengembalikan satu instans yang sama
  factory NotificationService() => _instance;

  NotificationService._internal();

  // Global navigator key untuk navigasi saat notifikasi ditekan (PBI-059)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ---- Plugin dan channel Android -----------------------------------------
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'payungin_reminder';
  static const String _channelName = 'Pengingat Payungin';
  static const String _channelDesc = 'Notifikasi pengingat cuaca harian';

  // ID timezone WIB
  static const String _wibId = 'Asia/Jakarta';

  bool _initialized = false;

  // ---- Inisialisasi plugin & timezone -------------------------------------
  // Dipanggil di main() sebelum runApp
  Future<void> init() async {
    if (_initialized) return;

    // 1. Inisialisasi data timezone (semua zona)
    tz_data.initializeTimeZones();

    // 2. Atur timezone lokal ke WIB
    tz.setLocalLocation(tz.getLocation(_wibId));

    // 3. Konfigurasi inisialisasi Android
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
          '[NotificationService] Notifikasi ditekan dengan payload: ${response.payload}',
        );
      },
    );

    // 4. Buat channel notifikasi Android (wajib untuk Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
    debugPrint('[NotificationService] Inisialisasi selesai (WIB timezone).');
  }

  // ---- Minta izin notifikasi (Android 13+ / API 33+) ----------------------
  // Mengembalikan true jika izin diberikan.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    final granted = await android.requestNotificationsPermission();
    debugPrint('[NotificationService] Izin notifikasi: $granted');
    return granted ?? false;
  }

  // ---- Jadwalkan notifikasi pengingat harian -------------------------------
  // ID notifikasi = reminder.key (Hive int) untuk memudahkan cancel.
  // Jika waktu sudah lewat hari ini → jadwalkan besok.
  // repeatDaily = true  → DateTimeComponents.time (setiap hari)
  // repeatDaily = false → one-shot (sekali saja)
  Future<void> schedule(Reminder r, [Object? advice]) async {
    if (!_initialized) await init();

    final id = r.key as int;

    // Parsing HH:mm dari r.time
    final parts = r.time.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    // Waktu terjadwal dalam WIB
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled;

    if (r.repeatDaily) {
      // Pengingat harian: hitung jam:menit
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      // Jika jam sudah lewat hari ini → mulai besok
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    } else if (r.date != null && r.date!.isNotEmpty) {
      // Pengingat satu kali pada tanggal spesifik (maks 7 hari)
      final partsDate = r.date!.split('-');
      if (partsDate.length == 3) {
        final year = int.tryParse(partsDate[0]) ?? now.year;
        final month = int.tryParse(partsDate[1]) ?? now.month;
        final day = int.tryParse(partsDate[2]) ?? now.day;
        scheduled = tz.TZDateTime(
          tz.local,
          year,
          month,
          day,
          hour,
          minute,
        );
      } else {
        scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      }

      // Jika tanggal + jam yang dipilih sudah lewat waktu saat ini, lewati
      if (scheduled.isBefore(now)) {
        debugPrint('[NotificationService] Waktu pengingat $scheduled sudah lewat, dilewati.');
        return;
      }
    } else {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }

    // Konten notifikasi
    final title = r.title.isNotEmpty ? r.title : 'Pengingat Payungin';
    final body = r.note.isNotEmpty
        ? r.note
        : 'Waktunya bersiap dan cek perlengkapan sebelum beraktivitas!';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    if (r.repeatDaily) {
      // Notifikasi berulang setiap hari pada jam yang sama
      await _plugin.zonedSchedule(
        id,
        title,
        body.isNotEmpty ? body : 'Cek cuaca sebelum bepergian!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('[NotificationService] Jadwal harian id=$id jam=$hour:$minute');
    } else {
      // Notifikasi sekali saja
      await _plugin.zonedSchedule(
        id,
        title,
        body.isNotEmpty ? body : 'Cek cuaca sebelum bepergian!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('[NotificationService] Jadwal sekali id=$id jam=$hour:$minute');
    }
  }

  // ---- Batalkan notifikasi berdasarkan ID (key Hive) ----------------------
  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id);
    debugPrint('[NotificationService] Notifikasi id=$id dibatalkan.');
  }

  // ---- Batalkan seluruh notifikasi terjadwal ------------------------------
  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
    debugPrint('[NotificationService] Seluruh notifikasi dibatalkan.');
  }

  // ---- Menjadwalkan ulang seluruh notifikasi aktif saat aplikasi dibuka (PBI-060)
  Future<void> rescheduleAll() async {
    if (!_initialized) await init();
    try {
      final box = Hive.box<Reminder>('reminders');
      for (final reminder in box.values) {
        if (reminder.notifOn) {
          await schedule(reminder);
        }
      }
      debugPrint('[NotificationService] Seluruh pengingat aktif berhasil dijadwalkan ulang.');
    } catch (e) {
      debugPrint('[NotificationService] Gagal menjadwalkan ulang pengingat: $e');
    }
  }

  // ---- Notifikasi instan (langsung tampil) ---------------------------------
  // Digunakan untuk tombol uji di halaman Profil.
  Future<void> showNow(String title, String body) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(0, title, body, details);
    debugPrint('[NotificationService] Notifikasi instan: $title — $body');
  }
}
