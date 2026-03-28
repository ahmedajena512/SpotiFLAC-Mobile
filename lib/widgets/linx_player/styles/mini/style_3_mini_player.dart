import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../now_playing_screen.dart';

class Style3MiniPlayer extends ConsumerWidget {
  const Style3MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final controller = ref.read(playbackProvider.notifier);
    
    if (playback.currentTrack == null) return const SizedBox.shrink();

    final track = playback.currentTrack!;
    final coverPath = track.coverArtPath;

    // We get the current position to calculate progress for the circular ring
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.positionNotifier,
      builder: (context, position, _) {
        final duration = playback.duration;
        double progress = 0.0;
        if (duration.inMilliseconds > 0) {
           progress = position.inMilliseconds / duration.inMilliseconds;
        }
        progress = progress.clamp(0.0, 1.0);

        return GestureDetector(
          onTap: () => openNowPlayingScreen(context),
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
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
          behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: isAmoled ? null : Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isAmoled 
                  ? _buildAmoledContainer(progress, coverPath, track, playback, controller)
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                      child: _buildBlurredContainer(progress, coverPath, track, playback, controller),
                    ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildAmoledContainer(double progress, String? coverPath, PlaybackTrack track, PlaybackState playback, PlaybackController controller) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      color: Colors.black, // Pure AMOLED black
      child: _buildContent(progress, coverPath, track, playback, controller),
    );
  }

  Widget _buildBlurredContainer(double progress, String? coverPath, PlaybackTrack track, PlaybackState playback, PlaybackController controller) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
      ),
      child: _buildContent(progress, coverPath, track, playback, controller),
    );
  }

  Widget _buildContent(double progress, String? coverPath, PlaybackTrack track, PlaybackState playback, PlaybackController controller) {
    return Row(
      children: [
        // Circular Album Art with Progress Ring
        SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. The Circular Progress Indicator
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2.5,
                                backgroundColor: Colors.white.withValues(alpha: 0.1), // Dimmed remaining track
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), // Active track progress
                              ),
                            ),
                            // 2. The Inner Circular Album Cover
                            SizedBox(
                              width: 38,
                              height: 38,
                              child: ClipOval(
                                child: _buildCover(coverPath),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Track Title & Artist (Marquee if necessary)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600, // Apple-style bold
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (track.artistName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                track.artistName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Play/Pause & Next Buttons (Apple styled simple icons)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => controller.togglePlay(),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => controller.next(),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                        ],
                      ),
      ],
    );
  }

  Widget _buildCover(String? coverPath) {
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
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note,
        color: Colors.white54,
        size: 20,
      ),
    );
  }
}
