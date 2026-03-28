import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/playback_provider.dart';
import '../../now_playing_screen.dart';

/// Style 6: Tidal Mobile App Replica (Audiophile Minimalist)
/// Features a pure black (AMOLED) background, sharp square album art,
/// HiFi/FLAC quality badges, and an ultra-thin green progress bar.
class Style6MiniPlayer extends ConsumerWidget {
  const Style6MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);
    final track = playback.currentTrack;

    if (track == null) return const SizedBox.shrink();

    // Tidal uses pure black for the mini player
    const Color bgColor = Colors.black;

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
      child: Material(
        color: bgColor,
        elevation: 12,
        shadowColor: Colors.black,
        // Optional: Very slight rounding at the top if desired, but Tidal is often
        // completely edge-to-edge. We'll use 0 radius for a true blocky feel,
        // or a tiny 4px radius at top for subtle separation from the list below.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
        child: SizedBox(
          height: 64, // Slightly taller to accommodate the badge
          child: Stack(
            children: [
              // Main content row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),

                  // Album Art (Slightly Rounded Square)
                  Hero(
                    tag: 'album_cover_${track.id}',
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[900], // Fallback color
                        borderRadius: BorderRadius.circular(
                          6,
                        ), // Slightly curved
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _buildCoverImage(track.coverArtPath),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Metadata Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title and Badge Row
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500, // Not too bold
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Audiophile Quality Badge (e.g., FLAC, HiFi)
                            _buildQualityBadge(track),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Artist Name
                        Text(
                          track.artistName,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Play/Pause Button Only (Minimalist)
                  IconButton(
                    iconSize: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    icon: Icon(
                      playback.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => controller.togglePlay(),
                  ),
                ],
              ),

              // Bottom Progress Bar (Ultra-thin, Tidal Accent)
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
                      height: 1.5, // Extremely thin line
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
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
    );
  }

  Widget _buildQualityBadge(dynamic track) {
    String badgeText = 'HIGH';
    final qualityStr = track.quality as String?;
    final filePath = track.filePath as String? ?? '';

    // Check quality string or file extension
    final isFlac =
        (qualityStr != null && qualityStr.toLowerCase().contains('flac')) ||
        filePath.toLowerCase().endsWith('.flac');

    if (isFlac) {
      badgeText = 'MAX';
    } else if (qualityStr != null) {
      final q = qualityStr.toLowerCase();
      if (q.contains('wav') || q.contains('alac')) {
        badgeText = 'MAX';
      } else if (q.contains('mp3') || q.contains('aac') || q.contains('ogg')) {
        badgeText = 'HIGH';
      }
    }

    final isMax = badgeText == 'MAX';
    final textColor = isMax ? const Color(0xFFFFD700) : Colors.white70;
    final bgColor = isMax
        ? const Color(0xFFFFD700).withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4), // Slightly rounded
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
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
    return const Center(
      child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 24),
    );
  }
}
