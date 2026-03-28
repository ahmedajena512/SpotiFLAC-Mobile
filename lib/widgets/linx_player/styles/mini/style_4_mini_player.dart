import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../now_playing_screen.dart';

class Style4MiniPlayer extends ConsumerWidget {
  const Style4MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const NowPlayingScreen(),
            fullscreenDialog: true,
          ),
        );
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => const NowPlayingScreen(),
              fullscreenDialog: true,
            ),
          );
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            controller.previous();
          } else if (details.primaryVelocity! < 0) {
            controller.next();
          }
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
        child: isAmoled
            ? _buildAmoledContainer(controller, playback, track)
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: _buildBlurredContainer(controller, playback, track),
              ),
      ),
    );
  }

  Widget _buildAmoledContainer(PlaybackController controller, PlaybackState playback, PlaybackTrack track) {
    return Container(
      height: 64, // Slim, consistent height
      width: double.infinity,
      color: Colors.black,
      child: _buildContent(controller, playback, track),
    );
  }

  Widget _buildBlurredContainer(PlaybackController controller, PlaybackState playback, PlaybackTrack track) {
    return Container(
      height: 64, // Slim, consistent height
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65), // Smooth translucent background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildContent(controller, playback, track),
    );
  }

  Widget _buildContent(PlaybackController controller, PlaybackState playback, PlaybackTrack track) {
    return Stack(
      children: [
        // Content
        Row(
          children: [
            // Album Art (Strict square inside the rounded container)
            SizedBox(
                      width: 64,
                      height: 64,
                      child: Hero(
                        tag: 'album_cover_${track.id}',
                        child: _buildCoverImage(track.coverArtPath),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Track Info
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
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artistName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
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
                          icon: Icon(
                            playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          iconSize: 32,
                          onPressed: () => controller.togglePlay(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                          ),
                          iconSize: 32,
                          onPressed: () => controller.next(),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ],
                ),
                
                // Signature Progress Bar at the very bottom (White)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: controller.positionNotifier,
                    builder: (context, position, _) {
                      final duration = playback.duration.inMilliseconds;
                      final pos = position.inMilliseconds;
                      double progress = duration > 0 ? pos / duration : 0.0;
                      
                      return LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), // Neutral sleek white
                        minHeight: 1.5, // Extremely thin
                      );
                    },
                  ),
                ),
              ],
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
          return Image.file(
            file,
            fit: BoxFit.cover,
          );
        }
      }
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      color: Colors.grey[850],
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}
