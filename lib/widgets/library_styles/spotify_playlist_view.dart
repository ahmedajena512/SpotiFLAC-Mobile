
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/utils/color_extractor.dart';
import 'package:spotiflac_android/l10n/l10n.dart';

class SpotifyPlaylistView extends ConsumerStatefulWidget {
  final String playlistName;
  final String? coverUrl;
  final String? ownerName;
  final int tracksCount;
  final bool isLoading;
  final String? error;
  
  final VoidCallback? onDownloadAll;
  final VoidCallback? onLoveAll;
  final VoidCallback? onAddPlaylist;
  final VoidCallback? onOptionsPressed;
  final bool isLovedAll;

  final VoidCallback? onPlayAll;

  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;

  const SpotifyPlaylistView({
    super.key,
    required this.playlistName,
    this.coverUrl,
    this.ownerName,
    required this.tracksCount,
    required this.isLoading,
    this.error,
    this.onDownloadAll,
    this.onLoveAll,
    this.onAddPlaylist,
    this.onOptionsPressed,
    this.onPlayAll,
    this.isLovedAll = false,
    required this.itemBuilder,
    required this.itemCount,
  });

  @override
  ConsumerState<SpotifyPlaylistView> createState() =>
      _SpotifyPlaylistViewState();
}

class _SpotifyPlaylistViewState extends ConsumerState<SpotifyPlaylistView> {
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
  void didUpdateWidget(covariant SpotifyPlaylistView oldWidget) {
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

  Widget _buildCoverImage({double? width, double? height, BoxFit? fit}) {
    if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty) {
      if (!widget.coverUrl!.startsWith('http://') && !widget.coverUrl!.startsWith('https://')) {
        return Image.file(
          File(widget.coverUrl!),
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          errorBuilder: (_, _, _) => _coverFallback(width, height),
        );
      }
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
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, size: 80, color: Color(0xFF535353)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _dominantColor ?? const Color(0xFF1DB954); // Default to Spotify green if no cover

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
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
                    bgColor.withValues(alpha: 0.6),
                    const Color(0xFF121212),
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(bgColor),
              _buildActionRow(),
              _buildContent(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color bgColor) {
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
          widget.playlistName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: kToolbarHeight + 20),
                child: ClipRRect(
                  child: _buildCoverImage(width: 220, height: 220),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                widget.playlistName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                  const Icon(Icons.music_note, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Playlist • ${widget.ownerName ?? 'SpotiFLAC'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (widget.onDownloadAll != null) ...[
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white70, size: 28),
                    onPressed: widget.onDownloadAll,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.onAddPlaylist != null) ...[
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 28),
                    onPressed: widget.onAddPlaylist,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.onLoveAll != null) ...[
                  IconButton(
                    icon: Icon(
                      widget.isLovedAll ? Icons.favorite : Icons.favorite_border,
                      color: widget.isLovedAll ? const Color(0xFF1DB954) : Colors.white70,
                      size: 28,
                    ),
                    onPressed: widget.onLoveAll,
                    padding: EdgeInsets.zero,
                  ),
                ],
                if (widget.onOptionsPressed != null) ...[
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70, size: 28),
                    onPressed: widget.onOptionsPressed,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            FloatingActionButton(
              heroTag: 'play_playlist_btn',
              onPressed: widget.onPlayAll,
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
              shape: const CircleBorder(),
              child: const Icon(Icons.play_arrow, size: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
        ),
      );
    }

    if (widget.error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.error!,
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.itemCount == 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              context.l10n.errorNoTracksFound,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        widget.itemBuilder,
        childCount: widget.itemCount,
      ),
    );
  }
}
