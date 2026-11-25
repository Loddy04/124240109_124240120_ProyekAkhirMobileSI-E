import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';
import '../models/favorite_city.dart';
import '../models/city_result.dart';
import '../models/popular_city.dart';
import '../models/weather_data.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/city_search_field.dart';
import 'detail_screen.dart';
import 'favorites_screen.dart';

// Layar Kelola Kota Favorit — Menampilkan grid kota favorit untuk slider Beranda
// dan daftar kota lainnya di bawahnya.
// Jika kota dihapus dari favorit, otomatis pindah ke bawah (kota lainnya).
// Jika kota di bawah ditambahkan, otomatis naik ke grid favorit di atas.
class SelectFavoritesScreen extends StatefulWidget {
  const SelectFavoritesScreen({super.key});

  @override
  State<SelectFavoritesScreen> createState() => _SelectFavoritesScreenState();
}

class _SelectFavoritesScreenState extends State<SelectFavoritesScreen> {
  // Hasil pencarian (F4): null = tidak sedang mencari
  List<CityResult>? _hasilCari;
  bool _sedangMencari = false;
  String? _errorCari;

  // Cache cuaca lokal untuk layar ini
  final Map<String, WeatherData?> _weatherCache = {};
  final Map<String, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllWeather();
  }

  // Buka Detail Cuaca kota ini (dipakai semua kartu)
  void _bukaDetail(String nama, double lat, double lon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          latitude: lat,
          longitude: lon,
          namaKota: nama,
          satuan: SettingsService.unit,
        ),
      ),
    );
  }

  String _cacheKey(String name, String province) =>
      '${name.toLowerCase()}|${province.toLowerCase()}';

  Future<void> _loadWeatherForCity(String name, String province, double lat, double lon) async {
    final key = _cacheKey(name, province);
    // Cek cache statis global dulu jika sudah ada
    final cached = WeatherCache.get(key);
    if (cached != null) {
      if (_weatherCache[key] == null) {
        setState(() => _weatherCache[key] = cached);
      }
      return;
    }

    if (_loadingMap[key] == true) return;
    _loadingMap[key] = true;

    try {
      final data = await ApiService.getWeather(lat, lon);
      WeatherCache.set(key, data);
      if (mounted) {
        setState(() => _weatherCache[key] = data);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _weatherCache[key] = null);
      }
    } finally {
      _loadingMap[key] = false;
    }
  }

  void _loadAllWeather() {
    for (final city in popularCities) {
      _loadWeatherForCity(city.name, city.province, city.lat, city.lon);
    }
  }

  // Hapus kota dari favorit
  void _removeFromFavorites(Box<FavoriteCity> box, int index, String cityName) {
    box.deleteAt(index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kota "$cityName" dihapus dari favorit.'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Kartu Grid Favorit (Gaya Card Elegan 2 Kolom Sesuai Referensi) ───────
  Widget _buildFavoriteGridCard(
    BuildContext context, {
    required FavoriteCity city,
    required int index,
    required Box<FavoriteCity> box,
  }) {
    final c = context.pc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = _cacheKey(city.name, city.province);
    final weather = _weatherCache[key] ?? WeatherCache.get(key);
    final isLoading = _loadingMap[key] == true && weather == null;

    if (weather == null && !isLoading) {
      _loadWeatherForCity(city.name, city.province, city.lat, city.lon);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.glass : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? c.glassBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF1E3A60).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header kartu: nama kota + tombol hati
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Tombol favorit (ketuk untuk menghapus dari favorit)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _removeFromFavorites(box, index, city.name),
                    child: Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: c.favorite.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: c.favorite,
                      ),
                    ),
                  ),
                ],
              ),

              // Tengah kartu: Suhu besar di kiri & Ikon cuaca biru outline di kanan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  else if (weather != null)
                    Text(
                      SettingsService.formatSuhu(weather.tempC),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        height: 1,
                      ),
                    )
                  else
                    Text(
                      '--',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: c.textMuted,
                      ),
                    ),

                  // Ikon cuaca
                  if (weather != null)
                    Icon(
                      weather.icon,
                      size: 36,
                      color: c.accent,
                    )
                  else
                    Icon(
                      Icons.cloud_outlined,
                      size: 36,
                      color: c.textMuted.withValues(alpha: 0.4),
                    ),
                ],
              ),

              // Bawah kartu: Pill badge kondisi cuaca riil & parameter kelembapan
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weather != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.chipBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        weather.condition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.chipText,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Memuat cuaca...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final box = Hive.box<FavoriteCity>('favorites');

    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<Box<FavoriteCity>>(
          valueListenable: box.listenable(),
          builder: (context, favBox, _) {
            // Set kota favorit saat ini (lowercase untuk perbandingan)
            final favNames = favBox.values
                .map((f) => f.name.toLowerCase())
                .toSet();

            // Kota populer yang BELUM difavoritkan (akan muncul di section bawah)
            final nonFavorites = popularCities
                .where((city) => !favNames.contains(city.name.toLowerCase()))
                .toList();

            // Hasil pencarian (F4) yang belum difavoritkan, ditampilkan dengan baris yang sama
            final hasilCari = _hasilCari;
            final mencari = _sedangMencari || _errorCari != null || hasilCari != null;
            final daftar = hasilCari != null
                ? hasilCari
                    .where((k) => !favNames.contains(k.name.toLowerCase()))
                    .map((k) => PopularCity(
                          name: k.name,
                          province: k.province,
                          lat: k.latitude,
                          lon: k.longitude,
                        ))
                    .toList()
                : nonFavorites;

            return CustomScrollView(
              slivers: [
                // ── App Bar ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 2),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: c.text),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kota Favorit Beranda',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: c.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Section 1: KOTA FAVORIT SAYA ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_rounded, size: 16, color: c.favorite),
                        const SizedBox(width: 6),
                        Text(
                          'KOTA FAVORIT SAYA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${favBox.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid 2-kolom jika ada kota favorit
                if (favBox.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.88,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final city = favBox.getAt(index);
                          if (city == null) return const SizedBox.shrink();

                          // Ketuk kartu favorit membuka Detail (tombol hati tetap menghapus)
                          return GestureDetector(
                            onTap: () => _bukaDetail(city.name, city.lat, city.lon),
                            child: _buildFavoriteGridCard(
                              context,
                              city: city,
                              index: index,
                              box: favBox,
                            ),
                          );
                        },
                        childCount: favBox.length,
                      ),
                    ),
                  )
                else
                  // Empty state jika belum ada kota favorit
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              size: 40,
                              color: c.favorite.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum Ada Kota Favorit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pilih kota di bawah untuk disematkan ke slider Beranda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Divider Pemisah yang Jelas ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Divider(color: c.glassBorder),
                  ),
                ),

                // ── Section 2: TAMBAH KOTA LAINNYA ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(
                      children: [
                        Icon(Icons.add_location_alt_rounded, size: 16, color: c.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          mencari ? 'HASIL PENCARIAN' : 'PILIH KOTA LAINNYA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${daftar.length} tersedia)',
                          style: TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),

                // Kolom cari: logika F4 (ApiService.searchCity, hanya kota Indonesia)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: CitySearchField(
                      hintText: 'Cari kota untuk ditambahkan...',
                      onSearching: () => setState(() {
                        _sedangMencari = true;
                        _errorCari = null;
                      }),
                      onResult: (hasil) {
                        setState(() {
                          _hasilCari = hasil;
                          _sedangMencari = false;
                        });
                        // Muat cuaca tiap hasil agar barisnya terisi
                        for (final k in hasil) {
                          _loadWeatherForCity(k.name, k.province, k.latitude, k.longitude);
                        }
                      },
                      onError: (pesan) => setState(() {
                        _sedangMencari = false;
                        _errorCari = pesan;
                      }),
                      onClear: () => setState(() {
                        _hasilCari = null;
                        _sedangMencari = false;
                        _errorCari = null;
                      }),
                    ),
                  ),
                ),

                // List kota yang belum difavoritkan
                if (_sedangMencari)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_errorCari != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          _errorCari!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                      ),
                    ),
                  )
                else if (daftar.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          hasilCari == null
                              ? 'Semua kota sudah ada di favorit Anda!'
                              : hasilCari.isEmpty
                                  ? 'Kota tidak ditemukan di Indonesia.'
                                  : 'Semua hasil sudah ada di favorit Anda.',
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final city = daftar[index];
                        final key = _cacheKey(city.name, city.province);
                        final weather = _weatherCache[key] ?? WeatherCache.get(key);

                        final iconColor = weather != null
                            ? WeatherCategoryHelper.weatherIconColor(weather.weatherCode, isDark)
                            : c.accent;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: GlassCard(
                            // Ketuk baris membuka Detail (tombol + tetap menambah favorit)
                            onTap: () => _bukaDetail(city.name, city.lat, city.lon),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                // Avatar bulat berdasarkan kondisi cuaca riil
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    weather != null ? weather.icon : Icons.location_city_rounded,
                                    size: 20,
                                    color: iconColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        city.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: c.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (weather != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                weather.condition,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: iconColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Suhu
                                if (weather != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          SettingsService.formatSuhu(weather.tempC),
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: c.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Tombol Tambah ke Favorit
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    FavoritesScreen.saveFavoriteCity(
                                      context,
                                      name: city.name,
                                      province: city.province,
                                      lat: city.lat,
                                      lon: city.lon,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: c.accent.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 20,
                                      color: c.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: daftar.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
