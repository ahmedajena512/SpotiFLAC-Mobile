import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../../../constants/playback_constants.dart';
import 'style_5_lyrics.dart';
import 'style_5_queue.dart';

/// Style 5: Deezer Full Screen Exact Replica
/// Features: Dark muted background, artwork carousel, white lyrics button on cover,
/// center-aligned huge bold titles, thin slider, and giant play button without border.
class Style5NowPlaying extends ConsumerStatefulWidget {
  const Style5NowPlaying({super.key});

  @override
  ConsumerState<Style5NowPlaying> createState() => _Style5NowPlayingState();
}

class _Style5NowPlayingState extends ConsumerState<Style5NowPlaying> {
  Color _bgColor = const Color(0xFF121216); // Super dark base color
  String? _lastCoverPath;
  double _tempSliderValue = -1.0;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageController == null) {
      final playback = ref.watch(playbackProvider);
      if (playback.playlist.isNotEmpty) {
        _pageController = PageController(
          viewportFraction: 0.95,
          initialPage: playback.currentIndex,
        );
      }
    }
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
          final dominant =
              palette.dominantColor?.color ?? const Color(0xFF191922);
          final hsl = HSLColor.fromColor(dominant);
          // Reverted to standard dark vibrant Deezer background
          _bgColor = hsl
              .withLightness((hsl.lightness * 0.4).clamp(0.1, 0.3))
              .withSaturation((hsl.saturation * 1.2).clamp(0.4, 0.8))
              .toColor();
        });
      }
    } catch (_) {}
  }

  String _formatDurationMinimal(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = d.inMinutes.remainder(60).toString();
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$minutes:$twoDigitSeconds";
    }
    return "$minutes:$twoDigitSeconds";
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
        backgroundColor: Color(0xFF121216),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pageController == null && playback.playlist.isNotEmpty) {
      _pageController = PageController(
        viewportFraction: 0.95,
        initialPage: playback.currentIndex,
      );
    }

    if (track.coverArtPath != _lastCoverPath) {
      Future.microtask(() => _extractColors());
    }

    return Scaffold(
      backgroundColor: isAmoled ? Colors.black : _bgColor,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(context, track),

              const SizedBox(height: 16),

              // Album Art Carousel
              Expanded(
                flex: 5,
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
                    return _buildCarouselItem(context, itemTrack, isActive);
                  },
                ),
              ),

              // Interaction Bar
              const SizedBox(height: 24),
              _buildInteractionBar(),

              // Slider
              const SizedBox(height: 8),
              _buildProgressBar(controller, playback),

              // Track Metadata
              const SizedBox(height: 20),
              _buildMetadata(track),

              // Playback Controls
              const SizedBox(height: 24),
              _buildPlaybackControls(controller, playback),

              const Spacer(),

              // Bottom Actions
              _buildBottomActions(context),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, PlaybackTrack track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (track.quality != null && track.quality!.isNotEmpty)
                        ? track.quality!.toUpperCase()
                        : 'LOSSLESS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(
    BuildContext context,
    PlaybackTrack track,
    bool isActive,
  ) {
    return AnimatedScale(
      scale: isActive ? 1.0 : 0.95, // slight shrinking for inactive items
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Center(
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _buildCoverImage(track.coverArtPath),
              ),
            ),
            if (isActive && ref.watch(playbackProvider).lyrics != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            Style5Lyrics(bgColor: _bgColor),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              const begin = Offset(0.0, 1.0);
                              const end = Offset.zero;
                              var tween = Tween(
                                begin: begin,
                                end: end,
                              ).chain(CurveTween(curve: Curves.easeOutCubic));
                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_none_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Lyrics',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              color: Colors.white,
              size: 26,
            ),
            onPressed: () {},
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white, size: 26),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    PlaybackController controller,
    PlaybackState playback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ValueListenableBuilder<Duration>(
        valueListenable: controller.positionNotifier,
        builder: (context, position, child) {
          final duration = playback.duration;
          final positionValue = _tempSliderValue >= 0
              ? _tempSliderValue
              : position.inSeconds.toDouble();
          final durationValue = duration.inSeconds.toDouble();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDurationMinimal(
                        Duration(seconds: positionValue.toInt()),
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatDurationMinimal(duration),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.0, // Very thin
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16.0,
                  ),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetadata(PlaybackTrack track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 6.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 3.0,
                  vertical: 1.0,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: const Text(
                  'E',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  track.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${track.artistName} - ${track.albumName}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(
    PlaybackController controller,
    PlaybackState playback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: playback.playMode == PlayMode.shuffle
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              size: 26,
            ),
            onPressed: () {
              if (playback.playMode == PlayMode.shuffle) {
                controller.setPlayMode(PlayMode.sequence);
              } else {
                controller.setPlayMode(PlayMode.shuffle);
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.skip_previous_rounded,
              color: Colors.white,
              size: 40,
            ),
            onPressed: () => controller.previous(),
          ),
          // Giant Play Button (No circular container)
          IconButton(
            icon: Icon(
              playback.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 72,
            ),
            padding: EdgeInsets.zero,
            onPressed: () => controller.togglePlay(),
          ),
          IconButton(
            icon: const Icon(
              Icons.skip_next_rounded,
              color: Colors.white,
              size: 40,
            ),
            onPressed: () => controller.next(),
          ),
          IconButton(
            icon: Icon(
              playback.playMode == PlayMode.singleLoop
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color:
                  (playback.playMode == PlayMode.loop ||
                      playback.playMode == PlayMode.singleLoop)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              size: 26,
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
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.speaker_group,
              color: Colors.white.withValues(alpha: 0.7),
              size: 26,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.timer_outlined,
              color: Colors.white.withValues(alpha: 0.7),
              size: 26,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.format_list_bulleted_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 26,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: Style5Queue(bgColor: _bgColor),
                ),
              );
            },
          ),
        ],
      ),
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
