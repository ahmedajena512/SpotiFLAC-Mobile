import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/utils/color_extractor.dart';

/// Spotify-style album view for downloaded (local) albums.
/// Receives data as [DownloadHistoryItem] from [DownloadedAlbumScreen].
class SpotifyDownloadedAlbumView extends ConsumerStatefulWidget {
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

  const SpotifyDownloadedAlbumView({
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
  ConsumerState<SpotifyDownloadedAlbumView> createState() =>
      _SpotifyDownloadedAlbumViewState();
}

class _SpotifyDownloadedAlbumViewState
    extends ConsumerState<SpotifyDownloadedAlbumView> {
  Color? _dominantColor;
  bool _showTitleInAppBar = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _extractColor();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SpotifyDownloadedAlbumView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.embeddedCoverPath != widget.embeddedCoverPath) {
      _extractColor();
    }
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 240;
    if (shouldShow != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShow);
    }
  }

  Future<void> _extractColor() async {
    // Try embedded cover first, then network URL
    final imageSource = widget.embeddedCoverPath ?? widget.coverUrl;
    if (imageSource == null) return;
    final colors = await ColorExtractor.getColors(imageSource);
    if (mounted && colors.isNotEmpty) {
      setState(() {
        _dominantColor = colors.first;
      });
    }
  }

  Widget _buildCoverImage({double? width, double? height, BoxFit? fit}) {
    if (widget.embeddedCoverPath != null) {
      return Image.file(
        File(widget.embeddedCoverPath!),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, _, _) => _coverFallback(width, height),
      );
    } else if (widget.coverUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.coverUrl!,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        cacheManager: CoverCacheManager.instance,
        errorWidget: (_, _, _) => _coverFallback(width, height),
      );
    }
    return _coverFallback(width, height);
  }

  Widget _coverFallback(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.album, size: 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = _dominantColor ?? colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Gradient Background from dominant color
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withValues(alpha: isDark ? 0.6 : 1.0),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(bgColor, isDark),
              _buildActionRow(isDark),
              if (widget.tracks.isNotEmpty) _buildTrackList(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color bgColor, bool isDark) {
    final releaseDate = widget.tracks.isNotEmpty
        ? widget.tracks.first.releaseDate
        : null;
    final releaseYear = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.split('-').first
        : null;

    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: _showTitleInAppBar ? bgColor : Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        opacity: _showTitleInAppBar ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          widget.albumName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album artwork centered
            Center(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _buildCoverImage(width: 220, height: 220),
                    ),
                  ),
                ),
              ),
            ),
            // Album name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                widget.albumName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            // Artist name with avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colorScheme.surfaceContainer,
                    child: const Icon(Icons.person, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.artistName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Metadata row: quality + year
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                [
                  if (widget.commonQuality != null) widget.commonQuality!,
                  if (releaseYear != null) releaseYear,
                  '${widget.tracks.length} ${widget.tracks.length == 1 ? "song" : "songs"}',
                ].join(' • '),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  Widget _buildActionRow(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // More options
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              onPressed: () => _showAlbumOptionsSheet(context),
            ),
            const Spacer(),
            // Shuffle button
            IconButton(
              icon: const Icon(Icons.shuffle, size: 24),
              color: colorScheme.onSurfaceVariant,
              onPressed: () {
                if (widget.tracks.isNotEmpty) {
                  final playbackTracks = widget.tracks
                      .map(
                        (t) => PlaybackTrack(
                          id: t.id,
                          name: t.trackName,
                          artistName: t.artistName,
                          albumName: t.albumName,
                          coverUrl: t.coverUrl,
                          filePath: t.filePath,
                          quality: t.quality,
                        ),
                      )
                      .toList()
                    ..shuffle();
                  ref
                      .read(playbackProvider.notifier)
                      .playTrackList(playbackTracks, startIndex: 0);
                }
              },
            ),
            const SizedBox(width: 8),
            // Green Play button (Spotify's signature)
            GestureDetector(
              onTap: () {
                if (widget.tracks.isNotEmpty) {
                  final playbackTracks = widget.tracks
                      .map(
                        (t) => PlaybackTrack(
                          id: t.id,
                          name: t.trackName,
                          artistName: t.artistName,
                          albumName: t.albumName,
                          coverUrl: t.coverUrl,
                          filePath: t.filePath,
                          quality: t.quality,
                        ),
                      )
                      .toList();
                  ref
                      .read(playbackProvider.notifier)
                      .playTrackList(playbackTracks, startIndex: 0);
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954), // Spotify Green
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = widget.tracks[index];
          final isSelected = widget.selectedIds.contains(track.id);

          return InkWell(
            onTap: widget.isSelectionMode
                ? () => widget.onToggleSelection(track.id)
                : () => widget.onOpenFile(track),
            onLongPress: widget.isSelectionMode
                ? null
                : () => widget.onEnterSelectionMode(track.id),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  // Selection checkbox or track number
                  if (widget.isSelectionMode) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1DB954)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1DB954)
                              : Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 12),
                  ],
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${track.trackNumber ?? index + 1}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title and Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play button (only when not in selection mode)
                  if (!widget.isSelectionMode)
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => widget.onNavigateToMetadata(track),
                    ),
                ],
              ),
            ),
          );
        },
        childCount: widget.tracks.length,
      ),
    );
  }

  void _showAlbumOptionsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Shuffle Play'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (widget.tracks.isNotEmpty) {
                  final playbackTracks = widget.tracks
                      .map((t) => PlaybackTrack(
                            id: t.id,
                            name: t.trackName,
                            artistName: t.artistName,
                            albumName: t.albumName,
                            coverUrl: t.coverUrl,
                            filePath: t.filePath,
                            quality: t.quality,
                          ))
                      .toList()..shuffle();
                  ref.read(playbackProvider.notifier).playTrackList(playbackTracks, startIndex: 0);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Album Files'),
              onTap: () {
                Navigator.pop(sheetContext);
                for (final t in widget.tracks) {
                  widget.onEnterSelectionMode(t.id);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
