import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/playback_provider.dart';
import '../../karaoke_lyrics_view.dart';

class TidalLyricsScreen extends ConsumerWidget {
  final bool isAmoled;
  const TidalLyricsScreen({super.key, this.isAmoled = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black, // Pure black background
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Current song title indicator
                  if (playback.currentTrack != null)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            playback.currentTrack!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            playback.currentTrack!.artistName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 48), // Balance for centering
                ],
              ),
            ),

            // Lyrics View
            Expanded(
              child: playback.lyrics != null
                  ? KaraokeLyricsView(
                      lyricsData: playback.lyrics,
                      currentPosition: controller.positionNotifier,
                      textAlign: TextAlign.center,
                      activeStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 28, // Distinctive sizing
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                      inactiveStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 28,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                      onTapLine: (duration) {
                        controller.seekTo(duration);
                      },
                    )
                  : const Center(
                      child: Text(
                        "Lyrics not available",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
