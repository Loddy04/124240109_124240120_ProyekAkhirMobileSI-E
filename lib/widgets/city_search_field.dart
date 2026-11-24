import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../models/city_result.dart';
import '../theme/app_theme.dart';

// Kolom Cari Kota (F4) yang dipakai di layar Kota dan Kelola Favorit.
// Seluruh logika pencarian ada di sini: form, validator (minimal 3 huruf),
// dan pemanggilan ApiService.searchCity (hanya kota Indonesia).
// Layar pemakai cukup menerima hasilnya lewat callback.
class CitySearchField extends StatefulWidget {
  final String hintText;

  // Dipanggil saat pencarian dimulai, berhasil, gagal, atau dibersihkan
  final VoidCallback onSearching;
  final ValueChanged<List<CityResult>> onResult;
  final ValueChanged<String> onError;
  final VoidCallback onClear;

  const CitySearchField({
    super.key,
    required this.hintText,
    required this.onSearching,
    required this.onResult,
    required this.onError,
    required this.onClear,
  });

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Validator: tidak boleh kosong dan minimal 3 huruf
  String? _validasi(String? nilai) {
    final teks = (nilai ?? '').trim();
    if (teks.isEmpty) return 'Nama kota tidak boleh kosong.';
    if (teks.length < 3) return 'Minimal 3 huruf.';
    return null;
  }

  Future<void> _cari() async {
    FocusScope.of(context).unfocus();
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    widget.onSearching();

    try {
      final hasil = await ApiService.searchCity(_controller.text);
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onResult(hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onError('Tidak bisa mencari kota. Periksa koneksi internet.');
    }
  }

  // Tombol x: kosongkan kolom dan kembali ke daftar awal
  void _hapus() {
    _controller.clear();
    _formKey.currentState?.reset();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _controller,
                validator: _validasi,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _cari(),
                style: TextStyle(color: c.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                  // Tanpa bingkai agar menyatu dengan kartu kaca
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            // Tombol x muncul hanya bila kolom berisi teks
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, nilai, _) {
                if (nilai.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: c.textMuted, size: 18),
                  onPressed: _hapus,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(onPressed: _cari, child: const Text('Cari')),
            ),
          ],
        ),
      ),
    );
  }
}
