import 'package:flutter_test/flutter_test.dart';
import 'package:payungin/services/notification_service.dart';
import 'package:payungin/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Tes teks yang tampil di layar: suhu menurut satuan pilihan dan isi pesan notifikasi.

void main() {
  group('SettingsService.formatSuhu', () {
    test('satuan C: dibulatkan tanpa konversi', () async {
      SharedPreferences.setMockInitialValues({'tempUnit': 'C'});
      await SettingsService.init();
      expect(SettingsService.formatSuhu(30), '30°');
      expect(SettingsService.formatSuhu(26.6), '27°');
    });

    test('satuan F: dikonversi dari Celsius', () async {
      SharedPreferences.setMockInitialValues({'tempUnit': 'F'});
      await SettingsService.init();
      expect(SettingsService.formatSuhu(0), '32°');
      expect(SettingsService.formatSuhu(30), '86°');
      expect(SettingsService.formatSuhu(26.6), '80°');
    });

    test('tanpa pengaturan tersimpan: bawaan Celsius', () async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.init();
      expect(SettingsService.formatSuhu(28), '28°');
    });
  });

  group('NotificationService.isiNotifikasi', () {
    test('catatan dan kota: kota di depan catatan', () {
      expect(
        NotificationService.isiNotifikasi('Bawa payung', 'Sleman'),
        'Sleman: Bawa payung',
      );
    });

    test('catatan kosong dengan kota: kota di depan teks bawaan', () {
      expect(
        NotificationService.isiNotifikasi('', 'Sleman'),
        'Sleman: Waktunya bersiap dan cek perlengkapan sebelum beraktivitas!',
      );
    });

    test('tanpa kota (pengingat lama): isi tidak berubah', () {
      expect(NotificationService.isiNotifikasi('Bawa payung', ''), 'Bawa payung');
      expect(
        NotificationService.isiNotifikasi('', ''),
        'Waktunya bersiap dan cek perlengkapan sebelum beraktivitas!',
      );
    });
  });
}
