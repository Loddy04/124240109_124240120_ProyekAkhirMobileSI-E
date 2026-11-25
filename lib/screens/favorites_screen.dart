import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';
import '../models/favorite_city.dart';
import '../models/city_result.dart';
import '../models/popular_city.dart';
import '../models/weather_data.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/weather_gradient.dart';
import '../widgets/city_search_field.dart';
import 'detail_screen.dart';
import 'select_favorites_screen.dart';

// Cache statis ringan dalam memori agar data cuaca yang sudah dimuat
// bisa langsung dipakai bersama antara halaman Kota dan Kelola Favorit
class WeatherCache {
  static final Map<String, WeatherData> _cache = {};
  static WeatherData? get(String key) => _cache[key];
  static void set(String key, WeatherData data) => _cache[key] = data;
}

// Layar Kota (F5) — Eksplorasi cuaca berbagai kota di Indonesia
// Desain atmosferik premium ala Apple Weather yang adaptif penuh terhadap mode terang/gelap
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  // ── Kontrak publik (dipanggil Loddy dari F4 Cari Kota) ──────────────────
  static bool saveFavoriteCity(
    BuildContext context, {
    required String name,
    required String province,
    required double lat,
    required double lon,
  }) {
    final box = Hive.box<FavoriteCity>('favorites');

    final isDuplicate = box.values.any((c) =>
        c.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        c.province.trim().toLowerCase() == province.trim().toLowerCase());

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kota "$name" sudah ada di favorit.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    box.add(FavoriteCity(
      name: name.trim(),
      province: province.trim(),
      lat: lat,
      lon: lon,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name ditambahkan ke favorit.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    return true;
  }

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Hasil pencarian (F4): null = tidak sedang mencari
  List<CityResult>? _hasilCari;
  bool _sedangMencari = false;
  String? _errorCari;

  // Cache cuaca per kota: key = "name|province"
  final Map<String, WeatherData?> _weatherCache = {};
  final Map<String, bool> _loadingMap = {};

  // Default: tampilkan 10 kota populer pertama
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _preloadPopularWeather();
  }

  // Buka Detail Cuaca kota ini (dipakai semua kartu)
  void _bukaDetail(PopularCity city) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          latitude: city.lat,
          longitude: city.lon,
          namaKota: city.name,
          satuan: SettingsService.unit,
        ),
      ),
    );
  }

  String _cacheKey(String name, String province) =>
      '${name.toLowerCase()}|${province.toLowerCase()}';

  Future<void> _loadWeather(String name, String province, double lat, double lon) async {
    final key = _cacheKey(name, province);
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

  void _preloadPopularWeather() {
    final toLoad = popularCities.take(10);
    for (final city in toLoad) {
      _loadWeather(city.name, city.province, city.lat, city.lon);
    }
  }

  void _preloadAllWeather() {
    for (final city in popularCities) {
      _loadWeather(city.name, city.province, city.lat, city.lon);
    }
  }

  // ── Kartu Cuaca Representatif & Elegan ─────────────────────────────────────
  Widget _buildWeatherCard({
    required PopularCity city,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = _cacheKey(city.name, city.province);
    final weather = _weatherCache[key] ?? WeatherCache.get(key);
    final isLoading = _loadingMap[key] == true && weather == null;

    if (weather == null && !isLoading) {
      _loadWeather(city.name, city.province, city.lat, city.lon);
    }

    final gradient = weatherGradient(weather?.weatherCode, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: GestureDetector(
        onTap: () => _bukaDetail(city),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0xFF1A3860).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Highlight kilau kaca tipis di sudut kiri atas (efek Apple Weather)
                Positioned(
                  top: -30,
                  left: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.08 : 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Konten Kartu
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.22),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Baris Atas: Nama Kota, Provinsi & Suhu Besar
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sisi Kiri Atas: nama kota
                          Expanded(
                            child: Text(
                              city.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Sisi Kanan Atas: Suhu Besar
                          if (isLoading)
                            const SizedBox(
                              height: 36,
                              width: 36,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          else if (weather != null)
                            Text(
                              '${weather.tempC.round()}°',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w200,
                                color: Colors.white,
                                height: 0.95,
                                letterSpacing: -1,
                              ),
                            )
                          else
                            const Text(
                              '--',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w200,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Baris Bawah: Kondisi Cuaca & Parameter Meteorologi Riil
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Kiri Bawah: Ikon & Kondisi Cuaca (Flexible agar tidak overflow)
                          Expanded(
                            child: weather != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(weather.icon, size: 18, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          weather.condition,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Memuat prakiraan cuaca...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final box = Hive.box<FavoriteCity>('favorites');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<Box<FavoriteCity>>(
        valueListenable: box.listenable(),
        builder: (context, favBox, _) {
          // Kota populer sesuai query
          final allPopular = _showAll ? popularCities : popularCities.take(10).toList();
          // true bila sedang atau sudah mencari: daftar populer diganti hasil pencarian
          final hasilCari = _hasilCari;
          final mencari = _sedangMencari || _errorCari != null || hasilCari != null;

          return CustomScrollView(
            slivers: [
              // ── App Bar: Judul "Kota" & Ikon Favorit di Pojok Kanan Atas ──────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                snap: true,
                pinned: false,
                automaticallyImplyLeading: false,
                title: const Text('Kota'),
                titleTextStyle: TextStyle(
                  color: c.text,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      tooltip: 'Kota Favorit Beranda',
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.favorite_rounded, color: c.favorite, size: 26),
                          if (favBox.isNotEmpty)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: c.danger,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${favBox.length}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: c.onAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SelectFavoritesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Kolom cari: logika F4 (ApiService.searchCity, hanya kota Indonesia)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: CitySearchField(
                    hintText: 'Cari kota di Indonesia...',
                    onSearching: () => setState(() {
                      _sedangMencari = true;
                      _errorCari = null;
                    }),
                    onResult: (hasil) {
                      setState(() {
                        _hasilCari = hasil;
                        _sedangMencari = false;
                      });
                      // Muat cuaca tiap hasil agar kartunya terisi
                      for (final k in hasil) {
                        _loadWeather(k.name, k.province, k.latitude, k.longitude);
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

              // ── Header Section Kota Populer ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                  child: Row(
                    children: [
                      Icon(Icons.explore_rounded, size: 15, color: c.accent),
                      const SizedBox(width: 6),
                      Text(
                        mencari ? 'HASIL PENCARIAN' : 'KOTA POPULER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: c.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Daftar kartu cuaca: kota populer atau hasil pencarian ─────
              if (_sedangMencari)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_errorCari != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _errorCari!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textMuted, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else if (hasilCari != null && hasilCari.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Kota tidak ditemukan di Indonesia.',
                        style: TextStyle(color: c.textMuted, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Kartu yang sama untuk kota populer dan hasil pencarian
                      final PopularCity city;
                      if (hasilCari != null) {
                        final k = hasilCari[index];
                        city = PopularCity(
                          name: k.name,
                          province: k.province,
                          lat: k.latitude,
                          lon: k.longitude,
                        );
                      } else {
                        city = allPopular[index];
                      }
                      return _buildWeatherCard(city: city);
                    },
                    childCount: hasilCari?.length ?? allPopular.length,
                  ),
                ),

              // ── Tombol Lihat Lebih Banyak / Sembunyikan ───────────────────
              if (!mencari)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showAll = !_showAll);
                        if (_showAll) {
                          _preloadAllWeather();
                        }
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showAll
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: c.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showAll
                                  ? 'Tampilkan 10 kota saja'
                                  : 'Lihat ${popularCities.length - 10} kota lainnya',
                              style: TextStyle(
                                color: c.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
