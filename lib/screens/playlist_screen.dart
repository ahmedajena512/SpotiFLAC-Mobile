import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/library_appearance_provider.dart';
import 'package:spotiflac_android/models/library_styles.dart';
import 'package:spotiflac_android/widgets/library_styles/spotify_playlist_view.dart';
import 'package:spotiflac_android/widgets/library_styles/apple_music_playlist_view.dart';
import 'package:spotiflac_android/widgets/download_service_picker.dart';
import 'package:spotiflac_android/widgets/playlist_picker_sheet.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';
import 'package:spotiflac_android/services/download_request_payload.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  final String playlistName;
  final String? coverUrl;
  final List<Track> tracks;
  final String? playlistId;

  const PlaylistScreen({
    super.key,
    required this.playlistName,
    this.coverUrl,
    required this.tracks,
    this.playlistId,
  });

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  bool _showTitleInAppBar = false;
  final ScrollController _scrollController = ScrollController();
  List<Track>? _fetchedTracks;
  bool _isLoading = false;
  String? _error;
  String? _resolvedPlaylistName;
  String? _resolvedCoverUrl;

  List<Track> get _tracks => _fetchedTracks ?? widget.tracks;
  String get _playlistName => _resolvedPlaylistName ?? widget.playlistName;
  String? get _coverUrl => _resolvedCoverUrl ?? widget.coverUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchTracksIfNeeded();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTracksIfNeeded() async {
    if (widget.tracks.isNotEmpty || widget.playlistId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String playlistId = widget.playlistId!;
      late final Map<String, dynamic> result;
      if (playlistId.startsWith('deezer:')) {
        playlistId = playlistId.substring(7);
        result = await PlatformBridge.getDeezerMetadata('playlist', playlistId);
      } else if (playlistId.startsWith('qobuz:')) {
        playlistId = playlistId.substring(6);
        result = await PlatformBridge.getQobuzMetadata('playlist', playlistId);
      } else if (playlistId.startsWith('tidal:')) {
        playlistId = playlistId.substring(6);
        result = await PlatformBridge.getTidalMetadata('playlist', playlistId);
      } else {
        result = await PlatformBridge.getDeezerMetadata('playlist', playlistId);
      }
      if (!mounted) return;

      final playlistInfo = result['playlist_info'] as Map<String, dynamic>?;
      final owner = playlistInfo?['owner'] as Map<String, dynamic>?;

      // Go backend returns 'track_list' not 'tracks'
      final trackList = result['track_list'] as List<dynamic>? ?? [];
      final tracks = trackList
          .map((t) => _parseTrack(t as Map<String, dynamic>))
          .toList();

      setState(() {
        _fetchedTracks = tracks;
        _resolvedPlaylistName = (playlistInfo?['name'] ?? owner?['name'])
            ?.toString();
        _resolvedCoverUrl = (playlistInfo?['images'] ?? owner?['images'])
            ?.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Track _parseTrack(Map<String, dynamic> data) {
    int durationMs = 0;
    final durationValue = data['duration_ms'];
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.toInt();
    }

    return Track(
      id: (data['spotify_id'] ?? data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? data['album'] ?? '').toString(),
      albumArtist: data['album_artist']?.toString(),
      artistId: (data['artist_id'] ?? data['artistId'])?.toString(),
      albumId: data['album_id']?.toString(),
      coverUrl: (data['cover_url'] ?? data['images'])?.toString(),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      releaseDate: data['release_date']?.toString(),
    );
  }

  void _onScroll() {
    final expandedHeight = _calculateExpandedHeight(context);
    final shouldShow =
        _scrollController.offset > (expandedHeight - kToolbarHeight - 20);
    if (shouldShow != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShow);
    }
  }

  double _calculateExpandedHeight(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    return (mediaSize.height * 0.55).clamp(360.0, 520.0);
  }

  /// Upgrade cover URL to a reasonable resolution for full-screen display.
  String? _highResCoverUrl(String? url) {
    if (url == null) return null;
    // Spotify CDN: upgrade 300 → 640 only
    if (url.contains('ab67616d00001e02')) {
      return url.replaceAll('ab67616d00001e02', 'ab67616d0000b273');
    }
    // Deezer CDN: upgrade to 1000x1000
    final deezerRegex = RegExp(r'/(\d+)x(\d+)-(\d+)-(\d+)-(\d+)-(\d+)\.jpg$');
    if (url.contains('cdn-images.dzcdn.net') && deezerRegex.hasMatch(url)) {
      return url.replaceAllMapped(
        deezerRegex,
        (m) => '/1000x1000-${m[3]}-${m[4]}-${m[5]}-${m[6]}.jpg',
      );
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(libraryAppearanceProvider).libraryStyle;
    if (style == LibraryStyle.spotifyStyle) {
      return SpotifyPlaylistView(
        playlistName: _playlistName,
        coverUrl: _highResCoverUrl(_coverUrl) ?? _coverUrl,
        ownerName: null, // "SpotiFLAC" is fallback in view
        tracksCount: _tracks.length,
        isLoading: _isLoading,
        error: _error,
        onDownloadAll: _tracks.isEmpty ? null : () => _confirmDownloadAll(context),
        onLoveAll: _tracks.isEmpty ? null : () => _loveAll(_tracks),
        isLovedAll: _tracks.isNotEmpty && _tracks.every((t) => ref.watch(libraryCollectionsProvider).isLoved(t)),
        onAddPlaylist: _tracks.isEmpty ? null : () => showAddTracksToPlaylistSheet(context, ref, _tracks, playlistNamePrefill: widget.playlistName),
        onPlayAll: _tracks.isEmpty ? null : () => ref.read(playbackProvider.notifier).playTracks(_tracks, startIndex: 0),
        itemCount: _tracks.length,
        itemBuilder: (context, index) {
          final track = _tracks[index];
          return KeyedSubtree(
            key: ValueKey(track.id),
            child: _PlaylistTrackItem(
              track: track,
              allTracks: _tracks,
              trackIndex: index,
              onDownload: () => _downloadTrack(context, track),
              isSpotifyStyle: true,
            ),
          );
        },
      );
    }

    if (style == LibraryStyle.appleMusicStyle) {
      return AppleMusicPlaylistView(
        playlistName: _playlistName,
        coverUrl: _highResCoverUrl(_coverUrl) ?? _coverUrl,
        ownerName: null,
        tracksCount: _tracks.length,
        isLoading: _isLoading,
        error: _error,
        onDownloadAll: _tracks.isEmpty ? null : () => _confirmDownloadAll(context),
        onLoveAll: _tracks.isEmpty ? null : () => _loveAll(_tracks),
        isLovedAll: _tracks.isNotEmpty && _tracks.every((t) => ref.watch(libraryCollectionsProvider).isLoved(t)),
        onAddPlaylist: _tracks.isEmpty ? null : () => showAddTracksToPlaylistSheet(context, ref, _tracks, playlistNamePrefill: widget.playlistName),
        onPlayAll: _tracks.isEmpty ? null : () => ref.read(playbackProvider.notifier).playTracks(_tracks, startIndex: 0),
        itemCount: _tracks.length,
        itemBuilder: (context, index) {
          final track = _tracks[index];
          return KeyedSubtree(
            key: ValueKey(track.id),
            child: _PlaylistTrackItem(
              track: track,
              allTracks: _tracks,
              trackIndex: index,
              onDownload: () => _downloadTrack(context, track),
              isSpotifyStyle: false,
            ),
          );
        },
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(context, colorScheme),
          _buildInfoCard(context, colorScheme),
          _buildTrackList(context, colorScheme),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    final expandedHeight = _calculateExpandedHeight(context);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showTitleInAppBar ? 1.0 : 0.0,
        child: Text(
          _playlistName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapseRatio =
              (constraints.maxHeight - kToolbarHeight) /
              (expandedHeight - kToolbarHeight);
          final showContent = collapseRatio > 0.3;

          return FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (_coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: _highResCoverUrl(_coverUrl) ?? _coverUrl!,
                    fit: BoxFit.cover,
                    cacheManager: CoverCacheManager.instance,
                    placeholder: (_, _) =>
                        Container(color: colorScheme.surface),
                    errorWidget: (_, _, _) =>
                        Container(color: colorScheme.surface),
                  )
                else
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.playlist_play,
                      size: 80,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: expandedHeight * 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 40,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: showContent ? 1.0 : 0.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _playlistName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_tracks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.playlist_play,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.tracksCount(_tracks.length),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLoveAllButton(),
                              const SizedBox(width: 12),
                              _buildDownloadAllCenterButton(context),
                              const SizedBox(width: 12),
                              _buildAddToPlaylistButton(context),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            stretchModes: const [StretchMode.zoomBackground],
          );
        },
      ),
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ColorScheme colorScheme) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildTrackList(BuildContext context, ColorScheme colorScheme) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              context.l10n.errorNoTracksFound,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final track = _tracks[index];
        return KeyedSubtree(
          key: ValueKey(track.id),
          child: _PlaylistTrackItem(
            track: track,
            allTracks: _tracks,
            trackIndex: index,
            onDownload: () => _downloadTrack(context, track),
            isSpotifyStyle: false,
          ),
        );
      }, childCount: _tracks.length),
    );
  }

  void _downloadTrack(BuildContext context, Track track) {
    final settings = ref.read(settingsProvider);

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: track.name,
        artistName: track.artistName,
        coverUrl: track.coverUrl,
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addToQueue(
                track,
                service,
                qualityOverride: quality,
                playlistName: _playlistName,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.snackbarAddedToQueue(track.name)),
            ),
          );
        },
      );
    } else {
      ref
          .read(downloadQueueProvider.notifier)
          .addToQueue(
            track,
            settings.defaultService,
            playlistName: _playlistName,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
      );
    }
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: Colors.white),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildLoveAllButton() {
    final collectionsState = ref.watch(libraryCollectionsProvider);
    final allLoved =
        _tracks.isNotEmpty && _tracks.every((t) => collectionsState.isLoved(t));

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: _tracks.isEmpty ? null : () => _loveAll(_tracks),
        icon: Icon(
          allLoved ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: allLoved ? Colors.redAccent : Colors.white,
        ),
        tooltip: allLoved
            ? context.l10n.trackOptionRemoveFromLoved
            : context.l10n.tooltipLoveAll,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDownloadAllCenterButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: _tracks.isEmpty ? null : () => _confirmDownloadAll(context),
      icon: const Icon(Icons.download_rounded, size: 18),
      label: Text(context.l10n.downloadAllCount(_tracks.length)),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildAddToPlaylistButton(BuildContext context) {
    return _buildCircleButton(
      icon: Icons.playlist_add,
      tooltip: context.l10n.tooltipAddToPlaylist,
      onPressed: _tracks.isEmpty
          ? null
          : () => showAddTracksToPlaylistSheet(context, ref, _tracks, playlistNamePrefill: widget.playlistName),
    );
  }

  void _confirmDownloadAll(BuildContext context) {
    if (_tracks.isEmpty) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          title: Text(context.l10n.dialogDownloadAllTitle),
          content: Text(context.l10n.dialogDownloadAllMessage(_tracks.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.dialogCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _downloadAll(context);
              },
              child: Text(context.l10n.dialogDownload),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loveAll(List<Track> tracks) async {
    final notifier = ref.read(libraryCollectionsProvider.notifier);
    final state = ref.read(libraryCollectionsProvider);
    final allLoved = tracks.every((t) => state.isLoved(t));

    if (allLoved) {
      for (final track in tracks) {
        final key = trackCollectionKey(track);
        await notifier.removeFromLoved(key);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.snackbarRemovedTracksFromLoved(tracks.length),
            ),
          ),
        );
      }
    } else {
      int addedCount = 0;
      for (final track in tracks) {
        if (!state.isLoved(track)) {
          await notifier.toggleLoved(track);
          addedCount++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarAddedTracksToLoved(addedCount)),
          ),
        );
      }
    }
  }

  void _downloadAll(BuildContext context) {
    _downloadTracks(context, _tracks);
  }

  void _downloadTracks(BuildContext context, List<Track> tracks) {
    if (tracks.isEmpty) return;

    // Skip already-downloaded tracks
    final historyState = ref.read(downloadHistoryProvider);
    final settings = ref.read(settingsProvider);
    final localLibState = (settings.localLibraryEnabled && settings.localLibraryShowDuplicates)
        ? ref.read(localLibraryProvider)
        : null;
    final tracksToQueue = <Track>[];
    int skippedCount = 0;

    for (final track in tracks) {
      final isInHistory = historyState.isDownloaded(track.id) ||
          (track.isrc != null && historyState.getByIsrc(track.isrc!) != null) ||
          historyState.findByTrackAndArtist(track.name, track.artistName) != null;
      final isInLocal = localLibState?.existsInLibrary(
            isrc: track.isrc,
            trackName: track.name,
            artistName: track.artistName,
          ) ??
          false;

      if (isInHistory || isInLocal) {
        skippedCount++;
      } else {
        tracksToQueue.add(track);
      }
    }

    if (tracksToQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.discographySkippedDownloaded(0, skippedCount),
          ),
        ),
      );
      return;
    }

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: '${tracksToQueue.length} tracks',
        artistName: _playlistName,
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addMultipleToQueue(
                tracksToQueue,
                service,
                qualityOverride: quality,
                playlistName: _playlistName,
              );
          _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
        },
      );
    } else {
      ref
          .read(downloadQueueProvider.notifier)
          .addMultipleToQueue(
            tracksToQueue,
            settings.defaultService,
            playlistName: _playlistName,
          );
      _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
    }
  }

  void _showQueuedSnackbar(BuildContext context, int added, int skipped) {
    final message = skipped > 0
        ? context.l10n.discographySkippedDownloaded(added, skipped)
        : context.l10n.snackbarAddedTracksToQueue(added);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Separate Consumer widget for each track - only rebuilds when this specific track's status changes
class _PlaylistTrackItem extends ConsumerStatefulWidget {
  final Track track;
  final List<Track> allTracks;
  final int trackIndex;
  final VoidCallback onDownload;
  final bool isSpotifyStyle;

  const _PlaylistTrackItem({
    required this.track,
    required this.allTracks,
    required this.trackIndex,
    required this.onDownload,
    required this.isSpotifyStyle,
  });

  @override
  ConsumerState<_PlaylistTrackItem> createState() => _PlaylistTrackItemState();
}

class _PlaylistTrackItemState extends ConsumerState<_PlaylistTrackItem> {
  bool _isLoadingStream = false;

  void _handleTap(BuildContext context, {required bool isQueued}) async {
    if (isQueued) return;

    final resolvedPath = await ref.read(playbackProvider.notifier).resolveTrackPath(widget.track);
    if (resolvedPath != null) {
      await ref
          .read(playbackProvider.notifier)
          .playTracks(widget.allTracks, startIndex: widget.trackIndex);
      return;
    }

    if (_isLoadingStream) return;

    setState(() => _isLoadingStream = true);

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
      if (mounted) setState(() => _isLoadingStream = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

    // Check local library for duplicate detection
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

    if (widget.isSpotifyStyle) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: widget.track.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.track.coverUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                cacheManager: CoverCacheManager.instance,
              )
            : Container(
                width: 48,
                height: 48,
                color: const Color(0xFF282828),
                child: const Icon(Icons.music_note, color: Color(0xFF535353)),
              ),
        title: Text(
          widget.track.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (isInHistory || isInLocalLibrary) ...[
              const Icon(Icons.download_for_offline, color: Color(0xFF1DB954), size: 14),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                widget.track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingStream)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onPressed: () => TrackCollectionQuickActions.showTrackOptionsSheet(context, ref, widget.track),
              ),
          ],
        ),
        onTap: () => _handleTap(context, isQueued: isQueued),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: widget.track.coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.track.coverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    memCacheWidth: 96,
                    cacheManager: CoverCacheManager.instance,
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
          title: Text(
            widget.track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  widget.track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              if (isInLocalLibrary || isInHistory) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 10,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        context.l10n.libraryInLibrary,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isLoadingStream
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: colorScheme.primary,
                      ),
                      onPressed: () => _handleTap(context, isQueued: isQueued),
                    ),
              TrackCollectionQuickActions(track: widget.track),
            ],
          ),
          onTap: () => _handleTap(context, isQueued: isQueued),
          onLongPress: () => TrackCollectionQuickActions.showTrackOptionsSheet(
            context,
            ref,
            widget.track,
          ),
        ),
      ),
    );
  }
}
