import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/services/download_request_payload.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
class AppleMusicAlbumView extends ConsumerStatefulWidget {
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

  const AppleMusicAlbumView({
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
  ConsumerState<AppleMusicAlbumView> createState() => _AppleMusicAlbumViewState();
}

class _AppleMusicAlbumViewState extends ConsumerState<AppleMusicAlbumView> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;

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
    final showTitle = _scrollController.offset > 240;
    if (showTitle != _showTitleInAppBar) {
      setState(() {
        _showTitleInAppBar = showTitle;
      });
    }
  }

  void _playAll({bool shuffle = false}) {
    if (widget.tracks.isEmpty) return;
    final notifier = ref.read(playbackProvider.notifier);
    if (shuffle) {
      final shuffledTracks = List<Track>.from(widget.tracks)..shuffle();
      notifier.playTracks(shuffledTracks, startIndex: 0);
    } else {
      notifier.playTracks(widget.tracks, startIndex: 0);
    }
  }

  void _showTrackOptions(BuildContext context, Track track) {
    TrackCollectionQuickActions.showTrackOptionsSheet(context, ref, track);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Colors.redAccent.shade400;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 0, // We simulate standard Apple Music transparent-to-opaque behavior
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
                        title: Text(
                          widget.albumName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        centerTitle: true,
                      ),
                    ),
                  )
                : null,
            actions: [
              IconButton(
                icon: Icon(Icons.more_horiz, color: accentColor),
                onPressed: () {
                  // Show album actions
                },
              ),
            ],
          ),
          
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + 20),
                
                // Cover Art
                Center(
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.65,
                    height: MediaQuery.sizeOf(context).width * 0.65,
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
                    child: widget.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.coverUrl!,
                            fit: BoxFit.cover,
                            cacheManager: CoverCacheManager.instance,
                            errorWidget: (context, url, error) => const Icon(Icons.album, size: 80, color: Colors.grey),
                          )
                        : const Icon(Icons.album, size: 80, color: Colors.grey),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Titles
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        widget.albumName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.artistName ?? 'Unknown Artist',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentColor, // Apple Music artist links are accent colored
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Album • ${widget.tracks.length} tracks',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Buttons row
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
          
          if (widget.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (widget.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = widget.tracks[index];
                  return _AppleMusicTrackItem(
                    track: track,
                    allTracks: widget.tracks,
                    trackIndex: index,
                    artistName: widget.artistName,
                    onDownloadTrack: () => widget.onDownloadTrack(track),
                    showTrackOptions: () => _showTrackOptions(context, track),
                  );
                },
                childCount: widget.tracks.length,
              ),
            ),
            
          const SliverToBoxAdapter(
            child: SizedBox(height: 120), // Mini player padding
          ),
        ],
      ),
    );
  }
}

class _AppleMusicTrackItem extends ConsumerStatefulWidget {
  final Track track;
  final List<Track> allTracks;
  final int trackIndex;
  final String? artistName;
  final VoidCallback onDownloadTrack;
  final VoidCallback showTrackOptions;

  const _AppleMusicTrackItem({
    required this.track,
    required this.allTracks,
    required this.trackIndex,
    this.artistName,
    required this.onDownloadTrack,
    required this.showTrackOptions,
  });

  @override
  ConsumerState<_AppleMusicTrackItem> createState() => _AppleMusicTrackItemState();
}

class _AppleMusicTrackItemState extends ConsumerState<_AppleMusicTrackItem> {
  bool _isLoadingStream = false;

  void _handleTap(BuildContext context) async {
    final track = widget.track;
    
    // 1. Try playing first
    try {
      final resolvedPath = await ref.read(playbackProvider.notifier).resolveTrackPath(track);
      if (resolvedPath != null) {
        await ref.read(playbackProvider.notifier).playTracks(widget.allTracks, startIndex: widget.trackIndex);
        return;
      }
    } catch (_) {}

    if (_isLoadingStream) return;

    if (mounted) {
      setState(() {
        _isLoadingStream = true;
      });
    }

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
          await ref.read(playbackProvider.notifier).playLocalPath(
            path: track.id,
            title: track.name,
            artist: track.artistName,
            album: track.albumName,
            coverUrl: track.coverUrl ?? '',
            streamUrl: streamUrl,
            lyricsUrl: lyrics,
            track: track,
          );
        }
      }
    } catch (_) {
      // Stream failed silently
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final historyState = ref.watch(downloadHistoryProvider);
    final isDownloaded = historyState.isDownloaded(widget.track.id) ||
        (widget.track.isrc != null && widget.track.isrc!.isNotEmpty && historyState.getByIsrc(widget.track.isrc!) != null) ||
        historyState.findByTrackAndArtist(widget.track.name, widget.track.artistName) != null;
    
    final localLibraryState = ref.watch(localLibraryProvider);
    final isInLocalLibrary = localLibraryState.existsInLibrary(
      isrc: widget.track.isrc,
      trackName: widget.track.name,
      artistName: widget.track.artistName,
    );

    final showDownload = !isDownloaded && !isInLocalLibrary;

    return InkWell(
      onTap: () => _handleTap(context),
      onLongPress: widget.showTrackOptions,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: _isLoadingStream
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${widget.trackIndex + 1}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.track.artistName.isNotEmpty &&
                      widget.track.artistName != widget.artistName)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showDownload)
              IconButton(
                icon: Icon(Icons.arrow_downward, size: 20, color: Colors.redAccent.shade400),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: widget.onDownloadTrack,
              ),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.showTrackOptions,
            ),
          ],
        ),
      ),
    );
  }
}
