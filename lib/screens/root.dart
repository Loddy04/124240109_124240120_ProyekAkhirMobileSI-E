import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'activity_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';

// Kerangka navigasi utama aplikasi dengan 5 tab (F8)
// Catatan: Tab index 3 adalah placeholder Aktivitas (PBI-089).
// Loddy yang akan mengganti urutan tab dan menghubungkan ActivityScreen di PBI-088.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // Indeks tab yang sedang aktif
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    // Daftar 5 halaman tab aplikasi (posisi tab ke-4 placeholder Aktivitas)
    final List<Widget> pages = [
      // Beranda cuaca (F2); nama dikirim agar sapaan ikut berubah saat diedit di Profil
      HomeScreen(namaLengkap: SettingsService.fullName),
      const ActivityScreen(),
      const RemindersScreen(),
      const FavoritesScreen(),
      ProfileScreen(
        onNameChanged: () {
          setState(() {}); // Segarkan sapaan di Beranda jika nama diedit
        },
      ),
    ];

    return GlassScaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.glass,
              border: Border(
                top: BorderSide(color: c.glassBorder),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.cloud_outlined),
                  activeIcon: Icon(Icons.cloud_rounded),
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_available_outlined),
                  activeIcon: Icon(Icons.event_available_rounded),
                  label: 'Aktivitas',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_none_rounded),
                  activeIcon: Icon(Icons.notifications_rounded),
                  label: 'Pengingat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.location_city_outlined),
                  activeIcon: Icon(Icons.location_city_rounded),
                  label: 'Kota',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
