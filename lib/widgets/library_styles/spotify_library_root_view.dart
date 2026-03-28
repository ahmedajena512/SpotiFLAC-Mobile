import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';

import 'package:spotiflac_android/screens/queue_tab.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/screens/library_tracks_folder_screen.dart';

class SpotifyLibraryRootView extends ConsumerStatefulWidget {
  final String activeFilterMode;
  final Function(String) onFilterChanged;
  final LibraryCollectionsState collectionState;
  final List<dynamic> items; // Can be UnifiedLibraryItem, _GroupedAlbum, _GroupedLocalAlbum
  final int totalAlbums;
  final int totalSingles;
  final int totalAll;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final Function(String) onToggleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final Function(dynamic) onItemTap;
  final Function(dynamic)? onOptionsTap;

  // Since we bypassed QueueTab's native item tap for custom UI, we need
  // to expose a way to handle taps on albums/singles if necessary.
  // Actually, we can either re-implement the tap navigation or require it as a parameter.
  // For now, let's keep it simple to match the visual styling.

  const SpotifyLibraryRootView({
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
    this.onOptionsTap,
  });

  @override
  ConsumerState<SpotifyLibraryRootView> createState() => _SpotifyLibraryRootViewState();
}

class _SpotifyLibraryRootViewState extends ConsumerState<SpotifyLibraryRootView> {
  bool _isGridView = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
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

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Color(0xFF7F7F7F)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF535353))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                ref.read(libraryCollectionsProvider.notifier).createPlaylist(name);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          _buildSpotifyHeader(),
          _buildActionRow(),
          _buildContent(),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for mini player
        ],
      ),
    );
  }

  Widget _buildSpotifyHeader() {
    // Determine which chips to show based on standard Spotify UI
    // Usually it's Playlists, Albums, Artists, Downloaded matching SpotiFLAC's capabilities.
    return SliverAppBar(
      backgroundColor: const Color(0xFF121212),
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      expandedHeight: _isSearching ? 168 : 120,
      collapsedHeight: _isSearching ? kToolbarHeight + 108 : kToolbarHeight + 60,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.purple.shade300,
                    child: const Text('A', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Library',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: () => _showCreatePlaylistDialog(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filter Chips
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSpotifyChip('All', widget.totalAll, widget.activeFilterMode == 'all', 'all'),
                    const SizedBox(width: 8),
                    _buildSpotifyChip('Playlists', widget.collectionState.playlistCount, widget.activeFilterMode == 'playlists', 'playlists'),
                    const SizedBox(width: 8),
                    _buildSpotifyChip('Albums', widget.totalAlbums, widget.activeFilterMode == 'albums', 'albums'),
                    const SizedBox(width: 8),
                    _buildSpotifyChip('Songs', widget.totalAll, widget.activeFilterMode == 'songs', 'songs'),
                    const SizedBox(width: 8),
                    _buildSpotifyChip('Singles', widget.totalSingles, widget.activeFilterMode == 'singles', 'singles'),
                  ],
                ),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 12),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search in Your Library',
                      hintStyle: TextStyle(color: Color(0xFF7F7F7F), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Color(0xFF7F7F7F), size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyChip(String label, int count, bool isSelected, String mode) {
    if (count == 0 && mode != 'all') return const SizedBox.shrink(); // Hide empty filters

    final bgColor = isSelected ? const Color(0xFF1DB954) : const Color(0xFF2A2A2A);
    final textColor = isSelected ? Colors.white : const Color(0xFFB3B3B3);
    final badgeBgColor = isSelected ? const Color(0xFF14853B) : const Color(0xFF3E3E3E);

    return GestureDetector(
      onTap: () => widget.onFilterChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w400, fontSize: 13)),
            if (count > 0 && mode != 'all') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.swap_vert, color: Color(0xFFB3B3B3), size: 18),
            const SizedBox(width: 8),
            const Text('Recents', style: TextStyle(color: Color(0xFFB3B3B3), fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            IconButton(
              icon: Icon(_isGridView ? Icons.grid_view : Icons.view_list, color: const Color(0xFFB3B3B3), size: 20),
              onPressed: _toggleViewMode,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final showPlaylists = widget.activeFilterMode == 'all' || widget.activeFilterMode == 'playlists';

    // Filter playlists by search query
    final filteredPlaylists = _searchQuery.isEmpty
        ? widget.collectionState.playlists
        : widget.collectionState.playlists.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();

    // Filter dynamic items by search query
    final filteredItems = _searchQuery.isEmpty
        ? widget.items
        : widget.items.where((item) => _matchesSearch(item)).toList();

    // Check if fixed items match search
    final showLikedSongs = _searchQuery.isEmpty || 'liked songs'.contains(_searchQuery);
    final showWishlist = widget.collectionState.wishlistCount > 0 &&
        (_searchQuery.isEmpty || 'wishlist'.contains(_searchQuery));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: _isGridView
          ? _buildGridContent(showPlaylists, filteredPlaylists, filteredItems, showLikedSongs, showWishlist)
          : _buildListContent(showPlaylists, filteredPlaylists, filteredItems, showLikedSongs, showWishlist),
    );
  }

  bool _matchesSearch(dynamic item) {
    if (item is UnifiedLibraryItem) {
      return item.trackName.toLowerCase().contains(_searchQuery) ||
          item.artistName.toLowerCase().contains(_searchQuery) ||
          item.albumName.toLowerCase().contains(_searchQuery);
    } else if (item is GroupedAlbum) {
      return item.albumName.toLowerCase().contains(_searchQuery) ||
          item.artistName.toLowerCase().contains(_searchQuery);
    } else if (item is GroupedLocalAlbum) {
      return item.albumName.toLowerCase().contains(_searchQuery) ||
          item.artistName.toLowerCase().contains(_searchQuery);
    }
    return false;
  }

  Widget _buildListContent(bool showPlaylists, List<UserPlaylistCollection> playlists, List<dynamic> items, bool showLikedSongs, bool showWishlist) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          int currentIndex = index;

          if (showPlaylists) {
            if (showLikedSongs) {
              if (currentIndex == 0) return _buildLikedSongsTile(isGrid: false);
              currentIndex--;
            }

            if (showWishlist) {
              if (currentIndex == 0) return _buildWishlistTile(isGrid: false);
              currentIndex--;
            }

            if (currentIndex < playlists.length) {
              return _buildPlaylistTile(playlists[currentIndex], isGrid: false);
            }
            currentIndex -= playlists.length;
          }

          if (widget.activeFilterMode != 'playlists') {
            if (currentIndex < items.length) {
              return _buildDynamicItemTile(items[currentIndex], isGrid: false);
            }
          }

          return null;
        },
      ),
    );
  }

  Widget _buildGridContent(bool showPlaylists, List<UserPlaylistCollection> playlists, List<dynamic> items, bool showLikedSongs, bool showWishlist) {
    int totalItems = 0;
    if (showPlaylists) {
      if (showLikedSongs) totalItems += 1;
      if (showWishlist) totalItems += 1;
      totalItems += playlists.length;
    }
    if (widget.activeFilterMode != 'playlists') {
      totalItems += items.length;
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          int currentIndex = index;

          if (showPlaylists) {
            if (showLikedSongs) {
              if (currentIndex == 0) return _buildLikedSongsTile(isGrid: true);
              currentIndex--;
            }

            if (showWishlist) {
              if (currentIndex == 0) return _buildWishlistTile(isGrid: true);
              currentIndex--;
            }

            if (currentIndex < playlists.length) {
              return _buildPlaylistTile(playlists[currentIndex], isGrid: true);
            }
            currentIndex -= playlists.length;
          }

          if (widget.activeFilterMode != 'playlists') {
            if (currentIndex < items.length) {
              return _buildDynamicItemTile(items[currentIndex], isGrid: true);
            }
          }

          return null;
        },
        childCount: totalItems,
      ),
    );
  }

  Widget _buildLikedSongsTile({required bool isGrid}) {
    final title = 'Liked Songs';
    final subtitle = 'Playlist • ${widget.collectionState.lovedCount} songs';
    final cover = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF450af5), Color(0xFFc4efd9)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.favorite, color: Colors.white, size: 32),
      ),
    );

    return _buildTile(cover: cover, title: title, subtitle: subtitle, isGrid: isGrid, onTap: _openLikedSongs);
  }

  Widget _buildWishlistTile({required bool isGrid}) {
    final title = 'Wishlist';
    final subtitle = 'Playlist • ${widget.collectionState.wishlistCount} songs';
    final cover = Container(
      color: const Color(0xFF1DB954),
      child: const Center(
        child: Icon(Icons.add_circle_outline, color: Colors.white, size: 32),
      ),
    );

    return _buildTile(cover: cover, title: title, subtitle: subtitle, isGrid: isGrid, onTap: _openWishlist);
  }

  Widget _buildPlaylistTile(UserPlaylistCollection playlist, {required bool isGrid}) {
    final title = playlist.name;
    final subtitle = 'Playlist • ${playlist.tracks.length} songs';
    final cover = playlist.coverImagePath != null
        ? Image.file(File(playlist.coverImagePath!), fit: BoxFit.cover)
        : Container(
            color: const Color(0xFF282828),
            child: const Center(child: Icon(Icons.music_note, color: Color(0xFF535353), size: 32)),
          );

    return _buildTile(cover: cover, title: title, subtitle: subtitle, isGrid: isGrid, onTap: () => _openPlaylist(playlist));
  }

  Widget _fallbackCover({required bool isGrid, required bool isCircular}) {
    return Container(
      color: const Color(0xFF282828),
      child: Center(child: Icon(Icons.album, color: const Color(0xFF535353), size: isGrid ? 32 : 24)),
    );
  }

  Widget _buildDynamicItemTile(dynamic item, {required bool isGrid}) {
    String title = '';
    String subtitle = '';
    Widget coverImg = const SizedBox();

    if (item is UnifiedLibraryItem) {
      title = item.trackName.isNotEmpty ? item.trackName : item.albumName;
      subtitle = 'Song • ${item.artistName}';
      coverImg = item.coverUrl != null
          ? CachedNetworkImage(
              imageUrl: item.coverUrl!, 
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: const Color(0xFF282828),
                child: const Center(child: Icon(Icons.music_note, color: Color(0xFF535353))),
              ),
            )
          : (item.localCoverPath != null
              ? Image.file(File(item.localCoverPath!), fit: BoxFit.cover)
              : Container(
                  color: const Color(0xFF282828),
                  child: const Center(child: Icon(Icons.music_note, color: Color(0xFF535353), size: 32)),
                ));
    } else if (item is GroupedAlbum) {
      try {
        title = item.albumName;
        subtitle = 'Album • ${item.artistName}';
        final url = item.coverUrl;
        if (url != null && url.isNotEmpty) {
          final isLocal = !url.startsWith('http://') && !url.startsWith('https://');
          if (isLocal) {
            coverImg = Image.file(
              File(url),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallbackCover(isGrid: isGrid, isCircular: false),
            );
          } else {
            coverImg = CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              cacheManager: CoverCacheManager.instance,
              placeholder: (_, _) => _fallbackCover(isGrid: isGrid, isCircular: false),
              errorWidget: (_, _, _) => _fallbackCover(isGrid: isGrid, isCircular: false),
            );
          }
        } else {
          coverImg = _fallbackCover(isGrid: isGrid, isCircular: false);
        }
      } catch (e) {
        title = 'Unknown Album';
        subtitle = 'Album';
        coverImg = _fallbackCover(isGrid: isGrid, isCircular: false);
      }
    } else if (item is GroupedLocalAlbum) {
      try {
        title = item.albumName;
        subtitle = 'Album • ${item.artistName}';
        final path = item.coverPath;
        if (path != null && path.isNotEmpty) {
          coverImg = Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackCover(isGrid: isGrid, isCircular: false),
          );
        } else {
          coverImg = _fallbackCover(isGrid: isGrid, isCircular: false);
        }
      } catch (e) {
        title = 'Unknown Album';
        subtitle = 'Album';
        coverImg = _fallbackCover(isGrid: isGrid, isCircular: false);
      }
    }

    final String? id = (item is UnifiedLibraryItem) ? item.id : null;
    final bool isSelected = id != null && widget.selectedIds.contains(id);

    return _buildTile(
      cover: coverImg,
      title: title,
      subtitle: subtitle,
      isGrid: isGrid,
      isCircular: false,
      isSelected: isSelected,
      isSelectionMode: widget.isSelectionMode,
      onOptionsTap: widget.onOptionsTap != null ? () => widget.onOptionsTap!(item) : null,
      onTap: () {
        if (widget.isSelectionMode && id != null) {
          widget.onToggleSelection(id);
        } else {
          widget.onItemTap(item);
        }
      },
      onLongPress: id != null && !widget.isSelectionMode ? () => widget.onToggleSelection(id) : null,
    );
  }

  Widget _buildTile({
    required Widget cover,
    required String title,
    required String subtitle,
    required bool isGrid,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    VoidCallback? onOptionsTap,
    bool isCircular = false,
    bool isSelectionMode = false,
    bool isSelected = false,
  }) {
    final Widget coverWithSelection = isSelectionMode
        ? Stack(
            fit: StackFit.passthrough,
            children: [
              Opacity(opacity: 0.5, child: cover),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFF1DB954) : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          )
        : cover;

    if (isGrid) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isCircular ? 100 : 0),
                child: coverWithSelection,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: isSelected ? const Color(0xFF282828) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 64, 
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isCircular ? 32 : 0),
                  child: coverWithSelection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isGrid && onOptionsTap != null)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Color(0xFFB3B3B3)),
                  onPressed: onOptionsTap,
                ),
            ],
          ),
        ),
      );
    }
  }
}
