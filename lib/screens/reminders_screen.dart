import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/permission_dialog.dart';
import 'add_reminder_screen.dart';

// Layar Daftar Pengingat Cuaca (F6 / PBI-032, PBI-034, PBI-083)
// Stateful agar bisa meminta izin notifikasi saat pertama kali dibuka
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _permAsked = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Minta izin notifikasi sekali saat halaman pertama dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionIfNeeded();
    });

    // Timer real-time tiap 10 detik agar status pengingat otomatis berpindah
    // ke riwayat saat jam terlewat tanpa perlu restart aplikasi
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Izin notifikasi: cek keadaan sebenarnya ke sistem, bukan penanda tersimpan.
  // Pop-up muncul bila izin mati, lalu diminta; bila tetap ditolak, arahkan ke pengaturan.
  Future<void> _requestPermissionIfNeeded() async {
    if (_permAsked) return;
    if (await NotificationService().isEnabled()) return;
    if (!mounted) return;
    _permAsked = true;

    final setuju = await tampilkanDialogIzin(
      context,
      ikon: Icons.notifications_active_rounded,
      judul: 'Aktifkan Notifikasi',
      isi: 'Payungin akan memberi tahu kondisi cuaca sesuai jadwal yang Anda tentukan agar selalu siap beraktivitas.',
    );
    if (!setuju) {
      // Nanti Saja: boleh muncul lagi saat kembali ke tab ini
      _permAsked = false;
      return;
    }

    final diizinkan = await NotificationService().requestPermission();
    if (diizinkan || !mounted) return;

    // Ditolak (termasuk ditolak permanen): tawarkan membuka pengaturan aplikasi
    final buka = await tampilkanDialogIzin(
      context,
      ikon: Icons.notifications_off_outlined,
      judul: 'Izin Notifikasi Ditolak',
      isi: 'Izinkan notifikasi lewat pengaturan aplikasi agar pengingat bisa berbunyi.',
      tombolUtama: 'Buka pengaturan',
      tombolKedua: 'Batal',
    );
    if (buka) await Geolocator.openAppSettings();
  }

  // Format tanggal pengingat untuk tampilan kartu
  String _formatReminderDate(Reminder r) {
    if (r.repeatDaily) return 'Setiap Hari';
    if (r.date == null || r.date!.isEmpty) return 'Sekali (Hari ini/Besok)';

    final dt = DateTime.tryParse(r.date!);
    if (dt == null) return r.date!;

    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final namaHari = hari[dt.weekday - 1];
    final namaBulan = bulan[dt.month - 1];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Hari ini (${dt.day} $namaBulan ${dt.year})';
    if (diff == 1) return 'Besok (${dt.day} $namaBulan ${dt.year})';
    return '$namaHari, ${dt.day} $namaBulan ${dt.year}';
  }

  // Dialog konfirmasi hapus pengingat dengan aturan ID berbasis key Hive (PBI-034)
  void _confirmDelete(BuildContext context, Reminder reminder) {
    final c = context.pc;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          title: Text(
            'Hapus Pengingat',
            style: TextStyle(color: c.text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus pengingat "${reminder.title}"?',
            style: TextStyle(color: c.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Batal', style: TextStyle(color: c.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // Aturan PBI-034: batalkan notifikasi sebelum menghapus data Hive
                final reminderKey = reminder.key;
                if (reminderKey is int) {
                  NotificationService().cancel(reminderKey);
                }

                // Hapus objek dari Hive
                await reminder.delete();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pengingat berhasil dihapus.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                'Hapus',
                style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Langsung aktifkan kembali pengingat dari riwayat ke aktif (tanpa perlu form edit)
  Future<void> _reuseReminderDirectly(Reminder reminder) async {
    final now = DateTime.now();
    final parts = reminder.time.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Jika jam hari ini sudah lewat, setel ke besok; jika belum, setel ke hari ini
    final candidateToday = DateTime(now.year, now.month, now.day, hour, minute);
    final targetDate = candidateToday.isAfter(now)
        ? candidateToday
        : candidateToday.add(const Duration(days: 1));

    final dateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    reminder.date = dateStr;
    reminder.notifOn = true;
    await reminder.save();

    // Jadwalkan ulang notifikasi jika ID key int
    final reminderKey = reminder.key;
    if (reminderKey is int) {
      NotificationService().cancel(reminderKey);
    }
    NotificationService().schedule(reminder);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pengingat "${reminder.title}" kembali aktif!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Kartu pengingat — dipakai untuk bagian Aktif maupun Riwayat
  Widget _buildReminderCard(Reminder reminder, {bool isHistory = false}) {
    final c = context.pc;

    // Label & warna chip berbeda untuk riwayat (sudah lewat) vs aktif
    final chipLabel = isHistory ? 'Nonaktif' : (reminder.notifOn ? 'Aktif' : 'Mati');
    final chipIcon = isHistory
        ? Icons.notifications_off_outlined
        : (reminder.notifOn ? Icons.notifications_active_rounded : Icons.notifications_off_outlined);
    final chipColor = isHistory ? c.textMuted : (reminder.notifOn ? c.chipText : c.textMuted);
    final chipBg = isHistory ? c.glass : (reminder.notifOn ? c.chipBg : c.glass);

    return GlassCard(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Atas: Jam, Tanggal, dan Status Notifikasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 20, color: c.accent),
                        const SizedBox(width: 8),
                        Text(
                          '${reminder.time} WIB',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          reminder.repeatDaily
                              ? Icons.repeat_rounded
                              : Icons.calendar_today_rounded,
                          size: 13,
                          color: c.accent,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _formatReminderDate(reminder),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Kota pengingat (hanya bila sudah dipilih di form)
                    if (reminder.cityName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: c.accent),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              reminder.cityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Chip status notifikasi (Aktif/Mati/Nonaktif)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                  border: Border.all(color: c.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipColor),
                    const SizedBox(width: 4),
                    Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Judul Pengingat
          Text(
            reminder.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),

          // Catatan Tambahan (jika ada)
          if (reminder.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.glass,
                borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                border: Border.all(color: c.glassBorder),
              ),
              child: Text(
                reminder.note,
                style: TextStyle(fontSize: 12, color: c.text, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Tombol Aksi
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Tombol "Pakai lagi" hanya muncul di bagian Riwayat
              if (isHistory)
                TextButton.icon(
                  onPressed: () => _reuseReminderDirectly(reminder),
                  icon: Icon(Icons.refresh_rounded, size: 16, color: c.accent),
                  label: Text('Pakai lagi', style: TextStyle(color: c.accent)),
                ),
              if (isHistory) const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddReminderScreen(reminder: reminder),
                    ),
                  );
                },
                icon: Icon(Icons.edit_outlined, size: 16, color: c.accent),
                label: Text('Ubah', style: TextStyle(color: c.accent)),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _confirmDelete(context, reminder),
                icon: Icon(Icons.delete_outline_rounded, size: 16, color: c.danger),
                label: Text('Hapus', style: TextStyle(color: c.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final box = Hive.box<Reminder>('reminders');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Pengingat Cuaca'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? c.onAccent : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Pengingat', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReminderScreen()),
          );
        },
      ),
      body: ValueListenableBuilder<Box<Reminder>>(
        valueListenable: box.listenable(),
        builder: (context, reminderBox, _) {
          // Tampilan kosong jika belum ada pengingat
          if (reminderBox.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: GlassCard(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: c.accent.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Pengingat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buat pengingat agar Anda siap sedia membawa payung sebelum beraktivitas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddReminderScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tambah Pengingat Pertama'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Pisahkan pengingat aktif dan riwayat (berdasarkan scheduledDateTime: tanggal + jam)
          final now = DateTime.now();
          final allReminders = reminderBox.values.toList();

          // Helper untuk menghitung jadwal eksekusi terdekat suatu pengingat
          DateTime getNextTriggerTime(Reminder r) {
            final parts = r.time.split(':');
            final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
            final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

            if (r.repeatDaily) {
              final todayTime = DateTime(now.year, now.month, now.day, hour, minute);
              return todayTime.isAfter(now) ? todayTime : todayTime.add(const Duration(days: 1));
            } else {
              return r.scheduledDateTime ??
                  (r.dateTime != null
                      ? DateTime(r.dateTime!.year, r.dateTime!.month, r.dateTime!.day, hour, minute)
                      : DateTime(now.year, now.month, now.day, hour, minute));
            }
          }

          final active = allReminders.where((r) {
            if (r.repeatDaily) return true;
            final scheduled = r.scheduledDateTime ?? r.dateTime;
            if (scheduled == null) return true; // default aktif jika tanpa tanggal spesifik
            return scheduled.isAfter(now);
          }).toList();

          // Urutkan pengingat aktif: yang paling cepat/awal dieksekusi tampil paling atas
          active.sort((a, b) => getNextTriggerTime(a).compareTo(getNextTriggerTime(b)));

          final history = allReminders.where((r) {
            if (r.repeatDaily) return false;
            final scheduled = r.scheduledDateTime ?? r.dateTime;
            if (scheduled == null) return false;
            return scheduled.isBefore(now);
          }).toList();

          // Riwayat diurutkan dari yang paling baru lewat (terkini ke terlama)
          history.sort((a, b) => getNextTriggerTime(b).compareTo(getNextTriggerTime(a)));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Bagian Aktif ──
                if (active.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Pengingat Aktif',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                  ),
                  ...active.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReminderCard(r),
                  )),
                ],

                // ── Bagian Riwayat ──
                if (history.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 10),
                    child: Text(
                      'Riwayat Pengingat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                  ...history.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReminderCard(r, isHistory: true),
                  )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
