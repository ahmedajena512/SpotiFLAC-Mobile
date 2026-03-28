import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/playback_provider.dart';
import '../../../../providers/player_appearance_provider.dart';
import '../../karaoke_lyrics_view.dart';

class Style3NowPlaying extends ConsumerStatefulWidget {
  const Style3NowPlaying({super.key});

  @override
  ConsumerState<Style3NowPlaying> createState() => _Style3NowPlayingState();
}

class _Style3NowPlayingState extends ConsumerState<Style3NowPlaying> {
  double _tempSliderValue = -1.0;
  bool _showInlineLyrics = false;
  PageController? _pageController;
  /// Tracks the last index we synced to, so we know when to recreate the
  /// controller after returning from lyrics view.
  int _lastSyncedIndex = 0;

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
        _lastSyncedIndex = playback.currentIndex;
        _pageController = PageController(initialPage: playback.currentIndex);
      }
    }
  }

  /// Ensures the PageController is at the correct page index.
  /// Uses jumpToPage to avoid animation conflicts with AnimatedScale/AnimatedSwitcher.
  void _syncPageController(int targetIndex) {
    _lastSyncedIndex = targetIndex;
    if (_pageController != null && _pageController!.hasClients) {
      final currentPage =
          _pageController!.page?.round() ?? _pageController!.initialPage;
      if (targetIndex != currentPage) {
        _pageController!.jumpToPage(targetIndex);
      }
    }
    // If no clients (PageView is hidden e.g. lyrics mode), _lastSyncedIndex
    // will be used to recreate the controller when the PageView returns.
  }

  /// Ensures the PageController starts at the correct page.
  /// Called from the Builder right before returning the PageView.
  void _ensurePageControllerSync(int currentIndex) {
    if (_pageController == null || _lastSyncedIndex != currentIndex) {
      _lastSyncedIndex = currentIndex;
    }

    // Check if we need to recreate the controller (e.g. returning from
    // lyrics view and the track changed while we were away)
    final controllerPage = _pageController?.hasClients == true
        ? _pageController!.page?.round()
        : _pageController?.initialPage;

    if (_pageController == null || controllerPage != currentIndex) {
      _pageController?.dispose();
      _pageController = PageController(initialPage: currentIndex);
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
      _syncPageController(next.currentIndex);
    });

    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);
    final isAmoled = ref.watch(playerAppearanceProvider).useAmoledBackground;
    final track = playback.currentTrack;

    if (track == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_pageController == null && playback.playlist.isNotEmpty) {
      _lastSyncedIndex = playback.currentIndex;
      _pageController = PageController(initialPage: playback.currentIndex);
    }

    return Scaffold(
      backgroundColor: Colors.black, // Darken behind the blur
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe down to dismiss the full screen player
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Extremely blurred background of the album art
            if (!isAmoled)
              Positioned.fill(
                child: _buildCoverImage(track.coverArtPath, fit: BoxFit.cover),
              ),
            // The Glassmorphism Blur Layer
            if (!isAmoled)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.5,
                    ), // Dim the blurred bright colors
                  ),
                ),
              ),

            // Main UI
            SafeArea(
              child: Column(
                children: [
                  // Top Header (Drag handle or Chevron down)
                  _buildHeader(context),

                  // Animated Album Art / Inline Lyrics Header
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          // Fade and subtle scale up
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.95,
                                end: 1.0,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _showInlineLyrics && playback.lyrics != null
                            ? GestureDetector(
                                key: const ValueKey('inline_lyrics'),
                                onTap: () {
                                  // Push fullscreen with purely fade transition
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      transitionDuration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      reverseTransitionDuration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => AppleFullScreenLyrics(
                                            playback: playback,
                                            controller: controller,
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                    ),
                                  );
                                },
                                // Subtle background behind inline lyrics for separation if needed,
                                // but Apple often just puts them on the blurred background
                                child: KaraokeLyricsView(
                                  lyricsData: playback.lyrics,
                                  currentPosition: controller.positionNotifier,
                                  textAlign: TextAlign.start,
                                  activeStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    height: 1.4,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  inactiveStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 34,
                                    height: 1.4,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  onTapLine: (duration) {
                                    controller.seekTo(duration);
                                  },
                                ),
                              )
                            : AnimatedScale(
                                key: const ValueKey('album_art'),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutQuart,
                                // Shrink when paused, full size when playing
                                scale: playback.isPlaying ? 1.0 : 0.85,
                                child: Builder(
                                  builder: (context) {
                                    // Always ensure the PageController is in
                                    // sync with the current track index.
                                    _ensurePageControllerSync(
                                      playback.currentIndex,
                                    );
                                    return PageView.builder(
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
                                    final isActive =
                                        index == playback.currentIndex;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32.0,
                                      ),
                                      child: Center(
                                        child: Hero(
                                          tag: isActive
                                              ? 'album_cover_${itemTrack.id}'
                                              : 'dummy_cover_${itemTrack.id}_$index',
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha:
                                                              playback.isPlaying
                                                              ? 0.6
                                                              : 0.3,
                                                        ),
                                                    blurRadius:
                                                        playback.isPlaying
                                                        ? 40
                                                        : 20,
                                                    spreadRadius:
                                                        playback.isPlaying
                                                        ? 10
                                                        : 5,
                                                    offset: const Offset(0, 20),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
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
                                );
                                  },
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Song Info & Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Song Title and Options
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artistName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Progress Slider
                        _buildProgressBar(controller, playback),

                        const SizedBox(height: 24),

                        // Playback Controls
                        _buildControls(controller, playback),

                        const SizedBox(height: 32),

                        // Bottom Dock (Lyrics, Cast, Queue)
                        _buildBottomDock(context, controller, playback),

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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
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
                trackHeight: 6.0, // Apple style slightly thicker track
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14.0,
                ),
                activeTrackColor: Colors.white.withValues(alpha: 0.8),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.1),
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "-${_formatDuration(playback.duration - (_tempSliderValue >= 0 ? Duration(milliseconds: (_tempSliderValue * durationMillis).toInt()) : position))}",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: () => controller.previous(),
        ),
        GestureDetector(
          onTap: () => controller.togglePlay(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.1,
              ), // Subtle iOS button background
              shape: BoxShape.circle,
            ),
            child: Icon(
              playback.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: () => controller.next(),
        ),
      ],
    );
  }

  Widget _buildBottomDock(
    BuildContext context,
    PlaybackController controller,
    PlaybackState playback,
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
            size: 28,
          ),
          onPressed: playback.lyrics != null
              ? () {
                  setState(() {
                    _showInlineLyrics = !_showInlineLyrics;
                  });
                }
              : null,
        ),

        // Equalizer Button (Replaced Airplay)
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 28,
          ),
          onPressed: () {
            // Push EQ screen
            // We can just push a dummy EQ screen for now or leave as placeholder
          },
        ),

        // Queue Button
        IconButton(
          icon: Icon(
            Icons.queue_music_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 28,
          ),
          onPressed: () {
            // Push the matching Apple Queue screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppleQueueScreen()),
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

/// A very simple replica of the Apple Music Lyrics View
class AppleFullScreenLyrics extends StatelessWidget {
  final PlaybackState playback;
  final PlaybackController controller;

  const AppleFullScreenLyrics({
    super.key,
    required this.playback,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Darken behind the blur
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.pop(context); // Swipe down to close lyrics
          }
        },
        child: Stack(
          children: [
            // The severely blurred background persists
            Positioned.fill(
              child: _buildCoverImage(playback.currentTrack?.coverArtPath),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            // Header and close button
            SafeArea(
              child: Column(
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Lyrics", // Typically Apple says "Lyrics" or nothing
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for title centering
                    ],
                  ),
                  Expanded(
                    child: playback.lyrics != null
                        ? KaraokeLyricsView(
                            lyricsData: playback.lyrics,
                            currentPosition: controller.positionNotifier,
                            textAlign: TextAlign.center,
                            activeStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.4,
                              fontWeight: FontWeight.w900, // Very bold
                            ),
                            inactiveStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 34,
                              height: 1.4,
                              fontWeight: FontWeight.w900,
                            ),
                            onTapLine: (duration) {
                              controller.seekTo(duration);
                            },
                          )
                        : const Center(
                            child: Text(
                              "No lyrics available",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
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

  Widget _buildCoverImage(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        );
      }
      final file = File(path);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    return const SizedBox();
  }
}

/// A very simple replica of the Apple Music Queue screen
class AppleQueueScreen extends ConsumerWidget {
  const AppleQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black, // Dark base for glass
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // Re-use blur background logic to keep context
            Positioned.fill(
              child: _buildCoverImage(playback.currentTrack?.coverArtPath),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                ), // Darker than now playing
              ),
            ),
            SafeArea(
              child: Column(
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Up Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for title centering
                    ],
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      header: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (playback.currentTrack != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: Text(
                                'Now Playing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: _buildCoverImage(
                                    playback.currentTrack!.coverArtPath,
                                  ),
                                ),
                              ),
                              title: Text(
                                playback.currentTrack!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                playback.currentTrack!.artistName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              trailing: Icon(
                                Icons.equalizer_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Up Next',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (playback.playlist.length >
                                    playback.currentIndex + 1)
                                  TextButton(
                                    onPressed: () =>
                                        controller.clearUpcomingQueue(),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (playback.playlist.length <=
                              playback.currentIndex + 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: Text(
                                'No upcoming tracks',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      itemCount:
                          playback.playlist.length > playback.currentIndex + 1
                          ? playback.playlist.length - playback.currentIndex - 1
                          : 0,
                      onReorder: (oldIndex, newIndex) {
                        final adjustedOld =
                            oldIndex + playback.currentIndex + 1;
                        final adjustedNew =
                            newIndex + playback.currentIndex + 1;
                        controller.reorderQueue(adjustedOld, adjustedNew);
                      },
                      itemBuilder: (context, idx) {
                        final realIndex = idx + playback.currentIndex + 1;
                        final track = playback.playlist[realIndex];

                        final tile = ListTile(
                          key: ValueKey('am_q_${track.id}_$realIndex'),
                          tileColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: _buildCoverImage(track.coverArtPath),
                            ),
                          ),
                          title: Text(
                            track.name,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            track.artistName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: idx,
                                child: const Icon(
                                  Icons.drag_handle_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            controller.skipToIndex(realIndex);
                            Navigator.pop(context);
                          },
                        );

                        return Dismissible(
                          key: ValueKey('am_d_${track.id}_$realIndex'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.withValues(alpha: 0.8),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          onDismissed: (_) =>
                              controller.removeFromQueue(realIndex),
                          child: tile,
                        );
                      },
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

  Widget _buildCoverImage(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        );
      }
      final file = File(path);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, color: Colors.white24),
    );
  }
}
