import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../now_playing_screen.dart';

/// Style 5: Deezer Mobile App Replica
/// Features a floating dark container, squared album art,
/// minimalistic controls on the right, and a 2px progress bar glued to the very bottom edge.
class Style5MiniPlayer extends ConsumerStatefulWidget {
  const Style5MiniPlayer({super.key});

  @override
  ConsumerState<Style5MiniPlayer> createState() => _Style5MiniPlayerState();
}

class _Style5MiniPlayerState extends ConsumerState<Style5MiniPlayer> {
  PaletteGenerator? _palette;
  String? _lastCoverPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    final playback = ref.read(playbackProvider);
    final track = playback.currentTrack;
    if (track == null || track.coverArtPath == null) return;

    if (track.coverArtPath == _lastCoverPath) return;
    _lastCoverPath = track.coverArtPath;

    if (track.coverArtPath!.isEmpty) {
      if (mounted) setState(() => _palette = null);
      return;
    }

    try {
      final imageProvider = track.coverArtPath!.startsWith('http')
          ? NetworkImage(track.coverArtPath!)
          : FileImage(File(track.coverArtPath!)) as ImageProvider;

      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 10,
      );

      if (mounted) {
        setState(() {
          _palette = palette;
        });
      }
    } catch (e) {
      debugPrint('Error generating palette: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;

    if (track == null) return const SizedBox.shrink();

    if (track.coverArtPath != _lastCoverPath) {
      Future.microtask(() => _updatePalette());
    }

    // Deezer uses a solid, heavily darkened version of the dominant color
    // If no color available, fallback to a dark grey.
    Color bgColor = const Color(0xFF191922); // Default dark fallback

    if (isAmoled) {
      bgColor = Colors.black;
    } else if (_palette != null) {
      final dominant =
          _palette!.dominantColor?.color ?? _palette!.darkVibrantColor?.color;
      if (dominant != null) {
        final hsl = HSLColor.fromColor(dominant);
        // Darken and slightly saturate for that rich Deezer feel
        bgColor = hsl
            .withLightness((hsl.lightness * 0.35).clamp(0.1, 0.25))
            .withSaturation((hsl.saturation * 1.2).clamp(0.3, 0.8))
            .toColor();
      }
    }

    return GestureDetector(
      onTap: () => openNowPlayingScreen(context),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -300) {
          openNowPlayingScreen(context);
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -300) {
            controller.next();
          } else if (details.primaryVelocity! > 300) {
            controller.previous();
          }
        }
      },
      child: Padding(
        // Deezer floats slightly above the bottom bar with horizontal margins
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10), // Clean rounded corners
          clipBehavior: Clip.antiAlias, // Critical for the bottom progress bar
          child: Container(
            color: bgColor,
            height: 60, // Slightly taller container
            child: Stack(
              children: [
                // Main Info Row
                Row(
                  children: [
                    const SizedBox(width: 8),
                    // Squared Album Art with very slight rounding
                    Hero(
                      tag: 'album_cover_${track.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: _buildCoverImage(track.coverArtPath),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Track Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.bold, // Deezer uses bold titles
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artistName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Controls (Devices, Play/Pause, Next)
                    IconButton(
                      iconSize: 28,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        playback.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => controller.togglePlay(),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      iconSize: 28,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => controller.next(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),

                // Deezer's signature bottom progress bar (2px thin, edge-to-edge)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: controller.positionNotifier,
                    builder: (context, position, child) {
                      final durationMillis = playback.duration.inMilliseconds;
                      final positionMillis = position.inMilliseconds;
                      final progress = durationMillis > 0
                          ? (positionMillis / durationMillis).clamp(0.0, 1.0)
                          : 0.0;

                      return SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      }
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      color: const Color(0xFF2B2B36),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
        size: 22,
      ),
    );
  }
}
