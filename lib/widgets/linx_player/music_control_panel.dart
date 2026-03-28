import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/playback_constants.dart';
import '../../providers/playback_provider.dart';
import 'slider_custom.dart';

/// Song info panel with title, artist, progress slider, and time display.
class SongInfoPanel extends ConsumerWidget {
  final double tempSliderValue;
  final Function(double) onSliderChanged;
  final Function(double) onSliderChangeEnd;
  final double animationProgress;

  const SongInfoPanel({
    super.key,
    required this.tempSliderValue,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    this.animationProgress = 0.0,
  });

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final titleOpacity = (1.0 - animationProgress).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: SizedBox(
            height: 80,
            child: Opacity(
              opacity: titleOpacity,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playback.currentTrack?.name ?? "Unknown Song",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      playback.currentTrack?.artistName ?? "Unknown Artist",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<Duration>(
          valueListenable: ref.read(playbackProvider.notifier).positionNotifier,
          builder: (context, position, child) {
            return AnimatedTrackHeightSlider(
              value: tempSliderValue >= 0
                  ? tempSliderValue
                  : position.inSeconds.toDouble(),
              max: playback.duration.inSeconds.toDouble(),
              min: 0,
              activeColor: Colors.white,
              inactiveColor: Colors.white30,
              onChanged: onSliderChanged,
              onChangeEnd: onSliderChangeEnd,
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: ref
                  .read(playbackProvider.notifier)
                  .positionNotifier,
              builder: (context, position, child) {
                return SizedBox(
                  width: 60,
                  child: Text(
                    formatDuration(position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              },
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    playback.currentTrack?.quality ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                formatDuration(playback.duration),
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Playback control buttons: shuffle, prev, play/pause, next, repeat, volume.
class MusicControlButtons extends ConsumerWidget {
  final bool compactLayout;

  const MusicControlButtons({super.key, this.compactLayout = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showPlayModeButtons = constraints.maxWidth >= 320;

        return Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                if (showPlayModeButtons)
                  IconButton(
                    iconSize: 18,
                    padding: compactLayout ? const EdgeInsets.all(4) : null,
                    constraints: compactLayout ? const BoxConstraints() : null,
                    color: Colors.white70,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playback.playMode == PlayMode.shuffle
                          ? Colors.white
                          : null,
                    ),
                    onPressed: () {
                      if (playback.playMode == PlayMode.shuffle) {
                        controller.setPlayMode(PlayMode.sequence);
                        return;
                      }
                      controller.setPlayMode(PlayMode.shuffle);
                    },
                  ),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        padding: compactLayout ? const EdgeInsets.all(4) : null,
                        constraints: compactLayout
                            ? const BoxConstraints()
                            : null,
                        color: playback.hasPrevious
                            ? Colors.white
                            : Colors.white70,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: () => controller.previous(),
                      ),
                      SizedBox(width: compactLayout ? 8 : 16),
                      IconButton(
                        iconSize: 52,
                        padding: compactLayout ? const EdgeInsets.all(4) : null,
                        constraints: compactLayout
                            ? const BoxConstraints()
                            : null,
                        color: Colors.white,
                        icon: Icon(
                          playback.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                        ),
                        onPressed: () => controller.togglePlay(),
                      ),
                      SizedBox(width: compactLayout ? 8 : 16),
                      IconButton(
                        iconSize: 36,
                        padding: compactLayout ? const EdgeInsets.all(4) : null,
                        constraints: compactLayout
                            ? const BoxConstraints()
                            : null,
                        color: playback.hasNext ? Colors.white : Colors.white70,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: () => controller.next(),
                      ),
                    ],
                  ),
                ),
                if (showPlayModeButtons)
                  IconButton(
                    iconSize: 18,
                    padding: compactLayout ? const EdgeInsets.all(4) : null,
                    constraints: compactLayout ? const BoxConstraints() : null,
                    color: Colors.white70,
                    icon: Icon(
                      playback.playMode == PlayMode.singleLoop
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color:
                          playback.playMode == PlayMode.loop ||
                              playback.playMode == PlayMode.singleLoop
                          ? Colors.white
                          : null,
                    ),
                    onPressed: () {
                      if (playback.playMode == PlayMode.singleLoop) {
                        controller.setPlayMode(PlayMode.sequence);
                        return;
                      }
                      controller.setPlayMode(
                        playback.playMode == PlayMode.loop
                            ? PlayMode.singleLoop
                            : PlayMode.loop,
                      );
                    },
                  ),
              ],
            ),
            if (!compactLayout) const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}
