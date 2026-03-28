import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../now_playing_screen.dart';

/// Style 2: Spotify Mobile App Replica
/// Features a dark, flat bar with a thin progress line at the very bottom,
/// and minimalist controls (just Play/Pause).
class Style2MiniPlayer extends ConsumerStatefulWidget {
  const Style2MiniPlayer({super.key});

  @override
  ConsumerState<Style2MiniPlayer> createState() => _Style2MiniPlayerState();
}

class _Style2MiniPlayerState extends ConsumerState<Style2MiniPlayer> {
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
    final track = playback.currentTrack;
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;

    if (track == null) return const SizedBox.shrink();

    // Trigger palette update if track changed
    if (track.coverArtPath != _lastCoverPath) {
      // Need microtask to avoid setState during build
      Future.microtask(() => _updatePalette());
    }

    Color bgColor = const Color(0xFF121212); // Default dark grey

    if (isAmoled) {
      bgColor = Colors.black;
    } else if (_palette != null) {
      final dominant = _palette!.dominantColor?.color;
      final muted = _palette!.darkMutedColor?.color;

      final selectedColor = muted ?? dominant;

      if (selectedColor != null) {
        // Create an even darker variant to ensure it looks like a bottom bar
        final hsl = HSLColor.fromColor(selectedColor);
        bgColor = hsl
            .withLightness((hsl.lightness * 0.4).clamp(0.05, 0.4))
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          clipBehavior:
              Clip.antiAlias, // Ensures the bottom progress bar doesn't spill
          child: Container(
            color: bgColor,
            height: 56,
            child: Stack(
              children: [
                // Main content
                Row(
                  children: [
                    const SizedBox(width: 8),
                    // Album art with Hero
                    Hero(
                      tag: 'album_cover_${track.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: _buildCoverImage(track.coverArtPath),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Song info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
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

                    // Controls
                    IconButton(
                      iconSize: 26,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(12),
                      icon: Icon(
                        playback.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => controller.togglePlay(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),

                // Bottom Progress Bar (Spotify style thin line)
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
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
        size: 20,
      ),
    );
  }
}
