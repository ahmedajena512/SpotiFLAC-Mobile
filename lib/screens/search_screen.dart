import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/track_provider.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';
import 'package:spotiflac_android/widgets/animation_utils.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';
import 'package:spotiflac_android/services/download_request_payload.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String query;

  const SearchScreen({super.key, required this.query});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    if (widget.query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(trackProvider.notifier).search(widget.query);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final _loadingStreamIndices = <int>{};

  void _search() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(trackProvider.notifier).search(query);
    }
  }

  void _downloadTrack(Track track) {
    final settings = ref.read(settingsProvider);
    ref
        .read(downloadQueueProvider.notifier)
        .addToQueue(track, settings.defaultService);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
    );
  }

  void _playTrack(List<Track> allTracks, int index) async {
    final track = allTracks[index];

    // First try playing local files directly
    try {
      await ref
          .read(playbackProvider.notifier)
          .playTracks(allTracks, startIndex: index);
      return; // Success, actually found a local file to play
    } catch (_) {
      // Local file not available, fall back to streaming the track
    }

    if (_loadingStreamIndices.contains(index)) return;

    setState(() {
      _loadingStreamIndices.add(index);
    });

    try {
      final settings = ref.read(settingsProvider);
      final payload = DownloadRequestPayload(
        spotifyId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        service: settings.defaultService,
        quality: settings.audioQuality,
        durationMs: track.duration * 1000,
        coverUrl: track.coverUrl ?? '',
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
                path: track.id, // Using Spotify ID as identifier
                title: track.name,
                artist: track.artistName,
                album: track.albumName,
                coverUrl: track.coverUrl ?? '',
                streamUrl: streamUrl,
                lyricsUrl: lyrics,
                track: track,
              );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load stream: ${response['error'] ?? 'Unknown error'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing stream: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStreamIndices.remove(index);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(trackProvider.select((s) => s.tracks));
    final isLoading = ref.watch(trackProvider.select((s) => s.isLoading));
    final error = ref.watch(trackProvider.select((s) => s.error));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search tracks...',
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
          autofocus: widget.query.isEmpty,
        ),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLoading) LinearProgressIndicator(color: colorScheme.primary),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(error, style: TextStyle(color: colorScheme.error)),
            ),
          Expanded(
            child: AnimatedStateSwitcher(
              child: isLoading && tracks.isEmpty
                  ? const TrackListSkeleton(key: ValueKey('loading'))
                  : tracks.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : ListView.builder(
                      key: const ValueKey('results'),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) => StaggeredListItem(
                        index: index,
                        child: _buildTrackTile(tracks[index], tracks, index, colorScheme),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Search for tracks',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(
    Track track,
    List<Track> allTracks,
    int index,
    ColorScheme colorScheme,
  ) {
    // Check if track is in local library or download history
    final localState = ref.watch(localLibraryProvider);
    final historyNotifier = ref.read(downloadHistoryProvider.notifier);

    final isrc = track.isrc?.trim();
    final hasLocal =
        historyNotifier.getBySpotifyId(track.id) != null ||
        (isrc != null &&
            isrc.isNotEmpty &&
            historyNotifier.getByIsrc(isrc) != null) ||
        localState.findByTrackAndArtist(track.name, track.artistName) != null;

    final coverWidget = track.coverUrl != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: track.coverUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              memCacheWidth: 144,
              memCacheHeight: 144,
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
            child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
          );

    return ListTile(
      leading: Stack(
        children: [
          coverWidget,
          if (hasLocal)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClickableArtistName(
            artistName: track.artistName,
            artistId: track.artistId,
            coverUrl: track.coverUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          ClickableAlbumName(
            albumName: track.albumName,
            albumId: track.albumId,
            artistName: track.artistName,
            coverUrl: track.coverUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      onLongPress: () => TrackCollectionQuickActions.showTrackOptionsSheet(
        context,
        ref,
        track,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _loadingStreamIndices.contains(index)
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
                  tooltip: 'Play',
                  onPressed: () => _playTrack(allTracks, index),
                ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download',
            onPressed: () => _downloadTrack(track),
          ),
        ],
      ),
      onTap: () => _playTrack(allTracks, index),
    );
  }
}
