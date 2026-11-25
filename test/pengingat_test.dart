import 'package:flutter_test/flutter_test.dart';
import 'package:payungin/models/activity.dart';

// Tes isian pengingat dari hasil Aktivitas (PBI-087): jam yang disarankan,
// tanggal, judul, dan catatan.

ActivityResult hasil({
  int skor = 80,
  String tingkat = 'Cocok',
  int jamDinilai = 10,
  int? jamLebihBaik,
  int? skorLebihBaik,
  bool tidakAdaJamAman = false,
}) {
  return ActivityResult(
    namaAktivitas: 'Jemur pakaian',
    skor: skor,
    tingkat: tingkat,
    faktor: const [],
    saran: const ['Cocok'],
    jamDinilai: jamDinilai,
    dibatasi: false,
    jamLebihBaik: jamLebihBaik,
    skorLebihBaik: skorLebihBaik,
    tidakAdaJamAman: tidakAdaJamAman,
  );
}

void main() {
  const jemur = JemurActivity();
  final senin = DateTime(2026, 11, 23, 9, 30);

  group('jamPengingat', () {
    test('memakai jam yang dinilai bila hasilnya layak', () {
      expect(hasil(jamDinilai: 10).jamPengingat, 10);
    });

    test('memakai jam lebih baik bila ada', () {
      final h = hasil(skor: 60, tingkat: 'Cukup', jamDinilai: 8, jamLebihBaik: 11, skorLebihBaik: 85);
      expect(h.jamPengingat, 11);
    });

    test('tidak ada jam aman: tidak ada pengingat', () {
      final h = hasil(skor: 10, tingkat: 'Hindari', tidakAdaJamAman: true, jamLebihBaik: 12, skorLebihBaik: 20);
      expect(h.jamPengingat, isNull);
    });

    test('Hindari tanpa jam lebih baik: tidak ada pengingat', () {
      final h = hasil(skor: 10, tingkat: 'Hindari');
      expect(h.jamPengingat, isNull);
    });

    test('Kurang tetap boleh dibuatkan pengingat', () {
      final h = hasil(skor: 40, tingkat: 'Kurang', jamDinilai: 9);
      expect(h.jamPengingat, 9);
    });
  });

  group('IsianPengingat.dari', () {
    test('judul, jenis, jam, dan tanggal untuk hari ini', () {
      final isian = IsianPengingat.dari(
        aktivitas: jemur,
        hasil: hasil(jamDinilai: 10),
        hari: 0,
        namaKota: 'Sleman',
        sekarang: senin,
      )!;
      expect(isian.judul, 'Jemur pakaian · Sleman');
      expect(isian.jenis, 'jemur');
      expect(isian.jam, '10:00');
      expect(isian.tanggal, DateTime(2026, 11, 23));
    });

    test('tanggal maju sesuai hari yang dipilih, juga melewati pergantian bulan', () {
      final isian = IsianPengingat.dari(
        aktivitas: jemur,
        hasil: hasil(),
        hari: 6,
        namaKota: 'Sleman',
        sekarang: DateTime(2026, 11, 27, 9),
      )!;
      expect(isian.tanggal, DateTime(2026, 12, 3));
    });

    test('jam lebih baik dipakai bersama skornya', () {
      final isian = IsianPengingat.dari(
        aktivitas: jemur,
        hasil: hasil(skor: 60, tingkat: 'Cukup', jamDinilai: 8, jamLebihBaik: 7, skorLebihBaik: 88),
        hari: 1,
        namaKota: 'Yogyakarta',
        sekarang: senin,
      )!;
      expect(isian.jam, '07:00');
      expect(isian.catatan, 'Skor Cocok (88) pada pukul 07.00.');
      expect(isian.tanggal, DateTime(2026, 11, 24));
    });

    test('tanpa jam lebih baik catatan memakai skor hasil', () {
      final isian = IsianPengingat.dari(
        aktivitas: jemur,
        hasil: hasil(skor: 62, tingkat: 'Cukup', jamDinilai: 13),
        hari: 0,
        namaKota: 'Sleman',
        sekarang: senin,
      )!;
      expect(isian.catatan, 'Skor Cukup (62) pada pukul 13.00.');
    });

    test('hasil tanpa jam yang berguna menghasilkan null', () {
      final isian = IsianPengingat.dari(
        aktivitas: jemur,
        hasil: hasil(skor: 5, tingkat: 'Hindari'),
        hari: 0,
        namaKota: 'Sleman',
        sekarang: senin,
      );
      expect(isian, isNull);
    });
  });
}
