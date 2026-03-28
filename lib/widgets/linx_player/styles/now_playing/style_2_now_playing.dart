import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../../../constants/playback_constants.dart';
import '../../karaoke_lyrics_view.dart';

/// Style 2: Spotify Full Screen Layout Replica
/// Features a static dominant color gradient, classic slider, aligned controls,
/// and a bottom draggable sheet for Lyrics.
class Style2NowPlaying extends ConsumerStatefulWidget {
  const Style2NowPlaying({super.key});

  @override
  ConsumerState<Style2NowPlaying> createState() => _Style2NowPlayingState();
}

class _Style2NowPlayingState extends ConsumerState<Style2NowPlaying> {
  Color _dominantColor = const Color(0xFF1E1E1E);
  Color _darkMutedColor = const Color(0xFF121212);
  Color _lyricsColor = const Color(0xFF2B2B2B);
  String? _lastCoverPath;
  double _tempSliderValue = -1.0;
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _extractColors() async {
    final track = ref.read(playbackProvider).currentTrack;
    if (track == null ||
        track.coverArtPath == null ||
        track.coverArtPath!.isEmpty) {
      return;
    }
    if (track.coverArtPath == _lastCoverPath) return;
    _lastCoverPath = track.coverArtPath;

    try {
      final imageProvider = track.coverArtPath!.startsWith('http')
          ? NetworkImage(track.coverArtPath!)
          : FileImage(File(track.coverArtPath!)) as ImageProvider;

      final palette = await PaletteGenerator.fromImageProvider(imageProvider);

      if (mounted) {
        setState(() {
          _dominantColor =
              palette.dominantColor?.color ?? const Color(0xFF1E1E1E);

          final hsl = HSLColor.fromColor(_dominantColor);
          _darkMutedColor = hsl
              .withLightness((hsl.lightness * 0.2).clamp(0.05, 0.15))
              .toColor();

          Color baseForLyrics =
              palette.darkVibrantColor?.color ??
              palette.mutedColor?.color ??
              _dominantColor;
          final hslLyrics = HSLColor.fromColor(baseForLyrics);
          // Spotify uses a very distinguished, slightly brighter but deeply saturated color for the lyrics card.
          _lyricsColor = hslLyrics
              .withSaturation((hslLyrics.saturation + 0.2).clamp(0.0, 1.0))
              .withLightness((hslLyrics.lightness).clamp(0.25, 0.45))
              .toColor();
        });
      }
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "${d.inMinutes}:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackState>(playbackProvider, (previous, next) {
      if (_pageController != null && _pageController!.hasClients) {
        final currentPage =
            _pageController!.page?.round() ?? _pageController!.initialPage;
        if (next.currentIndex != currentPage) {
          if ((next.currentIndex - currentPage).abs() > 1) {
            _pageController!.jumpToPage(next.currentIndex);
          } else {
            _pageController!.animateToPage(
              next.currentIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        }
      }
    });

    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;

    if (track == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pageController == null && playback.playlist.isNotEmpty) {
      _pageController = PageController(initialPage: playback.currentIndex);
    }

    if (track.coverArtPath != _lastCoverPath) {
      Future.microtask(() => _extractColors());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe down on the main background to pop the screen
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Standard Background Gradient (Spotify Style)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isAmoled ? Colors.black : null,
                  gradient: isAmoled
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _dominantColor.withValues(alpha: 0.8),
                            _darkMutedColor,
                            Colors.black,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                ),
              ),
            ),

            // Main UI
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Header
                  _buildHeader(context, track.albumName, playback, controller),

                  // Album Art
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0.0,
                          vertical: 16.0,
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            if (index != playback.currentIndex) {
                              controller.skipToIndex(index);
                            }
                          },
                          itemCount: playback.playlist.length,
                          itemBuilder: (context, index) {
                            final itemTrack = playback.playlist[index];
                            final isActive = index == playback.currentIndex;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Center(
                                child: Hero(
                                  tag: isActive
                                      ? 'album_cover_${itemTrack.id}'
                                      : 'dummy_cover_${itemTrack.id}_$index',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: _buildCoverImage(
                                        itemTrack.coverArtPath,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Song Info & Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Song Title and Heart Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artistName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.favorite_border_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Progress Slider
                        _buildProgressBar(controller, playback),

                        const SizedBox(height: 16),

                        // Playback Controls
                        _buildControls(controller, playback),

                        const SizedBox(height: 24),

                        // Bottom Actions Row
                        _buildBottomActions(context, playback, controller),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),

              // Draggable Lyrics Sheet removed in favor of Pill button
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String? albumName,
    PlaybackState playback,
    PlaybackController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Column(
            children: [
              const Text(
                'PLAYING FROM ALBUM',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600, // Make it subtle like Spotify
                ),
              ),
              const SizedBox(height: 2),
              Text(
                albumName ?? 'Unknown Album',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () =>
                _showSpotifyMenu(context, playback, controller, _dominantColor),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    PlaybackController controller,
    PlaybackState playback,
  ) {
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.positionNotifier,
      builder: (context, position, child) {
        final duration = playback.duration;
        final positionValue = _tempSliderValue >= 0
            ? _tempSliderValue
            : position.inSeconds.toDouble();
        final durationValue = duration.inSeconds.toDouble();

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 10.0,
                ),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: positionValue.clamp(
                  0.0,
                  durationValue > 0 ? durationValue : 1.0,
                ),
                min: 0.0,
                max: durationValue > 0 ? durationValue : 1.0,
                onChanged: (value) {
                  setState(() => _tempSliderValue = value);
                },
                onChangeEnd: (value) {
                  controller.seekTo(Duration(seconds: value.toInt()));
                  setState(() => _tempSliderValue = -1.0);
                },
              ),
            ),
            // Timers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(Duration(seconds: positionValue.toInt())),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(PlaybackController controller, PlaybackState playback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: playback.playMode == PlayMode.shuffle
                ? const Color(0xFF1DB954)
                : Colors.white.withValues(alpha: 0.6),
            size: 24,
          ),
          onPressed: () {
            if (playback.playMode == PlayMode.shuffle) {
              controller.setPlayMode(PlayMode.sequence);
            } else {
              controller.setPlayMode(PlayMode.shuffle);
            }
          },
        ),
        // Previous
        IconButton(
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () => controller.previous(),
        ),
        // Play/Pause (Large circle)
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              playback.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 32,
            ),
            onPressed: () => controller.togglePlay(),
          ),
        ),
        // Next
        IconButton(
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () => controller.next(),
        ),
        // Repeat
        IconButton(
          icon: Icon(
            playback.playMode == PlayMode.singleLoop
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color:
                (playback.playMode == PlayMode.loop ||
                    playback.playMode == PlayMode.singleLoop)
                ? const Color(0xFF1DB954)
                : Colors.white.withValues(alpha: 0.6),
            size: 24,
          ),
          onPressed: () {
            if (playback.playMode == PlayMode.singleLoop) {
              controller.setPlayMode(PlayMode.sequence);
            } else {
              controller.setPlayMode(
                playback.playMode == PlayMode.loop
                    ? PlayMode.singleLoop
                    : PlayMode.loop,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildBottomActions(
      BuildContext context, PlaybackState playback, PlaybackController controller) {
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Cast Icon
        IconButton(
          icon: const Icon(Icons.cast_rounded, color: Colors.white70, size: 22),
          onPressed: () {},
        ),

        // New LYRICS Capsule
        if (playback.lyrics != null)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SpotifyFullScreenLyrics(
                    playback: playback,
                    controller: controller,
                    bgColor: isAmoled ? Colors.black : _lyricsColor,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isAmoled ? Colors.white24 : _lyricsColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LYRICS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          )
        else
          const Spacer(),

        // Queue Icon
        IconButton(
          icon: const Icon(
            Icons.format_list_bulleted_rounded,
            color: Colors.white70,
            size: 22,
          ),
          onPressed: () => _showSpotifyQueue(
            context,
            isAmoled ? Colors.black : _lyricsColor,
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
          errorBuilder: (context, error, stackTrace) => _fallbackCover(),
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      }
    }
    return _fallbackCover();
  }

  Widget _fallbackCover() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
        size: 80,
      ),
    );
  }
}

// ============================================================================
// SPOTIFY-SPECIFIC SUB-SCREENS & MENUS
// ============================================================================

void _showSpotifyMenu(
  BuildContext context,
  PlaybackState playback,
  PlaybackController controller,
  Color dominant,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: dominant.withValues(alpha: 0.95),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24.0),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Add to Queue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSpotifyQueue(context, dominant);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.lyrics_outlined,
                  color: playback.lyrics != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                ),
                title: Text(
                  'View Lyrics',
                  style: TextStyle(
                    color: playback.lyrics != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: playback.lyrics != null
                    ? () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SpotifyFullScreenLyrics(
                              playback: playback,
                              controller: controller,
                              bgColor: dominant,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded, color: Colors.white),
                title: const Text(
                  'Equalizer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSpotifyEqualizer(context, dominant);
                },
              ),
              ListTile(
                leading: const Icon(Icons.album_outlined, color: Colors.white),
                title: const Text(
                  'View Album',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_pin_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'View Artist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSpotifyQueue(BuildContext context, Color dominant) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => SpotifyQueueScreen(dominant: dominant),
    ),
  );
}

class SpotifyQueueScreen extends ConsumerWidget {
  final Color dominant;
  const SpotifyQueueScreen({super.key, required this.dominant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final currentTrack = playback.currentTrack;

    return Scaffold(
      backgroundColor: Colors.black, // Spotify queue is pure black
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Queue',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentTrack == null
          ? const Center(
              child: Text("No Queue", style: TextStyle(color: Colors.white54)),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Now playing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTrackTile(currentTrack, true, dominant, () {}),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Next In Queue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (playback.playlist.length > playback.currentIndex + 1)
                        TextButton(
                          onPressed: () => controller.clearUpcomingQueue(),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (playback.playlist.isEmpty ||
                      playback.playlist.length <= playback.currentIndex + 1)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'No upcoming tracks',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                ],
              ),
              itemCount: playback.playlist.length > playback.currentIndex + 1
                  ? playback.playlist.length - playback.currentIndex - 1
                  : 0,
              onReorder: (oldIndex, newIndex) {
                final adjustedOld = oldIndex + playback.currentIndex + 1;
                final adjustedNew = newIndex + playback.currentIndex + 1;
                controller.reorderQueue(adjustedOld, adjustedNew);
              },
              itemBuilder: (context, idx) {
                final realIndex = idx + playback.currentIndex + 1;
                final track = playback.playlist[realIndex];

                final tile = Padding(
                  key: ValueKey('sp_q_${track.id}_$realIndex'),
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTrackTile(track, false, dominant, () {
                          controller.skipToIndex(realIndex);
                          Navigator.pop(context);
                        }),
                      ),
                      ReorderableDragStartListener(
                        index: idx,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: Colors.white30,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                return Dismissible(
                  key: ValueKey('sp_d_${track.id}_$realIndex'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    color: Colors.red.withValues(alpha: 0.8),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  onDismissed: (_) => controller.removeFromQueue(realIndex),
                  child: tile,
                );
              },
            ),
    );
  }

  Widget _buildTrackTile(
    PlaybackTrack track,
    bool isCurrent,
    Color dominant,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: SizedBox(width: 50, height: 50, child: _buildCover(track)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
                    fontSize: 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artistName,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(PlaybackTrack track) {
    if (track.coverArtPath != null && track.coverArtPath!.isNotEmpty) {
      if (track.coverArtPath!.startsWith('http')) {
        return Image.network(
          track.coverArtPath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        );
      } else {
        final file = File(track.coverArtPath!);
        if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
      }
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    color: Colors.grey[800],
    child: const Icon(Icons.music_note, color: Colors.white54),
  );
}

void _showSpotifyEqualizer(BuildContext context, Color dominant) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        backgroundColor: dominant.withValues(alpha: 0.5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Equalizer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.tune_rounded, size: 120, color: Colors.white24),
          ),
        ),
      ),
    ),
  );
}

class SpotifyFullScreenLyrics extends StatelessWidget {
  final PlaybackState playback;
  final PlaybackController controller;
  final Color bgColor;
  final bool isAmoled;

  const SpotifyFullScreenLyrics({
    super.key,
    required this.playback,
    required this.controller,
    required this.bgColor,
    this.isAmoled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            const Text(
              'LYRICS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              playback.currentTrack?.name ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          // Swipe DOWN to dismiss
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              children: [
                Expanded(
                  child: KaraokeLyricsView(
                    lyricsData: playback.lyrics,
                    currentPosition: controller.positionNotifier,
                    onTapLine: (duration) {
                      controller.seekTo(duration);
                    },
                  ),
                ),
                // Mini controls at the bottom
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playback.currentTrack?.name ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            playback.currentTrack?.artistName ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            playback.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                          ),
                          onPressed: () => controller.togglePlay(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
