import 'package:flutter/material.dart';

// Gradien kartu cuaca yang dipakai bersama oleh tab Kota, Beranda, dan Detail,
// supaya warna kartu cuaca seragam di semua layar.
//
// Warna mengikuti kondisi cuaca (kode cuaca Open-Meteo): cerah biru terang, berawan
// abu-biru, hujan biru-slate, badai ungu. Mode terang lebih cerah, mode gelap lebih dalam.
// Semua warna cukup gelap sehingga teks putih di atasnya tetap terbaca.
// weatherCode null (cuaca belum dimuat) memakai gradien biru bawaan.
LinearGradient weatherGradient(int? weatherCode, bool isDark) {
  List<Color> warna;

  if (weatherCode == null) {
    warna = isDark
        ? const [Color(0xFF345A9A), Color(0xFF2A4A86)]
        : const [Color(0xFF3B68B5), Color(0xFF285098)];
  } else if (weatherCode == 0) {
    // Cerah
    warna = isDark
        ? const [Color(0xFF2B72D4), Color(0xFF2467C4), Color(0xFF1B4F9E)]
        : const [Color(0xFF2180E8), Color(0xFF1E70CF), Color(0xFF3892F3)];
  } else if (weatherCode == 1 || weatherCode == 2) {
    // Cerah berawan atau berawan sebagian
    warna = isDark
        ? const [Color(0xFF3F79BE), Color(0xFF336AAB), Color(0xFF285792)]
        : const [Color(0xFF3A7BC8), Color(0xFF4E8CD4), Color(0xFF679EE0)];
  } else if (weatherCode == 3 || weatherCode == 45 || weatherCode == 48) {
    // Berawan penuh atau kabut
    warna = isDark
        ? const [Color(0xFF5A7391), Color(0xFF4D647F), Color(0xFF405670)]
        : const [Color(0xFF506882), Color(0xFF627B97), Color(0xFF758EAA)];
  } else if ((weatherCode >= 51 && weatherCode <= 67) ||
      (weatherCode >= 80 && weatherCode <= 82)) {
    // Gerimis atau hujan
    warna = isDark
        ? const [Color(0xFF3A6EA5), Color(0xFF2F5C8E), Color(0xFF254B78)]
        : const [Color(0xFF2B5B84), Color(0xFF3A71A0), Color(0xFF4A84B3)];
  } else if (weatherCode >= 95 && weatherCode <= 99) {
    // Badai petir
    warna = isDark
        ? const [Color(0xFF6A4DA8), Color(0xFF573C8E), Color(0xFF453075)]
        : const [Color(0xFF4A346E), Color(0xFF583F83), Color(0xFF694C9C)];
  } else {
    warna = isDark
        ? const [Color(0xFF3F6AA0), Color(0xFF345A8C)]
        : const [Color(0xFF385573), Color(0xFF4A6B8E)];
  }

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: warna,
  );
}
