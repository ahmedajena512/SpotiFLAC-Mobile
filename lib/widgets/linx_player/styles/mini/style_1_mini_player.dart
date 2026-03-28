import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/player_appearance_provider.dart';
import 'package:spotiflac_android/utils/color_extractor.dart';
import 'package:spotiflac_android/widgets/linx_player/now_playing_screen.dart';

class Style1MiniPlayer extends ConsumerStatefulWidget {
  const Style1MiniPlayer({super.key});

  @override
  ConsumerState<Style1MiniPlayer> createState() => _Style1MiniPlayerState();
}

class _Style1MiniPlayerState extends ConsumerState<Style1MiniPlayer> {
  List<Color> _extractedColors = [];
  String? _lastCoverPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadColorsForCurrentTrack();
  }

  @override
  void didUpdateWidget(covariant Style1MiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadColorsForCurrentTrack();
  }

  Future<void> _loadColorsForCurrentTrack() async {
    final track = ref.read(playbackProvider).currentTrack;
    if (track == null || track.coverArtPath == _lastCoverPath) return;

    _lastCoverPath = track.coverArtPath;
    final colors = await ColorExtractor.getColors(track.coverArtPath);

    if (mounted && colors.isNotEmpty) {
      setState(() {
        _extractedColors = colors;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // We must continuously watch playbackProvider to rebuild when track changes
    final playback = ref.watch(playbackProvider);
    final track = playback.currentTrack;

    // If the track changed and we haven't loaded colors yet, trigger a load
    if (track?.coverArtPath != _lastCoverPath) {
      // Schedule microtask to avoid setState during build
      Future.microtask(() => _loadColorsForCurrentTrack());
    }

    if (!playback.hasTrack || track == null) return const SizedBox.shrink();

    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final controller = ref.read(playbackProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    // Determine background colors
    final hasExtractedColors = _extractedColors.length >= 2;
    final bgColors = hasExtractedColors
        ? _extractedColors
        : [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHighest,
          ];

    // Decide text colors based on background brightness if we extracted colors
    // But for a simple gradient, we can attempt to compute luminance
    final dominantLuminance = hasExtractedColors
        ? _extractedColors.first.computeLuminance()
        : 0.5;
    final isDarkBg = isAmoled || dominantLuminance < 0.5;
    final textColor = isAmoled
        ? Colors.white
        : (hasExtractedColors
              ? (isDarkBg ? Colors.white : Colors.black87)
              : colorScheme.onSurface);

    return GestureDetector(
      onTap: () => openNowPlayingScreen(context),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -300) {
          // Swipe up -> Open Now Playing
          openNowPlayingScreen(context);
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < -300) {
          // Swipe left -> Next track
          controller.next();
        } else if (details.primaryVelocity! > 300) {
          // Swipe right -> Previous track
          controller.previous();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              color: isAmoled ? Colors.black : null,
              gradient: isAmoled
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: bgColors.take(2).toList(),
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Album art
                      Hero(
                        tag: 'album_cover_${track.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: _buildCoverImage(track.coverArtPath),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Song info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artistName,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            iconSize: 22,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            icon: Icon(
                              Icons.skip_previous_rounded,
                              color: textColor,
                            ),
                            onPressed: () => controller.previous(),
                          ),
                          IconButton(
                            iconSize: 28,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            icon: Icon(
                              playback.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: textColor,
                            ),
                            onPressed: () => controller.togglePlay(),
                          ),
                          IconButton(
                            iconSize: 22,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            icon: Icon(
                              Icons.skip_next_rounded,
                              color: textColor,
                            ),
                            onPressed: () => controller.next(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Progress bar at bottom
                ValueListenableBuilder<Duration>(
                  valueListenable: controller.positionNotifier,
                  builder: (context, position, _) {
                    final durationSec = playback.duration.inMilliseconds;
                    final progress = durationSec > 0
                        ? (position.inMilliseconds / durationSec).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 10,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAmoled
                                ? Colors.white
                                : (hasExtractedColors
                                      ? (isDarkBg
                                            ? Colors.white
                                            : colorScheme.primary)
                                      : colorScheme.primary),
                          ),
                          minHeight: 3,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? coverPath) {
    if (coverPath != null && coverPath.isNotEmpty) {
      if (coverPath.startsWith('http://') || coverPath.startsWith('https://')) {
        return Image.network(
          coverPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      final file = File(coverPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
        size: 24,
      ),
    );
  }
}
