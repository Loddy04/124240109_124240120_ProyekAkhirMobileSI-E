import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/gear_item.dart';
import '../theme/app_theme.dart';
import 'add_gear_screen.dart';

// Layar daftar perlengkapan hujan (F7) — PBI-042
// Menampilkan daftar GearItem dari Hive box 'gear',
// progress "N dari M siap", checkbox isReady, tombol +/-, FAB tambah, hapus.
class GearScreen extends StatelessWidget {
  const GearScreen({super.key});

  // ---- Konfirmasi hapus item ------------------------------------------------
  Future<void> _confirmDelete(BuildContext context, GearItem item) async {
    final c = context.pc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Perlengkapan?', style: TextStyle(color: c.text)),
        content: Text(
          'Yakin ingin menghapus "${item.name}" dari daftar?',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await item.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Perlengkapan Hujan'),
        centerTitle: true,
      ),
      // FAB untuk tambah item baru
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddGearScreen()),
          );
        },
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<GearItem>('gear').listenable(),
        builder: (context, Box<GearItem> box, _) {
          final items = box.values.toList();

          // ---- Empty state ---------------------------------------------------
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.backpack_outlined, size: 56, color: c.accent),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Perlengkapan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan perlengkapan hujanmu\ndengan menekan tombol + di bawah.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // ---- Hitung progres "N dari M siap" --------------------------------
          final readyCount = items.where((i) => i.isReady).length;
          final totalCount = items.length;
          final progress = totalCount > 0 ? readyCount / totalCount : 0.0;

          return Column(
            children: [
              // ---- Header progres ------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kesiapan Perlengkapan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          Text(
                            '$readyCount dari $totalCount siap',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: c.glassBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 1.0 ? Colors.green : c.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Daftar item ---------------------------------------------
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        child: Row(
                          children: [
                            // Checkbox isReady
                            Checkbox(
                              value: item.isReady,
                              activeColor: c.accent,
                              onChanged: (val) {
                                item.isReady = val ?? false;
                                item.save();
                              },
                            ),

                            // Nama item
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: c.text,
                                  decoration: item.isReady
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationColor: c.textMuted,
                                ),
                              ),
                            ),

                            // Tombol kurangi qty
                            IconButton(
                              onPressed: item.quantity > 1
                                  ? () => item.decrease()
                                  : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: item.quantity > 1 ? c.text : c.textMuted,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),

                            // Jumlah barang
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: c.text,
                                ),
                              ),
                            ),

                            // Tombol tambah qty
                            IconButton(
                              onPressed: () => item.increase(),
                              icon: Icon(Icons.add_circle_outline, color: c.accent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),

                            const SizedBox(width: 4),

                            // Tombol hapus
                            IconButton(
                              onPressed: () => _confirmDelete(context, item),
                              icon: Icon(Icons.delete_outline, color: c.danger),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

