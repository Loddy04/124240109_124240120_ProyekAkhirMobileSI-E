import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/gear_item.dart';
import '../theme/app_theme.dart';
import '../widgets/input_field.dart';

// Layar tambah perlengkapan hujan (F7) — PBI-042
// Form sederhana: nama barang, jumlah default 1.
// Quantity bisa diubah dengan +/- sebelum menyimpan.
class AddGearScreen extends StatefulWidget {
  const AddGearScreen({super.key});

  @override
  State<AddGearScreen> createState() => _AddGearScreenState();
}

class _AddGearScreenState extends State<AddGearScreen> {
  final _nameCtrl = TextEditingController();
  int _quantity = 1;
  String? _nameError;

  // Status proses simpan (loading / sukses / error)
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ---- Tambah/kurangi quantity sebelum simpan ------------------------------
  void _increaseQty() => setState(() => _quantity++);
  void _decreaseQty() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  // ---- Simpan ke Hive box 'gear' -------------------------------------------
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    // Validasi nama tidak boleh kosong
    if (name.isEmpty) {
      setState(() => _nameError = 'Nama barang tidak boleh kosong');
      return;
    }

    setState(() {
      _nameError = null;
      _isSaving = true;
    });

    try {
      final box = Hive.box<GearItem>('gear');
      await box.add(GearItem(name: name, quantity: _quantity));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar kustom mengikuti tema
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
                    'Tambah Perlengkapan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---- Input nama barang ------------------------------------
                          InputField(
                            controller: _nameCtrl,
                            label: 'Nama Barang',
                            hint: 'Contoh: Payung, Jas Hujan...',
                            isError: _nameError != null,
                            prefixIcon: Icons.backpack_outlined,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                          ),

                          const SizedBox(height: 20),

                          // ---- Jumlah barang ----------------------------------------
                          Text(
                            'Jumlah',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Tombol kurangi
                              IconButton(
                                onPressed: _quantity > 1 ? _decreaseQty : null,
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  size: 32,
                                  color: _quantity > 1 ? c.text : c.textMuted,
                                ),
                              ),

                              // Tampilkan angka
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '$_quantity',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: c.text,
                                    ),
                                  ),
                                ),
                              ),

                              // Tombol tambah
                              IconButton(
                                onPressed: _increaseQty,
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  size: 32,
                                  color: c.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---- Tombol Simpan ----------------------------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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

