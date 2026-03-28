import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/services/download_request_payload.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';
import 'package:spotiflac_android/utils/color_extractor.dart';
import 'package:spotiflac_android/widgets/playlist_picker_sheet.dart';

class SpotifyAlbumView extends ConsumerStatefulWidget {
  final String albumId;
  final String albumName;
  final String? coverUrl;
  final List<Track> tracks;
  final String? extensionId;
  final String? artistId;
  final String? artistName;
  final bool isLoading;
  final String? error;
  final VoidCallback onDownloadAll;
  final VoidCallback onLoveAll;
  final void Function(Track) onDownloadTrack;

  const SpotifyAlbumView({
    super.key,
    required this.albumId,
    required this.albumName,
    this.coverUrl,
    required this.tracks,
    this.extensionId,
    this.artistId,
    this.artistName,
    required this.isLoading,
    this.error,
    required this.onDownloadAll,
    required this.onLoveAll,
    required this.onDownloadTrack,
  });

  @override
  ConsumerState<SpotifyAlbumView> createState() => _SpotifyAlbumViewState();
}

class _SpotifyAlbumViewState extends ConsumerState<SpotifyAlbumView> {
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
  void didUpdateWidget(covariant SpotifyAlbumView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
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
    if (widget.coverUrl == null) return;
    final colors = await ColorExtractor.getColors(widget.coverUrl!);
    if (mounted && colors.isNotEmpty) {
      setState(() {
        _dominantColor = colors.first;
      });
    }
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
          // Gradient Background
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
              _buildActionRow(),
              if (widget.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (widget.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(widget.error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              if (!widget.isLoading && widget.error == null && widget.tracks.isNotEmpty)
                _buildTrackList(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color bgColor, bool isDark) {
    final displayArtist = widget.artistName ??
        (widget.tracks.isNotEmpty ? (widget.tracks.first.albumArtist ?? widget.tracks.first.artistName) : 'Unknown Artist');
    final releaseYear = widget.tracks.isNotEmpty && widget.tracks.first.releaseDate != null
        ? widget.tracks.first.releaseDate!.split('-').first
        : 'Unknown Year';

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
                    child: widget.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.coverUrl!,
                            fit: BoxFit.cover,
                            cacheManager: CoverCacheManager.instance,
                          )
                        : const Icon(Icons.album, size: 80),
                  ),
                ),
              ),
            ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                    backgroundImage: widget.coverUrl != null ? CachedNetworkImageProvider(widget.coverUrl!) : null,
                    child: widget.coverUrl == null ? const Icon(Icons.person, size: 16) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClickableArtistName(
                      artistName: displayArtist,
                      artistId: widget.artistId,
                      coverUrl: widget.coverUrl,
                      extensionId: widget.extensionId,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Album • $releaseYear',
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

  Widget _buildActionRow() {
    final collectionsState = ref.watch(libraryCollectionsProvider);
    final isAllLoved = widget.tracks.isNotEmpty && widget.tracks.every((t) => collectionsState.isLoved(t));

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isAllLoved ? Icons.favorite : Icons.favorite_border,
                color: isAllLoved ? const Color(0xFF1DB954) : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 28,
              ),
              onPressed: widget.onLoveAll,
            ),
            IconButton(
              icon: Icon(Icons.download_for_offline_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
              onPressed: widget.onDownloadAll,
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
              onPressed: () => _showAlbumOptionsSheet(context),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.shuffle, size: 24),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: () {
                if (widget.tracks.isNotEmpty) {
                  final shuffled = List<Track>.from(widget.tracks)..shuffle();
                  ref.read(playbackProvider.notifier).playTracks(shuffled, startIndex: 0);
                }
              },
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (widget.tracks.isNotEmpty) {
                  ref.read(playbackProvider.notifier).playTracks(widget.tracks, startIndex: 0);
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954), // Spotify Green
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.black, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumOptionsSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
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
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                showAddTracksToPlaylistSheet(
                  context,
                  ref,
                  widget.tracks,
                  playlistNamePrefill: widget.albumName,
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.favorite,
                color: widget.tracks.isNotEmpty && widget.tracks.every((t) => ref.read(libraryCollectionsProvider).isLoved(t))
                    ? const Color(0xFF1DB954)
                    : null,
              ),
              title: const Text('Love All Tracks'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onLoveAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('Download All'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onDownloadAll();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = widget.tracks[index];
          return _SpotifyTrackItem(
            track: track,
            allTracks: widget.tracks,
            trackIndex: index,
            onDownload: () => widget.onDownloadTrack(track),
          );
        },
        childCount: widget.tracks.length,
      ),
    );
  }
}

class _SpotifyTrackItem extends ConsumerStatefulWidget {
  final Track track;
  final List<Track> allTracks;
  final int trackIndex;
  final VoidCallback onDownload;

  const _SpotifyTrackItem({
    required this.track,
    required this.allTracks,
    required this.trackIndex,
    required this.onDownload,
  });

  @override
  ConsumerState<_SpotifyTrackItem> createState() => _SpotifyTrackItemState();
}

class _SpotifyTrackItemState extends ConsumerState<_SpotifyTrackItem> {
  bool _isLoadingStream = false;

  void _handleTap(BuildContext context, {required bool isQueued}) async {
    if (isQueued) return;

    try {
      await ref
          .read(playbackProvider.notifier)
          .playTracks(widget.allTracks, startIndex: widget.trackIndex);
      return;
    } catch (_) {
      // Local file not available, fall back to streaming
    }

    if (_isLoadingStream) return;

    setState(() {
      _isLoadingStream = true;
    });

    try {
      final settings = ref.read(settingsProvider);
      final payload = DownloadRequestPayload(
        spotifyId: widget.track.id,
        trackName: widget.track.name,
        artistName: widget.track.artistName,
        albumName: widget.track.albumName,
        service: settings.defaultService,
        quality: settings.audioQuality,
        durationMs: widget.track.duration * 1000,
        coverUrl: widget.track.coverUrl ?? '',
        outputDir: settings.downloadDirectory,
        filenameFormat: settings.filenameFormat,
      );

      final response = await PlatformBridge.getStreamUrl(payload: payload);

      if (response['success'] == true) {
        final streamUrl = response['stream_url'] as String?;
        final lyrics = response['lyrics_lrc'] as String?;

        if (streamUrl != null && streamUrl.isNotEmpty) {
          await ref
              .read(playbackProvider.notifier)
              .playLocalPath(
                path: widget.track.id,
                title: widget.track.name,
                artist: widget.track.artistName,
                album: widget.track.albumName,
                coverUrl: widget.track.coverUrl ?? '',
                streamUrl: streamUrl,
                lyricsUrl: lyrics,
                track: widget.track,
              );
        } else {
          widget.onDownload();
        }
      } else {
        widget.onDownload();
      }
    } catch (e) {
      widget.onDownload();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueItem = ref.watch(
      downloadQueueLookupProvider.select(
        (lookup) => lookup.byTrackId[widget.track.id],
      ),
    );

    final isInHistory = ref.watch(
      downloadHistoryProvider.select((state) {
        if (state.isDownloaded(widget.track.id)) return true;
        final isrc = widget.track.isrc?.trim();
        if (isrc != null && isrc.isNotEmpty && state.getByIsrc(isrc) != null) {
          return true;
        }
        return state.findByTrackAndArtist(widget.track.name, widget.track.artistName) != null;
      }),
    );

    final showLocalLibraryIndicator = ref.watch(
      settingsProvider.select(
        (s) => s.localLibraryEnabled && s.localLibraryShowDuplicates,
      ),
    );
    final isInLocalLibrary = showLocalLibraryIndicator
        ? ref.watch(
            localLibraryProvider.select(
              (state) => state.existsInLibrary(
                isrc: widget.track.isrc,
                trackName: widget.track.name,
                artistName: widget.track.artistName,
              ),
            ),
          )
        : false;

    final isQueued = queueItem != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _handleTap(context, isQueued: isQueued),
      onLongPress: () => TrackCollectionQuickActions.showTrackOptionsSheet(
        context,
        ref,
        widget.track,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            // Track Number (Spotify usually has it for albums)
            SizedBox(
              width: 32,
              child: _isLoadingStream
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${widget.track.trackNumber ?? widget.trackIndex + 1}',
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
                    widget.track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isInLocalLibrary || isInHistory) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1DB954),
                            shape: BoxShape.circle,
                          ),
                          width: 12,
                          height: 12,
                          child: const Icon(
                            Icons.check,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          widget.track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Trailing Icons
            TrackCollectionQuickActions(track: widget.track),
          ],
        ),
      ),
    );
  }
}
