import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';
import 'package:spotiflac_android/screens/library_playlists_screen.dart';
import 'package:spotiflac_android/screens/library_tracks_folder_screen.dart';
import 'package:spotiflac_android/screens/queue_tab.dart';
import 'package:spotiflac_android/services/downloaded_embedded_cover_resolver.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';

class AppleMusicLibraryRootView extends ConsumerStatefulWidget {
  final String activeFilterMode;
  final Function(String) onFilterChanged;
  final LibraryCollectionsState collectionState;
  final List<dynamic> items; // UnifiedLibraryItem, GroupedAlbum, GroupedLocalAlbum
  final int totalAlbums;
  final int totalSingles;
  final int totalAll;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final Function(String) onToggleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final Function(dynamic) onItemTap;

  const AppleMusicLibraryRootView({
    super.key,
    required this.activeFilterMode,
    required this.onFilterChanged,
    required this.collectionState,
    required this.items,
    required this.totalAlbums,
    required this.totalSingles,
    required this.totalAll,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onClearSelection,
    required this.onSelectAll,
    required this.onItemTap,
  });

  @override
  ConsumerState<AppleMusicLibraryRootView> createState() => _AppleMusicLibraryRootViewState();
}

class _AppleMusicLibraryRootViewState extends ConsumerState<AppleMusicLibraryRootView> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  bool _matchesSearch(String text) {
    return _searchQuery.isEmpty || text.toLowerCase().contains(_searchQuery);
  }

  void _openLikedSongs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LibraryTracksFolderScreen(
          mode: LibraryTracksFolderMode.loved,
        ),
      ),
    );
  }

  void _openWishlist() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LibraryTracksFolderScreen(
          mode: LibraryTracksFolderMode.wishlist,
        ),
      ),
    );
  }

  void _openPlaylist(UserPlaylistCollection playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryTracksFolderScreen(
          mode: LibraryTracksFolderMode.playlist,
          playlistId: playlist.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Colors.redAccent.shade400;

    final playlists = widget.collectionState.playlists;
    final lovedCount = widget.collectionState.lovedCount;
    final wishlistCount = widget.collectionState.wishlistCount;

    // Filter playlists by search query
    final filteredPlaylists = _searchQuery.isEmpty
        ? playlists
        : playlists.where((p) => _matchesSearch(p.name)).toList();

    // Build the items to display: albums when not searching, everything matching when searching
    final displayItems = _searchQuery.isEmpty
        ? widget.items.where((e) => e is GroupedAlbum || e is GroupedLocalAlbum).toList()
        : widget.items.where((item) {
            String title = '';
            String artist = '';
            String album = '';
            if (item is UnifiedLibraryItem) {
              title = item.trackName;
              artist = item.artistName;
              album = item.albumName;
            } else if (item is GroupedAlbum) {
              title = item.albumName;
              artist = item.artistName;
            } else if (item is GroupedLocalAlbum) {
              title = item.albumName;
              artist = item.artistName;
            }
            return _matchesSearch(title) || _matchesSearch(artist) || _matchesSearch(album);
          }).toList();

    // Combined grid items: Liked Songs card, playlists, then albums/songs
    final List<_GridItem> gridItems = [];

    // Add Liked Songs (filter by search)
    if (lovedCount > 0 && _matchesSearch('Liked Songs')) {
      gridItems.add(_GridItem(
        title: 'Liked Songs',
        subtitle: 'Playlist • $lovedCount songs',
        onTap: _openLikedSongs,
        isGradientCover: true,
        gradientColors: const [Color(0xFFff375f), Color(0xFFff6f91)],
        icon: Icons.favorite,
      ));
    }

    // Add Wishlist (filter by search)
    if (wishlistCount > 0 && _matchesSearch('Wishlist')) {
      gridItems.add(_GridItem(
        title: 'Wishlist',
        subtitle: 'Playlist • $wishlistCount songs',
        onTap: _openWishlist,
        isGradientCover: true,
        gradientColors: [accentColor, accentColor.withValues(alpha: 0.6)],
        icon: Icons.add_circle_outline,
      ));
    }

    // Add playlists (already filtered)
    for (final playlist in filteredPlaylists) {
      gridItems.add(_GridItem(
        title: playlist.name,
        subtitle: '${playlist.tracks.length} songs',
        coverUrl: playlist.coverImagePath,
        onTap: () => _openPlaylist(playlist),
        icon: Icons.queue_music,
      ));
    }

    // Add albums and songs
    for (final item in displayItems) {
      if (item is UnifiedLibraryItem) {
        gridItems.add(_GridItem(
          title: item.trackName.isNotEmpty ? item.trackName : item.albumName,
          subtitle: 'Song • ${item.artistName}',
          coverUrl: item.coverUrl ?? item.localCoverPath,
          filePath: item.filePath,
          onTap: () => widget.onItemTap(item),
        ));
      } else if (item is GroupedAlbum) {
        gridItems.add(_GridItem(
          title: item.albumName,
          subtitle: 'Album • ${item.artistName}',
          coverUrl: item.coverUrl,
          onTap: () => widget.onItemTap(item),
        ));
      } else if (item is GroupedLocalAlbum) {
        gridItems.add(_GridItem(
          title: item.albumName,
          subtitle: 'Album • ${item.artistName}',
          coverUrl: item.coverPath,
          filePath: item.tracks.isNotEmpty ? item.tracks.first.filePath : null,
          onTap: () => widget.onItemTap(item),
        ));
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: _isSearching ? 170 : 120,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Library',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 34,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _toggleSearch,
                        child: Icon(
                          _isSearching ? Icons.close : Icons.search,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search Your Library',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade200,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value.toLowerCase());
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Menu Items — hide during search to show filtered results only
          if (!_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _LibraryMenuItem(
                      icon: Icons.queue_music,
                      iconColor: accentColor,
                      title: 'Playlists',
                      count: playlists.length,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LibraryPlaylistsScreen(),
                          ),
                        );
                      },
                    ),
                    _LibraryMenuItem(
                      icon: Icons.person,
                      iconColor: accentColor,
                      title: 'Artists',
                      count: null,
                      onTap: () {
                        // Switch to albums filter mode as closest equivalent
                        widget.onFilterChanged('albums');
                      },
                    ),
                    _LibraryMenuItem(
                      icon: Icons.album,
                      iconColor: accentColor,
                      title: 'Albums',
                      count: widget.totalAlbums,
                      onTap: () {
                        widget.onFilterChanged('albums');
                      },
                    ),
                    _LibraryMenuItem(
                      icon: Icons.music_note,
                      iconColor: accentColor,
                      title: 'Songs',
                      count: lovedCount,
                      onTap: _openLikedSongs,
                    ),
                    _LibraryMenuItem(
                      icon: Icons.download_done,
                      iconColor: accentColor,
                      title: 'Downloaded',
                      count: widget.totalAll,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LibraryTracksFolderScreen(
                              mode: LibraryTracksFolderMode.downloaded,
                            ),
                          ),
                        );
                      },
                      isLast: true,
                    ),
                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recently Added',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          // Recently Added Grid — with albums + playlists
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= gridItems.length) return null;
                  final gridItem = gridItems[index];

                  return GestureDetector(
                    onTap: gridItem.onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildGridCover(gridItem),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gridItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          gridItem.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: gridItems.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 120), // Bottom padding for player
          ),
        ],
      ),
    );
  }

  Widget _buildGridCover(_GridItem item) {
    if (item.isGradientCover) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: item.gradientColors ?? [Colors.red, Colors.pink],
          ),
        ),
        child: Center(
          child: Icon(item.icon ?? Icons.music_note, color: Colors.white, size: 40),
        ),
      );
    }

    final url = item.coverUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey.shade800,
        child: Center(
          child: Icon(item.icon ?? Icons.album, size: 40, color: Colors.grey),
        ),
      );
    }

    if (url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => Icon(Icons.album, size: 40, color: Colors.grey),
        );
      }

      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.album, size: 40, color: Colors.grey));
      }
    }

    if (item.filePath != null && item.filePath!.isNotEmpty) {
      final embeddedPath = DownloadedEmbeddedCoverResolver.resolve(
        item.filePath,
        onChanged: () {
          if (mounted) setState(() {});
        },
      );
      if (embeddedPath != null) {
        final embeddedFile = File(embeddedPath);
        if (embeddedFile.existsSync()) {
          return Image.file(embeddedFile, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.album, size: 40, color: Colors.grey));
        }
      }
    }

    return Container(
      color: Colors.grey.shade800,
      child: Center(
        child: Icon(item.icon ?? Icons.album, size: 40, color: Colors.grey),
      ),
    );
  }
}

class _GridItem {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final String? filePath;
  final VoidCallback onTap;
  final bool isGradientCover;
  final List<Color>? gradientColors;
  final IconData? icon;

  const _GridItem({
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.filePath,
    required this.onTap,
    this.isGradientCover = false,
    this.gradientColors,
    this.icon,
  });
}

class _LibraryMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int? count;
  final VoidCallback onTap;
  final bool isLast;

  const _LibraryMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.count,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 17,
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }
}
