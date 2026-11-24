import 'package:flutter/material.dart';

import '../models/weather_advice.dart';
import '../theme/app_theme.dart';

// Kartu Skor Payung dan saran singkat (F9).
// Hanya mengenal tipe WeatherAdvice: isi kartu berbeda otomatis menurut
// subclass-nya (polymorphism), jadi cukup dipanggil dengan AdviceCard(advice).
class AdviceCard extends StatelessWidget {
  final WeatherAdvice advice;

  const AdviceCard(this.advice, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    // Hijau (< 30), kuning (30-59), atau merah (>= 60), sudah sesuai mode terang/gelap
    final warna = c.scoreColor(advice.score);

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lencana skor berwarna
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: warna.withAlpha(36),
              border: Border.all(color: warna, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${advice.score}',
                  style: TextStyle(
                    color: warna,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Skor',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Judul, penjelasan, dan chip saran
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advice.message,
                  style: TextStyle(color: c.textMuted, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final saran in advice.recommendations)
                      InfoChip(label: saran),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
