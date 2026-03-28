import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/playback_provider.dart';

class TidalQueueScreen extends ConsumerWidget {
  final bool isAmoled;
  const TidalQueueScreen({super.key, this.isAmoled = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.watch(playbackProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black, // Pure black AMOLED (Tidal signature)
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
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
                    "Playing Next",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance centering
                ],
              ),
            ),

            // Queue List
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 100,
                ), // Padding for bottom edges
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playback.currentTrack != null) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: Text(
                          'Now Playing',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: _buildTrackImage(
                          playback.currentTrack!.coverArtPath,
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
                        trailing: Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00FFCE,
                            ), // Tidal Green Indicator
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Next Up',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (playback.playlist.length >
                              playback.currentIndex + 1)
                            TextButton(
                              onPressed: () => controller.clearUpcomingQueue(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (playback.playlist.length <= playback.currentIndex + 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Text(
                          'No upcoming tracks',
                          style: TextStyle(color: Colors.white24, fontSize: 14),
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

                  final tile = ListTile(
                    key: ValueKey('tidal_q_${track.id}_$realIndex'),
                    tileColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: _buildTrackImage(track.coverArtPath),
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
                    trailing: ReorderableDragStartListener(
                      index: idx,
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        color: Colors.white30,
                      ),
                    ),
                    onTap: () {
                      controller.skipToIndex(realIndex);
                      Navigator.pop(context);
                    },
                  );

                  return Dismissible(
                    key: ValueKey('tidal_d_${track.id}_$realIndex'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Colors.red[900],
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    onDismissed: (_) => controller.removeFromQueue(realIndex),
                    child: tile,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackImage(String? path) {
    Widget imageWidget;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        imageWidget = Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.music_note, color: Colors.white24),
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          imageWidget = Image.file(file, fit: BoxFit.cover);
        } else {
          imageWidget = Container(
            color: Colors.grey[900],
            child: const Icon(Icons.music_note, color: Colors.white24),
          );
        }
      }
    } else {
      imageWidget = Container(
        color: Colors.grey[900],
        child: const Icon(Icons.music_note, color: Colors.white24),
      );
    }

    // TIDAL signature: sharp corners (0 radius)
    return SizedBox(width: 48, height: 48, child: imageWidget);
  }
}
