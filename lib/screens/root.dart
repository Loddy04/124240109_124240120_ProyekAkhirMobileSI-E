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
// Urutan tab: Beranda, Kota, Aktivitas, Pengingat, Profil
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // Indeks tab yang sedang aktif
  int _selectedIndex = 0;

  // Posisi tab Pengingat (Beranda 0, Kota 1, Aktivitas 2, Pengingat 3, Profil 4)
  static const int _tabPengingat = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    // Daftar 5 halaman tab aplikasi; urutannya harus sama dengan item menu di bawah
    final List<Widget> pages = [
      // Beranda cuaca (F2); nama dikirim agar sapaan ikut berubah saat diedit di Profil
      HomeScreen(namaLengkap: SettingsService.fullName),
      const FavoritesScreen(),
      // Setelah pengingat dari hasil Aktivitas disimpan, pindah ke tab Pengingat
      ActivityScreen(
        onReminderSaved: () => setState(() => _selectedIndex = _tabPengingat),
      ),
      const RemindersScreen(),
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
                  icon: Icon(Icons.location_city_outlined),
                  activeIcon: Icon(Icons.location_city_rounded),
                  label: 'Kota',
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
