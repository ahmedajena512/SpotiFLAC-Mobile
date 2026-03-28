import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:spotiflac_android/constants/playback_constants.dart';
import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import 'style_6_lyrics.dart';
import 'style_6_queue.dart';

/// Style 6: Tidal Mobile App Replica (Audiophile Minimalist)
/// Features a pure black (AMOLED) background, sharp square album art
/// (0px radius), HiFi/FLAC quality badges, and a minimalist control layout.
class Style6NowPlaying extends ConsumerStatefulWidget {
  const Style6NowPlaying({super.key});

  @override
  ConsumerState<Style6NowPlaying> createState() => _Style6NowPlayingState();
}

class _Style6NowPlayingState extends ConsumerState<Style6NowPlaying> {
  double _tempSliderValue = -1.0;
  PageController? _pageController;
  PaletteGenerator? _palette;
  String? _lastCoverPath;

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
        _pageController = PageController(initialPage: playback.currentIndex);
      }
    }
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
    final controller = ref.watch(playbackProvider.notifier);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;

    if (track == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FFCE)),
        ),
      );
    }

    if (_pageController == null && playback.playlist.isNotEmpty) {
      _pageController = PageController(initialPage: playback.currentIndex);
    }

    if (track.coverArtPath != _lastCoverPath) {
      Future.microtask(() => _updatePalette());
    }

    Color gradientTop = const Color(0xFF1A1A1A);
    Color gradientBottom = Colors.black;
    if (_palette != null) {
      final dominant =
          _palette!.darkVibrantColor?.color ?? _palette!.dominantColor?.color;
      if (dominant != null) {
        gradientTop = dominant;
        // The bottom can be a very dark version of the dominant color, or just gradientTop with less opacity
        final hsl = HSLColor.fromColor(dominant);
        gradientBottom = hsl
            .withLightness((hsl.lightness * 0.1).clamp(0.01, 0.1))
            .toColor();
      }
    }

    return Scaffold(
      backgroundColor: Colors.black, // Fallback
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe down to dismiss
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Dynamic Album Color Background (User requested colors by default)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  color: isAmoled ? Colors.black : null,
                  gradient: isAmoled
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [gradientTop, gradientBottom],
                        ),
                ),
              ),
            ),

            // Main UI
            SafeArea(
              child: Column(
                children: [
                  // Top Header
                  _buildTopNavigationBar(context, track.albumName),

                  const SizedBox(height: 16),

                  // Album Art Carousel (Sharp Edges - No Radius)
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
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
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Center(
                            child: Hero(
                              tag: isActive
                                  ? 'album_cover_${itemTrack.id}'
                                  : 'dummy_cover_${itemTrack.id}_$index',
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  // TIDAL: Slightly rounded edges based on user feedback
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: playback.isPlaying ? 0.5 : 0.2,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildCoverImage(
                                      itemTrack.coverArtPath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Song Info & Controls Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),

                        // Title and Artist
                        _buildTrackInfo(track),

                        const SizedBox(height: 32),

                        // Progress Slider
                        _buildProgressBar(controller, playback),

                        const SizedBox(height: 16),

                        // Quality Badge (Centered below progress bar)
                        Center(child: _buildQualityBadge(track)),

                        const SizedBox(height: 16),

                        // Playback Controls
                        _buildControls(controller, playback),

                        const SizedBox(height: 32),

                        // Bottom Navigation / Actions
                        _buildBottomActions(context, playback, isAmoled),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavigationBar(BuildContext context, String albumName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          iconSize: 32,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Album Name
        Expanded(
          child: Text(
            albumName.isNotEmpty ? albumName : 'Now Playing',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.white),
          onPressed: () {
            // More options
          },
        ),
      ],
    );
  }

  Widget _buildTrackInfo(PlaybackTrack track) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontSize: 24, // Large, confident typography
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artistName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
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
            size: 28,
          ),
          onPressed: () {
            // Favorite logic
          },
        ),
      ],
    );
  }

  Widget _buildQualityBadge(PlaybackTrack track) {
    String badgeText = 'HIGH';
    final qualityStr = track.quality;
    final filePath = track.filePath;

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

    final isMax = badgeText == 'MAX' || badgeText.contains('FLAC');

    // MAX: Gold text on translucent gold
    // HIGH: Light grey text on dark grey (like the image)
    final accentColor = isMax ? const Color(0xFFFFD700) : Colors.white70;
    final bgColor = isMax
        ? const Color(0xFFFFD700).withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6), // Slightly rounded pill
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: accentColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
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

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0, // Extra thin
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14.0,
                ),
                activeTrackColor: Colors.white, // User requested white
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: sliderValue,
                onChanged: (val) {
                  setState(() {
                    _tempSliderValue = val;
                  });
                },
                onChangeEnd: (val) {
                  final targetMillis = val * durationMillis;
                  controller.seekTo(
                    Duration(milliseconds: targetMillis.toInt()),
                  );
                  setState(() {
                    _tempSliderValue = -1.0;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(
                      _tempSliderValue >= 0
                          ? Duration(
                              milliseconds: (_tempSliderValue * durationMillis)
                                  .toInt(),
                            )
                          : position,
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatDuration(playback.duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
        IconButton(
          icon: Icon(
            playback.playMode == PlayMode.shuffle
                ? Icons.shuffle_on_rounded
                : Icons.shuffle_rounded,
            color: playback.playMode == PlayMode.shuffle
                ? Colors.white
                : Colors.white54,
          ),
          onPressed: () {
            controller.setPlayMode(
              playback.playMode == PlayMode.shuffle
                  ? PlayMode.sequence
                  : PlayMode.shuffle,
            );
          },
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: () => controller.previous(),
        ),
        // Play Button: Big, white, no surrounding circle (pure icon)
        GestureDetector(
          onTap: () => controller.togglePlay(),
          child: Icon(
            playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 64, // Massive icon
          ),
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: () => controller.next(),
        ),
        IconButton(
          icon: Icon(
            playback.playMode == PlayMode.loop ||
                    playback.playMode == PlayMode.singleLoop
                ? (playback.playMode == PlayMode.singleLoop
                      ? Icons.repeat_one_on_rounded
                      : Icons.repeat_on_rounded)
                : Icons.repeat_rounded,
            color:
                (playback.playMode == PlayMode.loop ||
                    playback.playMode == PlayMode.singleLoop)
                ? Colors.white
                : Colors.white54,
          ),
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
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    PlaybackState playback,
    bool isAmoled,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Lyrics Button
        IconButton(
          icon: Icon(
            Icons.format_quote_rounded,
            color: playback.lyrics != null
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            size: 26,
          ),
          onPressed: playback.lyrics != null
              ? () {
                  Navigator.push<void>(
                    context,
                    PageRouteBuilder<void>(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TidalLyricsScreen(isAmoled: isAmoled),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0, 1),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                              child: child,
                            );
                          },
                    ),
                  );
                }
              : null,
        ),

        // Output device identifier (e.g. built-in speaker)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speaker_group_rounded,
              color: const Color(0xFF00FFCE).withValues(alpha: 0.8),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              "TIDAL Connect",
              style: TextStyle(
                color: const Color(0xFF00FFCE).withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        // Queue Button
        IconButton(
          icon: Icon(
            Icons.queue_music_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 26,
          ),
          onPressed: () {
            // Push Tidal Queue Screen
            Navigator.push<void>(
              context,
              PageRouteBuilder<void>(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    TidalQueueScreen(isAmoled: isAmoled),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      );
                    },
              ),
            );
          },
        ),
      ],
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
        child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 64),
      ),
    );
  }
}
