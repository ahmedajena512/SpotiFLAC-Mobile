import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/playback_provider.dart';
import '../../karaoke_lyrics_view.dart';

class Style4Lyrics extends ConsumerStatefulWidget {
  const Style4Lyrics({super.key});

  @override
  ConsumerState<Style4Lyrics> createState() => _Style4LyricsState();
}

class _Style4LyricsState extends ConsumerState<Style4Lyrics> {
  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final lyrics = playback.lyrics;
    final track = playback.currentTrack;

    if (track == null || lyrics == null || lyrics.lines.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No Lyrics Available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final controller = ref.watch(playbackProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Background heavy blur
            Positioned.fill(
              child: Opacity(
                opacity: 0.4,
                child: Hero(
                  tag: 'album_cover_${track.id}',
                  child: _buildCoverImage(track.coverArtPath),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Top Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),

            // Lyrics List
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 80.0,
                  left: 32.0,
                  right: 32.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 80.0,
                    left: 32.0,
                    right: 32.0,
                  ),
                  child: KaraokeLyricsView(
                    lyricsData: lyrics,
                    currentPosition: controller.positionNotifier,
                    onTapLine: (position) => controller.seekTo(position),
                    textAlign: TextAlign.left,
                    activeStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    inactiveStyle: const TextStyle(
                      color: Colors.white70,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.black),
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      }
    }
    return Container(color: Colors.black);
  }
}
