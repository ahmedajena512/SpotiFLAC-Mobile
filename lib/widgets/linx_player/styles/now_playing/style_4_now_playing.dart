import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../../../../constants/playback_constants.dart';
import 'style_4_queue.dart';
import 'style_4_lyrics.dart';
import 'style_4_eq.dart';

class Style4NowPlaying extends ConsumerStatefulWidget {
  const Style4NowPlaying({super.key});

  @override
  ConsumerState<Style4NowPlaying> createState() => _Style4NowPlayingState();
}

class _Style4NowPlayingState extends ConsumerState<Style4NowPlaying> {
  double _tempSliderValue = -1.0;
  Color _dominantColor = Colors.white; // Fallback instead of SC Orange
  String? _lastCoverPath;
  late List<double> _waveformHeights;
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _waveformHeights = [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageController == null) {
      final playback = ref.watch(playbackProvider);
      if (playback.playlist.isNotEmpty) {
        _pageController = PageController(initialPage: playback.currentIndex);
      }
    }
  }

  void _generateWaveform(String trackId) {
    if (_waveformHeights.isNotEmpty) return; // Already generated for this track
    // Pseudo-random deterministic waveform using track ID hash
    final random = Random(trackId.hashCode);
    _waveformHeights = List.generate(80, (index) {
      // Create a nice envelope that is less tall at the edges and chaotic in the middle
      double envelope = 1.0;
      if (index < 10) envelope = index / 10.0;
      if (index > 70) envelope = (80 - index) / 10.0;
      return (random.nextDouble() * 0.8 + 0.2) * envelope;
    });
  }

  Future<void> _extractDominantColor(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    if (imagePath == _lastCoverPath) return;
    _lastCoverPath = imagePath;

    ImageProvider provider;
    if (imagePath.startsWith('http')) {
      provider = NetworkImage(imagePath);
    } else {
      provider = FileImage(File(imagePath));
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(provider);
      if (mounted && palette.dominantColor != null) {
        setState(() {
          // Ensure color is bright enough to see over dark backgrounds
          final hsl = HSLColor.fromColor(palette.dominantColor!.color);
          _dominantColor = hsl
              .withLightness((hsl.lightness < 0.5) ? 0.6 : hsl.lightness)
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
    return "$twoDigitMinutes:$twoDigitSeconds";
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
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;

    if (track == null) return const Scaffold(backgroundColor: Colors.black);

    _generateWaveform(track.id);
    _extractDominantColor(track.coverArtPath);

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
            // 1. Full Screen Album Art (SoundCloud Signature)
            // Always show the fullscreen art, even if AMOLED is requested, 
            // to maintain the SoundCloud identity. We will just darken the gradient.
            Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    if (index != playback.currentIndex) {
                      ref.read(playbackProvider.notifier).skipToIndex(index);
                    }
                  },
                  itemCount: playback.playlist.length,
                  itemBuilder: (context, index) {
                    final itemTrack = playback.playlist[index];
                    final isActive = index == playback.currentIndex;
                    return Hero(
                      tag: isActive
                          ? 'album_cover_${itemTrack.id}'
                          : 'dummy_cover_${itemTrack.id}_$index',
                      child: _buildCoverImage(
                        itemTrack.coverArtPath,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),

            // 2. Heavy Top & Bottom Gradients to ensure text readability
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isAmoled
                          ? [
                              Colors.black.withValues(alpha: 0.7), // Top dark
                              Colors.black.withValues(alpha: 0.2), // Middle clear (a bit darker than normal)
                              Colors.black.withValues(alpha: 0.7), // Lower middle (darker)
                              Colors.black, // Pure black at bottom for AMOLED
                              Colors.black,
                            ]
                          : [
                              Colors.black.withValues(alpha: 0.7), // Top dark
                              Colors.black.withValues(alpha: 0.1), // Middle clear
                              Colors.black.withValues(alpha: 0.3), // Lower middle
                              Colors.black.withValues(alpha: 0.85), // Bottom very dark
                              Colors.black, // Bottom solid
                            ],
                      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Main UI Content
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Action Bar + Track Info
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.artistName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // "HQ Audio" badge replacing SC's "Behind this track"
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.graphic_eq_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      track.quality ?? 'HD Audio',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top Right Icons
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // The Waveform Section
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: _buildWaveform(playback),
                  ),

                  const SizedBox(height: 24),

                  // The Comment Bar Replacement (Controls Pill)
                  _buildControlsPill(playback),

                  const SizedBox(height: 16),

                  // Bottom Icons Row (Like, Lyrics, Share, More)
                  _buildBottomIcons(context, playback),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform(PlaybackState playback) {
    final controller = ref.read(playbackProvider.notifier);

    return ValueListenableBuilder<Duration>(
      valueListenable: controller.positionNotifier,
      builder: (context, position, _) {
        final durationMillis = playback.duration.inMilliseconds.toDouble();
        final positionMillis = position.inMilliseconds.toDouble();

        double sliderValue;
        if (_tempSliderValue >= 0) {
          sliderValue = _tempSliderValue;
        } else {
          sliderValue = durationMillis > 0
              ? (positionMillis / durationMillis).clamp(0.0, 1.0)
              : 0.0;
        }

        final currentPosOverride = _tempSliderValue >= 0
            ? Duration(
                milliseconds: (_tempSliderValue * durationMillis).toInt(),
              )
            : position;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final dx = details.localPosition.dx;
            final width = box.size.width;
            setState(() {
              _tempSliderValue = (dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) {
            final targetMillis = _tempSliderValue * durationMillis;
            controller.seekTo(Duration(milliseconds: targetMillis.toInt()));
            setState(() {
              _tempSliderValue = -1.0;
            });
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final dx = details.localPosition.dx;
            final width = box.size.width;
            final val = (dx / width).clamp(0.0, 1.0);
            controller.seekTo(
              Duration(milliseconds: (val * durationMillis).toInt()),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Visual Waveform using CustomPaint
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    heights: _waveformHeights,
                    progress: sliderValue,
                    activeColor: _dominantColor,
                    inactiveColor: Colors.white.withValues(
                      alpha: 0.6,
                    ), // Standard grey/white
                  ),
                ),
              ),

              // The floating Black Time Pill exactly on the line
              Positioned(
                left: _getFloatingPillPosition(
                  sliderValue,
                  MediaQuery.of(context).size.width,
                ),
                bottom: 2, // Near axis
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(currentPosOverride),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          "|",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(playback.duration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Calculate left offset for the pill so it sticks to the progress line but doesn't overflow screen
  double _getFloatingPillPosition(double progress, double screenWidth) {
    const double pillEstimatedWidth = 60.0;
    double exactPos = progress * screenWidth;

    // Shift slightly to the right of the line so it doesn't cover the line exactly, just adjacent
    double shifted = exactPos + 2;

    if (shifted + pillEstimatedWidth > screenWidth - 10) {
      shifted = screenWidth - pillEstimatedWidth - 10;
    }
    return shifted.clamp(0.0, screenWidth - pillEstimatedWidth);
  }

  Widget _buildControlsPill(PlaybackState playback) {
    final controller = ref.read(playbackProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 56, // Size of the SC comment bar
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shuffle
              IconButton(
                icon: const Icon(Icons.shuffle_rounded),
                color: playback.playMode == PlayMode.shuffle
                    ? _dominantColor
                    : Colors.white70,
                iconSize: 22,
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
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white,
                iconSize: 32,
                onPressed: () => controller.previous(),
              ),

              // Play/Pause (No background here so it fits the sleek pill, SC comment field style)
              IconButton(
                icon: Icon(
                  playback.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                color: Colors.white,
                iconSize: 36,
                onPressed: () => controller.togglePlay(),
              ),

              // Next
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white,
                iconSize: 32,
                onPressed: () => controller.next(),
              ),

              // Repeat
              IconButton(
                icon: Icon(
                  playback.playMode == PlayMode.singleLoop
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
                color:
                    (playback.playMode == PlayMode.loop ||
                        playback.playMode == PlayMode.singleLoop)
                    ? _dominantColor
                    : Colors.white70,
                iconSize: 22,
                onPressed: () {
                  if (playback.playMode == PlayMode.sequence ||
                      playback.playMode == PlayMode.shuffle) {
                    controller.setPlayMode(PlayMode.loop);
                  } else if (playback.playMode == PlayMode.loop) {
                    controller.setPlayMode(PlayMode.singleLoop);
                  } else {
                    controller.setPlayMode(PlayMode.sequence);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomIcons(BuildContext context, PlaybackState playback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Queue
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
            iconSize: 28,
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => FractionallySizedBox(
                  heightFactor: 0.7,
                  child: const Style4Queue(),
                ),
              );
            },
          ),

          // Lyrics Button (no text)
          IconButton(
            icon: const Icon(Icons.lyrics_outlined, color: Colors.white),
            iconSize: 28,
            onPressed: playback.lyrics != null
                ? () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const Style4Lyrics()),
                    );
                  }
                : null,
          ),

          // EQ
          IconButton(
            icon: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
            iconSize: 28,
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const Style4EQ(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(String? path, {BoxFit fit = BoxFit.cover}) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(file, fit: fit);
        }
      }
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 64),
      ),
    );
  }
}

/// Custom pseudo-random waveform layout exactly resembling SoundCloud's dense lines
class _WaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.heights,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.square;

    final int count = heights.length;
    // We space the bars evenly across the width
    final double spacing = size.width / count;
    final double barWidth = spacing * 0.75; // small gap between bars

    // axis at roughly 70% down from the top
    final double axisY = size.height * 0.70;

    for (int i = 0; i < count; i++) {
      final x = i * spacing;
      final isPassed = (i / count) <= progress;

      paint.color = isPassed ? activeColor : inactiveColor;

      // Base height mapping
      final h = heights[i] * axisY;

      // Draw upper portion
      canvas.drawRect(Rect.fromLTWH(x, axisY - h, barWidth, h), paint);

      // Draw reflected (mirrored) bottom portion, shorter and dimmer
      final mirrorHeight = h * 0.4;
      paint.color = (isPassed ? activeColor : inactiveColor).withValues(
        alpha: 0.35,
      ); // Reflect opacity
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          axisY + 1.5,
          barWidth,
          mirrorHeight,
        ), // small 1.5px gap for the axis line
        paint,
      );

      // Draw the exact progress line indicator (the divider between active/inactive)
      if (isPassed && ((i + 1) / count) > progress) {
        paint.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(
            x + barWidth,
            axisY - h - 5,
            1.5,
            h + mirrorHeight + 10,
          ),
          paint,
        );
      }
    }

    // Draw the tiny 1px axis line across the screen that SoundCloud has
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, axisY + 0.75),
      Offset(size.width, axisY + 0.75),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.heights != heights;
  }
}
