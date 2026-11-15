import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';
import '../models/favorite_city.dart';
import '../models/popular_city.dart';
import '../models/weather_data.dart';
import '../theme/app_theme.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  // ── Gradien Cuaca Atmosferik Adaptif (Mode Terang vs Mode Gelap) ─────────
  // Tidak ada warna nabrak: di mode terang gradien lebih cerah & kaya,
  // di mode gelap gradien lebih dalam (deep midnight/moody) dan nyaman di mata.
  LinearGradient _getAtmosphericGradient(WeatherData? weather, bool isDark) {
    if (weather == null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1E2D4A), Color(0xFF131D33)]
            : const [Color(0xFF3B68B5), Color(0xFF285098)],
      );
    }

    final code = weather.weatherCode;

    // 1. Cerah (kode 0)
    if (code == 0) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF104A8E), Color(0xFF0D3261), Color(0xFF092040)]
            : const [Color(0xFF2180E8), Color(0xFF1E70CF), Color(0xFF3892F3)],
      );
    }

    // 2. Cerah Berawan / Berawan Sebagian (kode 1-2)
    if (code == 1 || code == 2) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1E3A5F), Color(0xFF162A45), Color(0xFF0F1D30)]
            : const [Color(0xFF3A7BC8), Color(0xFF4E8CD4), Color(0xFF679EE0)],
      );
    }

    // 3. Berawan Penuh / Kabut (kode 3, 45, 48)
    if (code == 3 || code == 45 || code == 48) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF2C394B), Color(0xFF1F2837), Color(0xFF151C26)]
            : const [Color(0xFF506882), Color(0xFF627B97), Color(0xFF758EAA)],
      );
    }

    // 4. Gerimis / Hujan (kode 51-67, 80-82)
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1A3254), Color(0xFF13243D), Color(0xFF0E1A2C)]
            : const [Color(0xFF2B5B84), Color(0xFF3A71A0), Color(0xFF4A84B3)],
      );
    }

    // 5. Badai Petir (kode 95-99)
    if (code >= 95 && code <= 99) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF2B1B47), Color(0xFF1C1130), Color(0xFF120B1F)]
            : const [Color(0xFF4A346E), Color(0xFF583F83), Color(0xFF694C9C)],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF1B2838), Color(0xFF111A24)]
          : const [Color(0xFF385573), Color(0xFF4A6B8E)],
    );
  }

  // Label ilmiah spektrum suhu (Panas / Hangat / Sejuk)
  String _tempSpectrum(double temp) {
    if (temp >= 31) return 'Panas';
    if (temp >= 25) return 'Hangat';
    return 'Sejuk';
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

    final gradient = _getAtmosphericGradient(weather, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Membuka detail cuaca ${city.name}.'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
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
                          // Sisi Kiri Atas: Nama Kota & Kategori Suhu
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
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
                                    if (weather != null) ...[
                                      const SizedBox(width: 8),
                                      // Badge Spektrum Suhu
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _tempSpectrum(weather.tempC),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  city.province,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
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

                          const SizedBox(width: 8),

                          // Kanan Bawah: Parameter Nyata (Kelembapan & H/L)
                          if (weather != null)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Kelembapan riil
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.water_drop_rounded, size: 11, color: Colors.white70),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${weather.humidity}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (weather.dailyMax.isNotEmpty && weather.dailyMin.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'T:${weather.dailyMax.first.round()}° R:${weather.dailyMin.first.round()}°',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
          final filtered = _query.isEmpty
              ? allPopular
              : popularCities.where((city) =>
                  city.name.toLowerCase().contains(_query.toLowerCase()) ||
                  city.province.toLowerCase().contains(_query.toLowerCase())).toList();

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
                          Icon(Icons.favorite_rounded, color: c.accent, size: 26),
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
                                  style: const TextStyle(
                                    color: Colors.white,
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

              // ── Search bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            style: TextStyle(color: c.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Cari kota di Indonesia...',
                              hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: Icon(Icons.close_rounded, color: c.textMuted, size: 18),
                          ),
                      ],
                    ),
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
                        _query.isEmpty ? 'KOTA POPULER' : 'HASIL PENCARIAN',
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

              // ── Daftar Kartu Cuaca Representatif ──────────────────────────
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Kota "$_query" tidak ditemukan.',
                        style: TextStyle(color: c.textMuted, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final city = filtered[index];
                      return _buildWeatherCard(city: city);
                    },
                    childCount: filtered.length,
                  ),
                ),

              // ── Tombol Lihat Lebih Banyak / Sembunyikan ───────────────────
              if (_query.isEmpty)
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
