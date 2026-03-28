import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_provider.dart';

/// An inline queue view to be embedded directly into the NowPlayingScreen.
class InPlaceQueueView extends ConsumerWidget {
  const InPlaceQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final currentTrack = playback.currentTrack;

    return Column(
      children: [
        // Queue label & Clear button
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 12),
          child: Row(
            children: [
              const Text(
                'Next In Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (playback.playlist.length > playback.currentIndex + 1)
                TextButton(
                  onPressed: () => controller.clearUpcomingQueue(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(
                    'Clear Queue',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              if (currentTrack?.quality != null &&
                  currentTrack!.quality!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    currentTrack.quality!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Track list
        Expanded(
          child: playback.playlist.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No upcoming tracks',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: playback.playlist.length,
                  onReorder: (oldIndex, newIndex) =>
                      controller.reorderQueue(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final track = playback.playlist[index];
                    final isCurrent = index == playback.currentIndex;

                    return _QueueTrackTile(
                      key: ValueKey('queue_item_${track.id}_$index'),
                      track: track,
                      isCurrent: isCurrent,
                      onTap: () {
                        controller.skipToIndex(index);
                      },
                      onDismiss: isCurrent
                          ? null
                          : () => controller.removeFromQueue(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A single track row in the queue list.
class _QueueTrackTile extends StatelessWidget {
  final PlaybackTrack track;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const _QueueTrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tileContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Album art thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(width: 44, height: 44, child: _buildCover(track)),
          ),
          const SizedBox(width: 14),
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  style: TextStyle(
                    color: isCurrent ? Colors.black87 : Colors.white,
                    fontSize: 16,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  track.artistName,
                  style: TextStyle(
                    color: isCurrent
                        ? Colors.black54
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index:
                0, // Not used strictly when inside ReorderableListView, but requires an integer if directly using ReorderableDragStartListener
            child: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.drag_handle_rounded, color: Colors.white30),
            ),
          ),
        ],
      ),
    );

    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: tileContent,
    );

    // Allow swipe-to-dismiss for non-current tracks
    if (onDismiss != null) {
      return Dismissible(
        key: ValueKey('${track.id}_$hashCode'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        onDismissed: (_) => onDismiss!(),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildCover(PlaybackTrack track) {
    final coverPath = track.coverArtPath;
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
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
        size: 18,
      ),
    );
  }
}
