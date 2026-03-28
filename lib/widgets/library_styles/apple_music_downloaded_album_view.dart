import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';
/// Apple Music style album view for downloaded (local) albums.
class AppleMusicDownloadedAlbumView extends ConsumerStatefulWidget {
  final String albumName;
  final String artistName;
  final String? coverUrl;
  final List<DownloadHistoryItem> tracks;
  final String? embeddedCoverPath;
  final String? commonQuality;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final void Function(String) onToggleSelection;
  final void Function(String) onEnterSelectionMode;
  final void Function(DownloadHistoryItem) onOpenFile;
  final void Function(DownloadHistoryItem) onNavigateToMetadata;

  const AppleMusicDownloadedAlbumView({
    super.key,
    required this.albumName,
    required this.artistName,
    this.coverUrl,
    required this.tracks,
    this.embeddedCoverPath,
    this.commonQuality,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
    required this.onOpenFile,
    required this.onNavigateToMetadata,
  });

  @override
  ConsumerState<AppleMusicDownloadedAlbumView> createState() =>
      _AppleMusicDownloadedAlbumViewState();
}

class _AppleMusicDownloadedAlbumViewState
    extends ConsumerState<AppleMusicDownloadedAlbumView> {
  bool _showTitleInAppBar = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showTitle = _scrollController.offset > 260;
    if (showTitle != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = showTitle);
    }
  }

  void _playAll({bool shuffle = false}) {
    if (widget.tracks.isEmpty) return;
    final items = shuffle ? (List<DownloadHistoryItem>.from(widget.tracks)..shuffle()) : widget.tracks;
    final playbackTracks = items.map((t) => PlaybackTrack(
      id: t.id,
      name: t.trackName,
      artistName: t.artistName,
      albumName: t.albumName,
      coverUrl: t.coverUrl,
      filePath: t.filePath,
      quality: t.quality,
    )).toList();
    ref.read(playbackProvider.notifier).playTrackList(playbackTracks, startIndex: 0);
  }

  ImageProvider? _coverProvider() {
    final cover = widget.coverUrl;
    final embedded = widget.embeddedCoverPath;

    if (cover != null && cover.isNotEmpty) {
      if (cover.startsWith('http://') || cover.startsWith('https://')) {
        return CachedNetworkImageProvider(cover, cacheManager: CoverCacheManager.instance);
      }
      final file = File(cover);
      if (file.existsSync()) return FileImage(file);
    }
    if (embedded != null && embedded.isNotEmpty) {
      final file = File(embedded);
      if (file.existsSync()) return FileImage(file);
    }
    return null;
  }

  Widget _buildCoverWidget({double size = 200}) {
    final provider = _coverProvider();
    if (provider != null) {
      return Image(image: provider, fit: BoxFit.cover, width: size, height: size,
        errorBuilder: (context, error, stackTrace) => _fallbackCover(size));
    }
    return _fallbackCover(size);
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size, height: size,
      color: Colors.grey.shade800,
      child: const Icon(Icons.album, size: 64, color: Colors.grey),
    );
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Colors.redAccent.shade400;
    final coverSize = MediaQuery.sizeOf(context).width * 0.6;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: _showTitleInAppBar ? bgColor.withValues(alpha: 0.85) : Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: accentColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: _showTitleInAppBar
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: FlexibleSpaceBar(
                        title: Text(widget.albumName,
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                        centerTitle: true,
                      ),
                    ),
                  )
                : null,
          ),

          // Header
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + 20),
                Center(
                  child: Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildCoverWidget(size: coverSize),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(widget.albumName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(widget.artistName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: accentColor, fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.tracks.length} tracks${widget.commonQuality != null ? ' • ${widget.commonQuality}' : ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Play / Shuffle buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _playAll(shuffle: false),
                          icon: Icon(Icons.play_arrow, color: accentColor),
                          label: Text('Play', style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _playAll(shuffle: true),
                          icon: Icon(Icons.shuffle, color: accentColor),
                          label: Text('Shuffle', style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Track list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = widget.tracks[index];
                final isSelected = widget.selectedIds.contains(track.id);

                return InkWell(
                  onTap: () {
                    if (widget.isSelectionMode) {
                      widget.onToggleSelection(track.id);
                    } else {
                      widget.onOpenFile(track);
                    }
                  },
                  onLongPress: () {
                    if (!widget.isSelectionMode) {
                      widget.onEnterSelectionMode(track.id);
                    } else {
                      widget.onNavigateToMetadata(track);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        if (widget.isSelectionMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? accentColor : Colors.grey,
                              size: 24,
                            ),
                          )
                        else
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.trackName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textColor, fontSize: 16),
                              ),
                              if (track.artistName != widget.artistName)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    track.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (track.duration != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              _formatDuration(track.duration!),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.more_horiz, size: 20, color: Colors.grey.shade500),
                          onPressed: () {
                            final trackObj = Track(
                              id: track.spotifyId ?? track.isrc ?? track.id,
                              name: track.trackName,
                              artistName: track.artistName,
                              albumName: widget.albumName,
                              coverUrl: widget.coverUrl,
                              isrc: track.isrc,
                              duration: track.duration ?? 0,
                            );
                            TrackCollectionQuickActions.showTrackOptionsSheet(context, ref, trackObj);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: widget.tracks.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
