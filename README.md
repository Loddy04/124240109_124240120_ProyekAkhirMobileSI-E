# Payungin

**Payungin** adalah aplikasi cuaca Android berbahasa Indonesia yang membantu pengguna memutuskan
"perlu bawa payung atau tidak" dan "kapan waktu terbaik untuk beraktivitas". Aplikasi ini dibuat
dengan Flutter sebagai proyek akhir Praktikum Teknologi dan Pemrograman Mobile.

Aplikasi menampilkan cuaca kota favorit, cuaca di posisi pengguna (GPS), penilaian kelayakan
aktivitas (jemur pakaian, berkendara, outdoor), serta pengingat berjadwal dengan notifikasi lokal.

---

## Daftar Isi
1. [Fitur](#fitur)
2. [Alur Penggunaan](#alur-penggunaan)
3. [Aturan dan Logika Penting](#aturan-dan-logika-penting)
4. [Sumber Data (API)](#sumber-data-api)
5. [Penyimpanan Lokal](#penyimpanan-lokal)
6. [Teknologi](#teknologi)
7. [Struktur Folder](#struktur-folder)
8. [Cara Menjalankan](#cara-menjalankan)
9. [Akun Demo](#akun-demo)
10. [Pemetaan Modul Praktikum](#pemetaan-modul-praktikum)
11. [Konsep OOP](#konsep-oop)
12. [Pengujian](#pengujian)
13. [Pembagian Tugas](#pembagian-tugas)
14. [Keterbatasan yang Diketahui](#keterbatasan-yang-diketahui)

---

## Fitur

Aplikasi memiliki 5 tab: **Beranda, Kota, Aktivitas, Pengingat, Profil**.

### Autentikasi dan Akun
- **Registrasi** dengan validasi (nama minimal 3 karakter, username minimal 3 karakter tanpa spasi,
  password minimal 6 karakter, konfirmasi password harus sama). Password disimpan sebagai hash SHA-256.
- **Login** dengan akun terdaftar atau akun demo.
- **Sesi 7 hari:** setelah login, pengguna langsung masuk ke aplikasi sampai 7 hari berikutnya.
  Setelah itu login ulang.
- **Logout** dengan dialog konfirmasi. Halaman sebelumnya tidak bisa dibuka kembali lewat tombol back.

### Beranda
- Sapaan dan tanggal hari ini.
- **Slider kartu cuaca** yang bisa digeser antar kota favorit (suhu, kondisi, terasa seperti,
  kelembapan, angin, peluang hujan). Warna kartu mengikuti kondisi cuaca. Ketuk kartu untuk membuka Detail.
- **Lokasi Saya (GPS):** menampilkan cuaca di posisi pengguna. Bila kota GPS ada di favorit, slider
  bergeser ke kartu itu. Bila tidak, muncul kartu sementara yang hilang saat pindah tab.
- **7 jam ke depan**, **Cocok untuk hari ini** (skor empat aktivitas), **Pengingat berikutnya**,
  dan **Favorit terdekat** (maksimal 5 favorit, urut dari yang terdekat dengan jarak dan cuacanya).
- Label "Data terakhir diperbarui ... (offline)" muncul bila data berasal dari cache.

### Detail Cuaca
Cuaca per jam (24 jam), prakiraan 7 hari (ikon dari internet dengan cadangan ikon), ringkasan
(UV, angin, kelembapan, hujan hari ini, terasa seperti, peluang hujan), serta waktu matahari
terbit dan terbenam.

### Kota
- **Cari kota** di Indonesia (lewat Geocoding API).
- **Kota populer** (20 kota, 10 tampil awal) dengan kartu cuaca. Ketuk kartu untuk membuka Detail.
- Ikon hati membuka **Kelola Favorit**: daftar favorit (tambah dan hapus) dan daftar kota lain yang
  bisa ditambahkan. Kota favorit otomatis tampil di slider Beranda.

### Aktivitas
Pengguna memilih **aktivitas** (Jemur pakaian, Berkendara motor, Berkendara mobil, Aktivitas outdoor),
**hari** (hari ini sampai 6 hari ke depan), **jam**, dan **kota** (dari favorit). Aplikasi menampilkan
skor 0 sampai 100, tingkat (Cocok, Cukup, Kurang, Hindari), rincian tiap faktor, saran, dan **jam yang
lebih baik** pada hari yang sama. Dari hasilnya pengguna bisa langsung **membuat pengingat**.

### Pengingat (CRUD)
- **Tambah, ubah, hapus** pengingat. Pengingat berisi judul, kota (dari favorit), jam, tanggal
  (maksimal 7 hari ke depan) atau berulang setiap hari, catatan, dan saklar notifikasi.
- Daftar dibagi **Pengingat Aktif** dan **Riwayat**. Pengingat di riwayat bisa dipakai lagi.
- **Notifikasi lokal terjadwal** pada jam yang ditentukan, termasuk saat aplikasi ditutup, dan dijadwalkan
  ulang setelah HP dinyalakan kembali.
- Waktu yang sudah lewat ditolak pada pengingat sekali jalan.

### Profil dan Pengaturan
Foto profil (kamera atau galeri), ubah nama lengkap, satuan suhu (°C atau °F), mode terang atau gelap,
tombol **Tes notifikasi**, dan Logout.

### Mode Offline (Cache)
Cuaca terakhir yang berhasil dimuat disimpan per kota. Saat tidak ada internet, Beranda, Detail, dan
Aktivitas tetap menampilkan data terakhir tersebut dengan label offline.

---

## Alur Penggunaan

```
Buka aplikasi
   |
   +-- sesi masih berlaku (kurang dari 7 hari) --> langsung ke aplikasi
   |
   +-- belum login --> Login --(Daftar di sini)--> Registrasi --> kembali ke Login
                          |
                          v
                   Beranda | Kota | Aktivitas | Pengingat | Profil
```

1. **Daftar atau login** (bisa memakai akun demo).
2. Di tab **Kota**, cari atau pilih kota lalu ketuk ikon hati agar masuk **favorit**.
3. **Beranda** menampilkan cuaca kota favorit. Geser untuk berganti kota, atau tekan **Lokasi Saya**.
4. Di tab **Aktivitas**, pilih aktivitas, hari, jam, dan kota, lalu **Analisis**.
5. Dari hasil analisis, tekan **Buat pengingat**. Form terisi otomatis. Setelah disimpan, aplikasi pindah
   ke tab **Pengingat**.
6. Pada jam yang ditentukan, **notifikasi** muncul.

---

## Aturan dan Logika Penting

### Penilaian Aktivitas
- Tiap aktivitas punya beberapa faktor cuaca (misalnya peluang hujan, kondisi langit, UV, kelembapan,
  angin) dengan bobot masing-masing.
- Setiap faktor bernilai **Bagus (100), Sedang (50), atau Buruk (0)**.
- **Skor = jumlah (nilai x bobot) / 100.**
- Bila **faktor penentu** berstatus Buruk, skor dibatasi **maksimal 40**. Bila ada **badai petir**,
  maksimal 20.
- Tingkat: **Cocok** (75 ke atas), **Cukup** (50 sampai 74), **Kurang** (25 sampai 49), **Hindari** (di bawah 25).
- Jam dibulatkan ke jam terdekat (menit 30 ke atas naik ke jam berikutnya).
- **Jam yang lebih baik** dicari pada pukul 06.00 sampai 21.00 di hari yang sama.

### Lokasi Saya (LBS)
- Aplikasi meminta izin lokasi lewat dialog penjelasan, lalu mengambil posisi dengan `geolocator`.
- Nama kota dicari dari koordinat lewat Nominatim (OpenStreetMap), lalu dicocokkan dengan **nama** kota
  favorit (bukan jarak ke pusat kota). Bila gagal (offline), cadangannya adalah jarak 3 km ke pusat kota.
- **Koordinat GPS tidak disimpan.** Posisi hanya dipakai untuk mencari nama kota dan mengambil cuaca.
- **Favorit terdekat** diurutkan berdasarkan **jarak lurus ke titik pusat** tiap kota favorit
  (`Geolocator.distanceBetween`). Jarak di bawah 150 m ditulis "Kamu di sini".

### Cache Offline
Kunci cache adalah koordinat dibulatkan 2 desimal (sekitar 1 km), sehingga posisi GPS yang bergeser sedikit
memakai entri yang sama. Cache disimpan di Hive bersama waktu penyimpanannya.

### Isolasi Data Akun
Aplikasi menyimpan **satu akun per perangkat**. Mendaftar atau login dengan akun berbeda menghapus
pengingat, favorit, cache, dan foto profil akun sebelumnya, serta membatalkan notifikasinya.

### Izin
Pop-up izin lokasi dan notifikasi memakai tampilan yang sama. Izin notifikasi dicek langsung ke sistem
setiap tab Pengingat dibuka. Bila ditolak, tersedia tombol menuju pengaturan aplikasi.

---

## Sumber Data (API)

| Kebutuhan | Layanan | Keterangan |
|---|---|---|
| Cuaca dan prakiraan | [Open-Meteo Forecast API](https://open-meteo.com) | Tanpa API key. Suhu, kondisi, UV, angin, kelembapan, matahari |
| Cari kota | Open-Meteo Geocoding API | Dibatasi untuk Indonesia (`countryCode=ID`) |
| Nama kota dari koordinat | [Nominatim (OpenStreetMap)](https://nominatim.org) | Dipakai oleh Lokasi Saya |
| Ikon prakiraan 7 hari | OpenWeatherMap (gambar ikon) | Dengan ikon cadangan bila gagal dimuat |

Daftar **kota populer** (20 kota) tertulis tetap di aplikasi (`lib/models/popular_city.dart`).

---

## Penyimpanan Lokal

| Penyimpanan | Isi |
|---|---|
| **Hive** box `reminders` | Objek `Reminder` (judul, kota, koordinat, jam, tanggal, catatan, jenis, status) |
| **Hive** box `favorites` | Objek `FavoriteCity` (nama, provinsi, koordinat) |
| **Hive** box `weather_cache` | Cuaca terakhir per kota (JSON) dan waktu simpannya |
| **Shared Preferences** | Sesi (status login dan waktu login), akun terdaftar, nama lengkap, satuan suhu, mode gelap, foto profil |

---

## Teknologi

- **Flutter** (Dart SDK ^3.12.2), `setState` dan `Navigator` bawaan (tanpa GetX).
- Paket: `http`, `hive`, `hive_flutter`, `shared_preferences`, `geolocator`,
  `flutter_local_notifications`, `timezone`, `image_picker`, `crypto`.

---

## Struktur Folder

```
lib/
  main.dart                  Titik awal: inisialisasi Hive, pengaturan, notifikasi
  api/api_service.dart       Pengambilan data cuaca dan pencarian kota (HTTP)
  models/                    Model data (WeatherData, Activity, Reminder, FavoriteCity, ...)
  screens/                   Layar (login, register, root, beranda, kota, aktivitas, pengingat, profil, detail)
  services/                  Layanan (notifikasi, lokasi, cache, pengaturan, pengingat berikutnya)
  widgets/                   Widget yang dipakai ulang (kartu cuaca, kartu aktivitas, dialog izin, ...)
  theme/                     Tema terang dan gelap, gradien cuaca
test/                        Pengujian unit
assets/images/               Logo dan ikon aplikasi
```

---

## Cara Menjalankan

**Prasyarat:** Flutter SDK terpasang, serta HP Android (disarankan) atau emulator. Fitur notifikasi dan GPS
paling baik dicoba di HP fisik.

```bash
git clone https://github.com/Loddy04/payungin.git
cd payungin
flutter pub get
flutter run
```

Membuat dan memasang APK release langsung ke HP:

```bash
flutter build apk --release
flutter install
```

**Izin Android yang dipakai:** internet, lokasi (kasar dan akurat), notifikasi, alarm tepat waktu, dan
penjadwalan ulang saat HP menyala kembali.

---

## Akun Demo

| Username | Password |
|---|---|
| `adminpayungin` | `payungin123` |

Pengguna juga bisa mendaftar akun baru lewat layar Registrasi.

---

## Pemetaan Modul Praktikum

| Modul | Penerapan di Payungin |
|---|---|
| **II. Widget** | `MaterialApp`, `Scaffold`, `AppBar`, `Column`, `Row`, `Stack`, `Container`, `Text`, tombol, `Icon`, `Image`, `TextField`, `ListView`, `GridView`, `SingleChildScrollView` |
| **III. State dan Data** | `StatefulWidget`, `TextEditingController`, `setState`, conditional rendering (loading, sukses, gagal), model `User`, `Reminder`, `WeatherData` |
| **IV. Navigasi** | `Navigator.push`, `pushReplacement`, `pop`, `pushAndRemoveUntil` (logout), kirim data lewat constructor (Detail, form pengingat), `BottomNavigationBar` 5 tab |
| **V. HTTP Request** | Paket `http`, `Future` dan `async/await`, `try-catch`, `timeout`, `jsonDecode`, `fromJson`, tiga keadaan loading, sukses, gagal, `Future.wait` |
| **VI. Local Storage** | Shared Preferences (sesi dan pengaturan), Hive dengan adapter (`@HiveType`) untuk pengingat, favorit, dan cache |
| **VII. Notifikasi dan LBS** | `flutter_local_notifications` (channel, izin, jadwal `zonedSchedule`, notifikasi langsung), `geolocator` (izin, posisi, jarak, kota terdekat) |

**Kriteria proyek akhir:** autentikasi (login, registrasi, sesi, logout), CRUD (pengingat dan favorit),
seluruh modul, serta **bonus LBS**.

---

## Konsep OOP

| Konsep | Penerapan |
|---|---|
| Abstraksi | `Activity` (kelas abstrak) |
| Pewarisan | `JemurActivity`, `MotorActivity`, `MobilActivity`, `OutdoorActivity` mewarisi `Activity` |
| Polimorfisme | Layar memanggil `analyze()` pada tipe `Activity`, hasilnya berbeda menurut jenis aktivitas |
| Template Method | Alur penilaian ditulis sekali di `Activity.analyze()`, turunan hanya mengisi faktornya |
| Enkapsulasi | `WeatherData._temperature` privat dengan getter dan setter yang memvalidasi nilai |
| Constructor khusus | `WeatherData.empty()` (redirecting) dan `fromJson` (factory) |
| Singleton | `NotificationService` |
| Implements | `LocationException implements Exception` |
| Pewarisan framework | `Reminder` dan `FavoriteCity` mewarisi `HiveObject` |

---

## Pengujian

```bash
flutter analyze
flutter test
```

Pengujian unit mencakup mesin penilaian aktivitas, cache, logika lokasi (kota terdekat, pencocokan nama,
jarak), pembuatan pengingat dari hasil aktivitas, dan pengingat berikutnya.

---

## Pembagian Tugas

| Anggota | Tanggung jawab |
|---|---|
| **Loddy** | Data cuaca (API, model, cache), Beranda, Detail, Aktivitas, Lokasi Saya dan Favorit Terdekat, pencarian kota |
| **Salsabila** | Registrasi, login dan sesi, Profil dan pengaturan, Kota dan Favorit, Pengingat (CRUD) dan notifikasi, tema |

---

## Keterbatasan yang Diketahui

- Aplikasi menyimpan **satu akun per perangkat**. Mendaftar ulang menggantikan akun sebelumnya.
- Daftar kota populer tertulis tetap (20 kota). Kota lain dicari lewat kolom cari dan membutuhkan internet.
- Prakiraan untuk hari yang jauh (lebih dari 3 hari) kurang akurat.
- Fokus platform adalah Android.
