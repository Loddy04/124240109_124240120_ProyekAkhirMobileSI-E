import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/input_field.dart';

// Layar Form Tambah dan Ubah Pengingat Cuaca (F6 / PBI-033)
// Mendukung mode tambah baru dan edit data berbasis Hive key
class AddReminderScreen extends StatefulWidget {
  final int? index;
  final Reminder? reminder;
  final String? judulAwal;
  final String? kotaAwal;
  // Flag untuk menandai pemakaian kembali (Pakai lagi)
  final bool isReuse;

  const AddReminderScreen({
    super.key,
    this.index,
    this.reminder,
    this.judulAwal,
    this.kotaAwal,
    this.isReuse = false,
  });


  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late bool _isEditMode;
  late String _selectedTime;
  late DateTime _selectedDate;
  late double _lat;
  late double _lon;
  late bool _notifOn;
  late bool _repeatDaily;

  bool _isTitleError = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.reminder != null && !widget.isReuse;

    final r = widget.reminder;
    _titleController = TextEditingController(
      text: r?.title ?? widget.judulAwal ?? '',
    );
    _noteController = TextEditingController(text: r?.note ?? '');

    final now = DateTime.now();
    final currentHourStr = now.hour.toString().padLeft(2, '0');
    final currentMinuteStr = now.minute.toString().padLeft(2, '0');
    _selectedTime = r?.time ?? '$currentHourStr:$currentMinuteStr';
    _lat = r?.lat ?? SettingsService.mainLat;
    _lon = r?.lon ?? SettingsService.mainLon;
    _notifOn = r?.notifOn ?? true;
    _repeatDaily = r?.repeatDaily ?? false;

    if (r?.date != null && r!.date!.isNotEmpty) {
      _selectedDate = DateTime.tryParse(r.date!) ?? now;
    } else {
      _selectedDate = now;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Format tanggal bahasa Indonesia
  String _formatDateIndo(DateTime dt) {
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final namaHari = hari[dt.weekday - 1];
    final namaBulan = bulan[dt.month - 1];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    String relLabel = '';
    if (diff == 0) {
      relLabel = ' (Hari ini)';
    } else if (diff == 1) {
      relLabel = ' (Besok)';
    }

    return '$namaHari, ${dt.day} $namaBulan ${dt.year}$relLabel';
  }

  // Pemilih tanggal — dibatasi maksimal 7 hari ke depan (hari ini s.d H+6)
  // sesuai rentang prakiraan cuaca Open-Meteo
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDate.isBefore(today) ? today : _selectedDate;
    final maxDate = today.add(const Duration(days: 6)); // 7 hari total (hari ini s.d H+6)

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(maxDate) ? maxDate : initialDate,
      firstDate: today,
      lastDate: maxDate,
      helpText: 'Pilih Tanggal Pengingat (Maks 7 Hari)',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Pemilih jam menggunakan showTimePicker format 24 jam Indonesia (tanpa AM/PM)
  Future<void> _pickTime() async {
    final parts = _selectedTime.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 7;
    final initialMinute = int.tryParse(parts[1]) ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        // Memaksa format 24 jam waktu Indonesia (00:00 s.d 23:59 tanpa AM/PM)
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _selectedTime = '$hourStr:$minuteStr';
      });
    }
  }

  // Format string tanggal "yyyy-MM-dd"
  String get _dateString =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  // Proses simpan pengingat (tambah baru atau simpan perubahan)
  Future<void> _saveReminder() async {
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();

    setState(() {
      _isTitleError = false;
    });

    // Validator form tidak boleh kosong
    if (title.isEmpty) {
      setState(() => _isTitleError = true);
      _showSnackBar('Judul pengingat tidak boleh kosong.');
      return;
    }

    final box = Hive.box<Reminder>('reminders');
    final savedDate = _repeatDaily ? null : _dateString;

    // Validasi waktu lampau jika pengingat disetel untuk satu kali (bukan setiap hari)
    if (!_repeatDaily) {
      final now = DateTime.now();
      final parts = _selectedTime.split(':');
      final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );

      if (scheduledDateTime.isBefore(now)) {
        _showSnackBar('Waktu pengingat tidak boleh di masa lalu.');
        return;
      }
    }

    if (_isEditMode) {
      // 1. Mode Edit: perbarui object pengingat dan simpan
      final r = widget.reminder!;
      r.title = title;
      r.cityName = r.cityName; // pertahankan nilai kota bawaan
      r.lat = _lat;
      r.lon = _lon;
      r.time = _selectedTime;
      r.note = note;
      r.notifOn = _notifOn;
      r.repeatDaily = _repeatDaily;
      r.date = savedDate;

      await r.save();

      // Aturan ID berbasis key (PBI-034): batalkan jadwal lama sebelum menjadwalkan ulang
      final reminderKey = r.key;
      if (reminderKey is int) {
        NotificationService().cancel(reminderKey);
      }

      if (_notifOn) {
        NotificationService().schedule(r);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengingat berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // 2. Mode Tambah Baru: buat objek dan simpan dengan box.add (PBI-034)
      final newReminder = Reminder(
        title: title,
        cityName: '',
        lat: _lat,
        lon: _lon,
        time: _selectedTime,
        note: note,
        notifOn: _notifOn,
        repeatDaily: _repeatDaily,
        date: savedDate,
      );

      await box.add(newReminder);

      // Jadwalkan notifikasi jika opsi notifikasi aktif
      if (_notifOn) {
        NotificationService().schedule(newReminder);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengingat berhasil disimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Navigator.pop(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.pc.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar kustom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Ubah Pengingat' : 'Tambah Pengingat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),

            // Konten Formulir
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kartu Input Data Utama
                    GlassCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Judul Pengingat
                          InputField(
                            controller: _titleController,
                            label: 'Judul Pengingat',
                            hint: 'Misal: Bawa payung sebelum kuliah',
                            prefixIcon: Icons.alarm_outlined,
                            isError: _isTitleError,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_isTitleError) setState(() => _isTitleError = false);
                            },
                          ),
                          const SizedBox(height: 18),

                          // Pemilih Jam Pengingat
                          Text(
                            'Waktu Pengingat',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(AppTheme.radiusField),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: c.glass,
                                borderRadius: BorderRadius.circular(AppTheme.radiusField),
                                border: Border.all(color: c.glassBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: c.accent, size: 22),
                                      const SizedBox(width: 12),
                                      Text(
                                        '$_selectedTime WIB',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: c.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Pilih Jam',
                                    style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Pemilih Tanggal Pengingat (Maks 7 hari sesuai batas prediksi cuaca)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tanggal Pengingat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
                              ),
                              if (!_repeatDaily)
                                Text(
                                  'Maks 7 hari',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: c.accent,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _repeatDaily ? null : _pickDate,
                            borderRadius: BorderRadius.circular(AppTheme.radiusField),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: _repeatDaily ? c.glass.withValues(alpha: 0.4) : c.glass,
                                borderRadius: BorderRadius.circular(AppTheme.radiusField),
                                border: Border.all(color: c.glassBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          color: _repeatDaily ? c.textMuted : c.accent,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            _repeatDaily
                                                ? 'Setiap Hari (Otomatis)'
                                                : _formatDateIndo(_selectedDate),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: _repeatDaily ? c.textMuted : c.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_repeatDaily)
                                    Text(
                                      'Pilih Tanggal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _repeatDaily
                                ? 'Notifikasi akan aktif setiap hari pada jam tersebut.'
                                : 'Prakiraan cuaca akurat tersedia maksimal 7 hari ke depan.',
                            style: TextStyle(fontSize: 11, color: c.textMuted),
                          ),
                          const SizedBox(height: 18),

                          // Catatan Tambahan
                          InputField(
                            controller: _noteController,
                            label: 'Catatan Tambahan (Opsional)',
                            hint: 'Misal: Simpan jas hujan di jok motor',
                            prefixIcon: Icons.notes_rounded,
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kartu Pengaturan Notifikasi
                    GlassCard(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Aktifkan Notifikasi',
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.text),
                            ),
                            subtitle: Text(
                              'Munculkan pemberitahuan cuaca pada jam yang ditentukan',
                              style: TextStyle(fontSize: 12, color: c.textMuted),
                            ),
                            value: _notifOn,
                            onChanged: (val) async {
                              if (val) {
                                final granted = await NotificationService().requestPermission();
                                if (!granted) {
                                  if (mounted) {
                                    _showSnackBar(
                                      'Izin notifikasi belum diberikan. Aktifkan izin pada pengaturan perangkat.',
                                    );
                                  }
                                  return;
                                }
                              }
                              setState(() => _notifOn = val);
                            },
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Ulangi Setiap Hari',
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.text),
                            ),
                            subtitle: Text(
                              'Bunyikan notifikasi setiap hari pada jam yang sama',
                              style: TextStyle(fontSize: 12, color: c.textMuted),
                            ),
                            value: _repeatDaily,
                            onChanged: _notifOn
                                ? (val) {
                                    setState(() => _repeatDaily = val);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Simpan
                    ElevatedButton(
                      onPressed: _saveReminder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        ),
                      ),
                      child: Text(
                        _isEditMode ? 'Simpan Perubahan' : 'Buat Pengingat',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
