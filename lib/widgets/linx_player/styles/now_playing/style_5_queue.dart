import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/playback_provider.dart';

class Style5Queue extends ConsumerWidget {
  final Color bgColor;

  const Style5Queue({super.key, required this.bgColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final currentTrack = playback.currentTrack;
    final queue = playback.playlist;

    // Find index of current track
    int currentIndex = -1;
    if (currentTrack != null) {
      currentIndex = queue.indexWhere((t) => t.id == currentTrack.id);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor, // Dynamic Deezer background color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12.0, bottom: 20.0),
              height: 4.0,
              width: 36.0,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playing Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold, // Deezer bold aesthetic
                  ),
                ),
                TextButton(
                  onPressed: () => controller.clearUpcomingQueue(),
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16.0),

          // Queue List
          Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Text(
                      "Empty Queue",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ReorderableListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) =>
                        controller.reorderQueue(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isPlaying = index == currentIndex;

                      final tile = ListTile(
                        key: ValueKey('dz_queue_${track.id}_$index'),
                        tileColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6.0),
                          child: _buildCover(track.coverArtPath),
                        ),
                        title: Text(
                          track.name,
                          style: TextStyle(
                            color: isPlaying
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight
                                .bold, // Deezer favors bold titles in lists
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artistName,
                          style: TextStyle(
                            color: isPlaying
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPlaying)
                              const Icon(
                                Icons.equalizer_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            if (isPlaying) const SizedBox(width: 16),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          controller.skipToIndex(index);
                          Navigator.pop(context);
                        },
                      );

                      if (isPlaying) return tile;

                      return Dismissible(
                        key: ValueKey('dz_dismiss_${track.id}_$index'),
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
                        onDismissed: (_) => controller.removeFromQueue(index),
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        color: Colors.white.withValues(alpha: 0.1),
        child: const Icon(Icons.music_note_rounded, color: Colors.white24),
      );
    }
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: 48, height: 48, fit: BoxFit.cover);
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.white.withValues(alpha: 0.1),
      child: const Icon(Icons.music_note_rounded, color: Colors.white24),
    );
  }
}
