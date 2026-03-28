import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../providers/playback_provider.dart';
import '../../animated_album_cover.dart';
import '../../karaoke_lyrics_view.dart';
import '../../queue_sheet.dart';
import '../../liquid_gradient_painter.dart';
import '../../music_control_panel.dart';
import '../../../../providers/player_appearance_provider.dart';

/// Full-screen Now Playing screen with liquid gradient background,
/// animated album cover, lyrics view, and playback controls.
class Style1NowPlaying extends ConsumerStatefulWidget {
  const Style1NowPlaying({super.key});

  @override
  ConsumerState<Style1NowPlaying> createState() => _Style1NowPlayingState();
}

class _Style1NowPlayingState extends ConsumerState<Style1NowPlaying>
    with SingleTickerProviderStateMixin {
  late AnimationController _lyricsToggleController;
  double _tempSliderValue = -1;
  bool _showLyrics = false;
  bool _showQueue = false;

  List<Color>? _extractedColors;
  String? _lastExtractedCoverPath;
  PageController? _pageController;
  int _lastSyncedIndex = 0;

  @override
  void initState() {
    super.initState();
    _lyricsToggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _lyricsToggleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageController == null) {
      final playback = ref.watch(playbackProvider);
      if (playback.playlist.isNotEmpty) {
        _lastSyncedIndex = playback.currentIndex;
        _pageController = PageController(initialPage: playback.currentIndex);
      }
    }
  }

  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
      if (_showQueue && _showLyrics) {
        _showQueue = false;
      }
    });

    if (_showLyrics) {
      _lyricsToggleController.forward();
    } else {
      _lyricsToggleController.reverse();
    }
  }

  void _toggleQueue() {
    setState(() {
      _showQueue = !_showQueue;
      if (_showLyrics && _showQueue) {
        _showLyrics = false;
        _lyricsToggleController.reverse();
      }
    });
  }

  Future<void> _extractColors(String coverPath) async {
    if (_lastExtractedCoverPath == coverPath) return;

    ImageProvider? imageProvider;
    if (coverPath.startsWith('http')) {
      imageProvider = NetworkImage(coverPath);
    } else if (File(coverPath).existsSync()) {
      imageProvider = FileImage(File(coverPath));
    }

    if (imageProvider != null) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(imageProvider);
        if (!mounted) return;
        final defaultColors = _fallbackColors(context);
        final colors = <Color>[];

        if (palette.dominantColor != null) {
          colors.add(palette.dominantColor!.color);
        }
        if (palette.vibrantColor != null) {
          colors.add(palette.vibrantColor!.color);
        }
        if (palette.mutedColor != null) {
          colors.add(palette.mutedColor!.color);
        }
        if (palette.darkVibrantColor != null) {
          colors.add(palette.darkVibrantColor!.color);
        }

        if (colors.isEmpty) {
          colors.addAll(defaultColors);
        } else if (colors.length < 4) {
          colors.add(colors.first.withValues(alpha: 0.8));
          if (colors.length < 4) {
            colors.add(colors.last.withValues(alpha: 0.6));
          }
          if (colors.length < 4) {
            colors.add(colors.first.withValues(alpha: 0.4));
          }
        }

        if (mounted) {
          setState(() {
            _extractedColors = colors;
            _lastExtractedCoverPath = coverPath;
          });
        }
      } catch (_) {}
    }
  }

  List<Color> _fallbackColors(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      colorScheme.primaryContainer,
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
    ];
  }

  /// Ensures the PageController is at the correct page index.
  /// Uses jumpToPage to avoid animation conflicts.
  void _syncPageController(int targetIndex) {
    _lastSyncedIndex = targetIndex;
    if (_pageController != null && _pageController!.hasClients) {
      final currentPage =
          _pageController!.page?.round() ?? _pageController!.initialPage;
      if (targetIndex != currentPage) {
        _pageController!.jumpToPage(targetIndex);
      }
    }
  }

  /// Ensures the PageController starts at the correct page.
  /// Called from the Builder right before returning the PageView.
  void _ensurePageControllerSync(int currentIndex) {
    if (_pageController == null || _lastSyncedIndex != currentIndex) {
      _lastSyncedIndex = currentIndex;
    }
    final controllerPage = _pageController?.hasClients == true
        ? _pageController!.page?.round()
        : _pageController?.initialPage;
    if (_pageController == null || controllerPage != currentIndex) {
      _pageController?.dispose();
      _pageController = PageController(initialPage: currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackState>(playbackProvider, (previous, next) {
      _syncPageController(next.currentIndex);
    });

    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;
    final colorScheme = Theme.of(context).colorScheme;

    if (track == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Text(
            'No track playing',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    if (track.coverArtPath != null) {
      _extractColors(track.coverArtPath!);
    }

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
            // Liquid gradient background using theme colors
            Positioned.fill(
              child: isAmoled
                  ? Container(color: Colors.black)
                  : LiquidGeneratorPage(
                      liquidColors:
                          _extractedColors ?? _fallbackColors(context),
                      isPlaying: playback.isPlaying,
                    ),
            ),

            // Dark overlay for readability
            if (!isAmoled)
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Album cover / lyrics area / Queue area
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showQueue
                          ? const InPlaceQueueView()
                          : AnimatedBuilder(
                              animation: _lyricsToggleController,
                              builder: (context, child) {
                                final progress = _lyricsToggleController.value;
                                return Stack(
                                  children: [
                                    // Album cover
                                    if (progress < 1.0)
                                      Opacity(
                                        opacity: 1.0 - progress,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 0,
                                            ),
                                            child: Builder(
                                              builder: (context) {
                                                // Always ensure the
                                                // PageController is in sync
                                                // with the current track.
                                                _ensurePageControllerSync(
                                                  playback.currentIndex,
                                                );
                                                return PageView.builder(
                                              controller: _pageController,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              onPageChanged: (index) {
                                                if (index !=
                                                    playback.currentIndex) {
                                                  ref
                                                      .read(
                                                        playbackProvider
                                                            .notifier,
                                                      )
                                                      .skipToIndex(index);
                                                }
                                              },
                                              itemCount:
                                                  playback.playlist.length,
                                              itemBuilder: (context, index) {
                                                final itemTrack =
                                                    playback.playlist[index];
                                                final isActive =
                                                    index ==
                                                    playback.currentIndex;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                      ),
                                                  child: Center(
                                                    child: Hero(
                                                      tag: isActive
                                                          ? 'album_cover_${itemTrack.id}'
                                                          : 'dummy_cover_${itemTrack.id}_$index',
                                                      child: AnimatedAlbumCover(
                                                        albumArtPath: itemTrack
                                                            .coverArtPath,
                                                        title: itemTrack.name,
                                                        artist: itemTrack
                                                            .artistName,
                                                        isPlaying: isActive
                                                            ? playback.isPlaying
                                                            : false,
                                                        animationProgress: 0,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Lyrics view
                                    if (progress > 0.0 &&
                                        playback.lyrics != null)
                                      Opacity(
                                        opacity: progress,
                                        child: KaraokeLyricsView(
                                          lyricsData: playback.lyrics,
                                          currentPosition:
                                              controller.positionNotifier,
                                          onTapLine: (duration) {
                                            controller.seekTo(duration);
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),

                  // Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SongInfoPanel(
                      tempSliderValue: _tempSliderValue,
                      animationProgress: _showLyrics ? 1.0 : 0.0,
                      onSliderChanged: (value) {
                        setState(() => _tempSliderValue = value);
                      },
                      onSliderChangeEnd: (value) {
                        controller.seekTo(Duration(seconds: value.toInt()));
                        setState(() => _tempSliderValue = -1);
                      },
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: MusicControlButtons(),
                  ),

                  const SizedBox(height: 16),

                  // Bottom bar
                  _buildBottomBar(context, track),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, PlaybackTrack track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lyrics button
          IconButton(
            icon: Icon(
              Icons.format_quote_rounded,
              color: ref.watch(playbackProvider).lyrics != null
                  ? (_showLyrics ? Colors.white : Colors.white60)
                  : Colors.white.withValues(alpha: 0.2),
              size: 26,
            ),
            onPressed: ref.watch(playbackProvider).lyrics != null
                ? _toggleLyrics
                : null,
          ),

          // Equalizer/Audio Quality placeholder
          IconButton(
            icon: const Icon(
              Icons.equalizer_rounded,
              color: Colors.white60,
              size: 26,
            ),
            onPressed: () {},
          ),

          // Cast / AirPlay placeholder
          IconButton(
            icon: const Icon(
              Icons.cast_rounded,
              color: Colors.white60,
              size: 26,
            ),
            onPressed: () {},
          ),

          // Queue button
          Container(
            decoration: BoxDecoration(
              color: _showQueue
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.format_list_bulleted_rounded,
                color: _showQueue ? Colors.white : Colors.white60,
                size: 26,
              ),
              onPressed: _toggleQueue,
            ),
          ),

          // Close button
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white60,
              size: 26,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
