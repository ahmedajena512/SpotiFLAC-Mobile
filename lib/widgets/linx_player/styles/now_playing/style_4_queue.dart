import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/playback_provider.dart';

class Style4Queue extends ConsumerWidget {
  const Style4Queue({super.key});

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
        color: const Color(0xFF141414), // SC Dark
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12.0, bottom: 20.0),
              height: 4.0,
              width: 40.0,
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
                  'Up Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    controller.clearUpcomingQueue();
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8.0),

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
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) =>
                        controller.reorderQueue(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isPlaying = index == currentIndex;

                      final tile = ListTile(
                        key: ValueKey('sc_queue_${track.id}_$index'),
                        tileColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 4.0,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: _buildCover(track.coverArtPath),
                        ),
                        title: Text(
                          track.name,
                          style: TextStyle(
                            color: isPlaying
                                ? const Color(0xFFFF5500)
                                : Colors.white, // SC Orange for active
                            fontWeight: isPlaying
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artistName,
                          style: TextStyle(
                            color: isPlaying
                                ? const Color(0xFFFF5500).withValues(alpha: 0.8)
                                : Colors.white54,
                            fontSize: 14,
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
                                color: Color(0xFFFF5500),
                                size: 24,
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white54,
                                ),
                                onPressed: () {},
                              ),
                            const SizedBox(width: 8),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white30,
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
                        key: ValueKey('sc_dismiss_${track.id}_$index'),
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
        color: Colors.grey[900],
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
      color: Colors.grey[900],
      child: const Icon(Icons.music_note_rounded, color: Colors.white24),
    );
  }
}
