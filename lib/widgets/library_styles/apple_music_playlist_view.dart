import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';

/// Apple Music style playlist view.
/// Mirrors [SpotifyPlaylistView]'s constructor for drop-in replacement.
class AppleMusicPlaylistView extends ConsumerStatefulWidget {
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

  const AppleMusicPlaylistView({
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
  ConsumerState<AppleMusicPlaylistView> createState() =>
      _AppleMusicPlaylistViewState();
}

class _AppleMusicPlaylistViewState extends ConsumerState<AppleMusicPlaylistView> {
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

  Widget _buildCoverImage(double size) {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) {
      return _fallbackCover(size);
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size, height: size,
        fit: BoxFit.cover,
        cacheManager: CoverCacheManager.isInitialized ? CoverCacheManager.instance : null,
        errorWidget: (context, url, error) => _fallbackCover(size),
      );
    }
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackCover(size));
    }
    return _fallbackCover(size);
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size, height: size,
      color: Colors.grey.shade800,
      child: const Icon(Icons.queue_music, size: 64, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Colors.redAccent.shade400;
    final coverSize = MediaQuery.sizeOf(context).width * 0.55;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
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
                        title: Text(widget.playlistName,
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                        centerTitle: true,
                      ),
                    ),
                  )
                : null,
            actions: [
              if (widget.onOptionsPressed != null)
                IconButton(
                  icon: Icon(Icons.more_horiz, color: accentColor),
                  onPressed: widget.onOptionsPressed,
                ),
            ],
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
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildCoverImage(coverSize),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(widget.playlistName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                      if (widget.ownerName != null) ...[
                        const SizedBox(height: 4),
                        Text(widget.ownerName!,
                          style: TextStyle(color: accentColor, fontSize: 16)),
                      ],
                      const SizedBox(height: 4),
                      Text('${widget.tracksCount} tracks',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Play / Shuffle + actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onPlayAll,
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
                          onPressed: widget.onPlayAll != null ? () {
                            // Shuffle play — parent should handle this via onPlayAll wrapper
                            widget.onPlayAll!();
                          } : null,
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
                // Action icons row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (widget.onDownloadAll != null)
                        IconButton(
                          icon: const Icon(Icons.download_for_offline_outlined),
                          color: accentColor,
                          onPressed: widget.onDownloadAll,
                          tooltip: 'Download All',
                        ),
                      if (widget.onAddPlaylist != null)
                        IconButton(
                          icon: const Icon(Icons.playlist_add),
                          color: accentColor,
                          onPressed: widget.onAddPlaylist,
                          tooltip: 'Add to Playlist',
                        ),
                      if (widget.onLoveAll != null)
                        IconButton(
                          icon: Icon(
                            widget.isLovedAll ? Icons.favorite : Icons.favorite_border,
                            color: widget.isLovedAll ? Colors.red : accentColor,
                          ),
                          onPressed: widget.onLoveAll,
                          tooltip: widget.isLovedAll ? 'Unlike All' : 'Love All',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          if (widget.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (widget.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(widget.error!, style: const TextStyle(color: Colors.red))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                widget.itemBuilder,
                childCount: widget.itemCount,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
