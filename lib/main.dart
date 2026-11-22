import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/favorite_city.dart';
import 'models/reminder.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // 1. Memastikan binding framework Flutter telah siap
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi penyimpanan lokal Hive untuk Flutter
  await Hive.initFlutter();

  // 3. Registrasi adapter Hive untuk model buatan (typeId 2 Perlengkapan dipensiunkan)
  Hive.registerAdapter(ReminderAdapter());
  Hive.registerAdapter(FavoriteCityAdapter());

  // 4. Membuka box Hive data utama dan box cache cuaca milik Loddy
  await Hive.openBox<Reminder>('reminders');
  await Hive.openBox<FavoriteCity>('favorites');
  await Hive.openBox<String>('weather_cache');

  // 5. Inisialisasi layanan pengaturan aplikasi
  await SettingsService.init();

  // 6. Inisialisasi layanan notifikasi (PBI-043 & PBI-060)
  await NotificationService().init();
  await NotificationService().rescheduleAll();

  // 7. Jalankan aplikasi Payungin
  runApp(const PayunginApp());
}

class PayunginApp extends StatelessWidget {
  const PayunginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Payungin',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotificationService.navigatorKey,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentThemeMode,
          // Layar Login aktif sebagai halaman awal (PBI-006)
          home: const LoginScreen(),
          // Format 24 jam waktu Indonesia (tanpa AM/PM) untuk seluruh aplikasi
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
