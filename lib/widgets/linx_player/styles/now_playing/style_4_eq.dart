import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/playback_provider.dart';

class Style4EQ extends ConsumerWidget {
  const Style4EQ({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final track = playback.currentTrack;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414), // SC Dark
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24.0),
                height: 4.0,
                width: 40.0,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),

            const Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Audio Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildStatRow('Codec', track?.quality ?? 'Unknown'),
            const SizedBox(height: 16),
            _buildStatRow('Sample Rate', '44.1 kHz (Target)'),
            const SizedBox(height: 16),
            _buildStatRow('Bitrate', '1411 kbps (Lossless)'),
            const SizedBox(height: 16),
            _buildStatRow('DSP Effects', 'Bypassed (Audiophile Mode)'),

            const SizedBox(height: 48),

            // Visual mockup of an EQ to look nice
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(10, (index) {
                final heights = [
                  40.0,
                  60.0,
                  30.0,
                  80.0,
                  100.0,
                  120.0,
                  90.0,
                  70.0,
                  50.0,
                  45.0,
                ];
                return Container(
                  width: 12,
                  height: heights[index],
                  decoration: BoxDecoration(
                    color: index < 4
                        ? const Color(0xFFFF5500)
                        : Colors.white24, // SC Orange mock
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
