import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/playback_provider.dart';
import '../../karaoke_lyrics_view.dart';

class Style5Lyrics extends ConsumerStatefulWidget {
  final Color bgColor;

  const Style5Lyrics({super.key, required this.bgColor});

  @override
  ConsumerState<Style5Lyrics> createState() => _Style5LyricsState();
}

class _Style5LyricsState extends ConsumerState<Style5Lyrics> {
  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final lyrics = playback.lyrics;
    final track = playback.currentTrack;

    if (track == null || lyrics == null || lyrics.lines.isEmpty) {
      return Scaffold(
        backgroundColor: widget.bgColor,
        body: const Center(
          child: Text(
            'No Lyrics Available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final controller = ref.watch(playbackProvider.notifier);

    return Scaffold(
      backgroundColor: widget.bgColor,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Column(
          children: [
            // Top Header
            SafeArea(
              bottom: false,
              child: Padding(
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
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const IconButton(
                      icon: Icon(Icons.more_horiz_rounded, color: Colors.white),
                      onPressed: null, // Placeholder for report/options
                    ),
                  ],
                ),
              ),
            ),

            // Lyrics List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 40, left: 24, right: 24),
                child: KaraokeLyricsView(
                  lyricsData: lyrics,
                  currentPosition: controller.positionNotifier,
                  onTapLine: (position) => controller.seekTo(position),
                  textAlign: TextAlign.left,
                  activeStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  inactiveStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
