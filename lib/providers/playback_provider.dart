import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotiflac_android/constants/playback_constants.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/services/audio_player_service.dart';
import 'package:spotiflac_android/services/library_database.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/utils/file_access.dart';
import 'package:spotiflac_android/utils/logger.dart';
import 'package:spotiflac_android/widgets/linx_player/lyric/lyrics_models.dart';
import 'package:spotiflac_android/widgets/linx_player/lyric/lyrics_parser.dart';

final _log = AppLogger('PlaybackProvider');

/// Playback state holding all information about the current playback session.
class PlaybackState {
  /// The index of the currently playing track in the playlist.
  final int currentIndex;

  /// The ordered playlist of tracks.
  final List<PlaybackTrack> playlist;

  /// Current play mode.
  final PlayMode playMode;

  /// Volume level (0.0 - 1.0).
  final double volume;

  /// Whether audio is currently playing.
  final bool isPlaying;

  /// Current position.
  final Duration position;

  /// Total duration.
  final Duration duration;

  /// Lyrics data for the current track.
  final LyricsData? lyrics;

  /// Album art colors for liquid gradient.
  final List<int>? artColors;

  const PlaybackState({
    this.currentIndex = -1,
    this.playlist = const [],
    this.playMode = PlayMode.sequence,
    this.volume = 1.0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.lyrics,
    this.artColors,
  });

  PlaybackState copyWith({
    int? currentIndex,
    List<PlaybackTrack>? playlist,
    PlayMode? playMode,
    double? volume,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    LyricsData? lyrics,
    List<int>? artColors,
    bool clearLyrics = false,
    bool clearArtColors = false,
  }) {
    return PlaybackState(
      currentIndex: currentIndex ?? this.currentIndex,
      playlist: playlist ?? this.playlist,
      playMode: playMode ?? this.playMode,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      artColors: clearArtColors ? null : (artColors ?? this.artColors),
    );
  }

  /// Whether there's a track loaded.
  bool get hasTrack => currentIndex >= 0 && playlist.isNotEmpty;

  /// Get current track or null.
  PlaybackTrack? get currentTrack => hasTrack ? playlist[currentIndex] : null;

  /// Whether we can go to next track.
  bool get hasNext =>
      hasTrack &&
      (currentIndex < playlist.length - 1 ||
          playMode == PlayMode.loop ||
          playMode == PlayMode.shuffle);

  /// Whether we can go to previous track.
  bool get hasPrevious =>
      hasTrack &&
      (currentIndex > 0 ||
          playMode == PlayMode.loop ||
          playMode == PlayMode.shuffle);
}

/// A track in the playback queue with resolved file path.
class PlaybackTrack {
  final String id;
  final String name;
  final String artistName;
  final String albumName;
  final String? coverUrl;
  final String? localCoverPath;
  final String filePath;
  final String? quality;
  final int? durationMs;
  final String? streamUrl;
  final String? lyricsUrl; // Technically LRC string returned from backend

  const PlaybackTrack({
    required this.id,
    required this.name,
    required this.artistName,
    required this.albumName,
    this.coverUrl,
    this.localCoverPath,
    required this.filePath,
    this.quality,
    this.durationMs,
    this.streamUrl,
    this.lyricsUrl,
  });

  /// Get the cover art path (local file or network URL).
  String? get coverArtPath {
    if (localCoverPath != null && localCoverPath!.isNotEmpty) {
      return localCoverPath;
    }
    return coverUrl;
  }

  /// Get the cover art URI for media notification.
  String? get coverArtUri {
    final path = coverArtPath;
    if (path == null) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (File(path).existsSync()) {
      return 'file://$path';
    }
    return null;
  }
}

/// Controls audio playback with queue management, play modes, and lyrics.
class PlaybackController extends Notifier<PlaybackState> {
  AudioPlayerService? _audioService;
  Timer? _completionDebounce;
  final List<int> _originalOrder = [];
  final Random _random = Random();

  @override
  PlaybackState build() {
    // Initialize audio service lazily
    _initAudioService();
    return const PlaybackState();
  }

  Future<void> _initAudioService() async {
    if (_audioService != null) return;

    try {
      _audioService = await AudioPlayerService.init();
      _audioService!.onSongComplete = _onSongComplete;
      _audioService!.onPlaybackStateChanged = _onPlaybackStateChanged;

      // Load saved play mode
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getInt('playMode') ?? 2; // default: sequence
      state = state.copyWith(
        playMode:
            PlayMode.values[savedMode.clamp(0, PlayMode.values.length - 1)],
        volume: prefs.getDouble('playerVolume') ?? 1.0,
      );
    } catch (e) {
      _log.d('Failed to initialize audio service: $e');
    }
  }

  /// Play a single local file or stream URL.
  Future<void> playLocalPath({
    required String
    path, // This can also be interpreted as stream URL if streamUrl is provided
    required String title,
    required String artist,
    String album = '',
    String coverUrl = '',
    String? localCoverPath,
    String? quality,
    Track? track,
    String? streamUrl,
    String? lyricsUrl, // Can be LRC string or URL
  }) async {
    await _initAudioService();

    if (streamUrl == null && isCueVirtualPath(path)) {
      throw Exception(cueVirtualTrackRequiresSplitMessage);
    }

    final playbackTrack = PlaybackTrack(
      id: track?.id ?? path,
      name: title,
      artistName: artist,
      albumName: album,
      coverUrl: coverUrl,
      localCoverPath: localCoverPath,
      filePath: path, // We keep this as an identifier if streamUrl is passed
      quality: quality,
      streamUrl: streamUrl,
      lyricsUrl: lyricsUrl,
    );

    state = state.copyWith(
      playlist: [playbackTrack],
      currentIndex: 0,
      clearLyrics: true,
      clearArtColors: true,
    );

    await _playCurrentTrack();
  }

  /// Play a list of tracks starting at a specific index.
  Future<void> playTrackList(
    List<PlaybackTrack> tracks, {
    int startIndex = 0,
  }) async {
    if (tracks.isEmpty) return;
    await _initAudioService();

    final safeStart = startIndex.clamp(0, tracks.length - 1);

    _originalOrder.clear();
    for (int i = 0; i < tracks.length; i++) {
      _originalOrder.add(i);
    }

    List<PlaybackTrack> orderedTracks = List.from(tracks);
    int currentIdx = safeStart;

    if (state.playMode == PlayMode.shuffle) {
      orderedTracks = _shuffleWithCurrentFirst(tracks, safeStart);
      currentIdx = 0;
    }

    state = state.copyWith(
      playlist: orderedTracks,
      currentIndex: currentIdx,
      clearLyrics: true,
      clearArtColors: true,
    );

    await _playCurrentTrack();
  }

  /// Play a list of Track model objects.
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    final playbackTracks = <PlaybackTrack>[];
    for (final track in tracks) {
      final resolvedPath = await resolveTrackPath(track);
      if (resolvedPath == null) continue;
      if (isCueVirtualPath(resolvedPath)) continue;

      playbackTracks.add(
        PlaybackTrack(
          id: track.id,
          name: track.name,
          artistName: track.artistName,
          albumName: track.albumName,
          coverUrl: track.coverUrl,
          filePath: resolvedPath,
          durationMs: track.duration > 0 ? track.duration * 1000 : null,
        ),
      );
    }

    if (playbackTracks.isEmpty) {
      throw Exception('No local audio file is available to play.');
    }

    // Adjust start index if some tracks were filtered out
    final adjustedStart = startIndex.clamp(0, playbackTracks.length - 1);
    await playTrackList(playbackTracks, startIndex: adjustedStart);
  }

  Future<void> _playCurrentTrack() async {
    final track = state.currentTrack;
    if (track == null || _audioService == null) return;

    try {
      if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        await _audioService!.playUrl(
          track.streamUrl!,
          title: track.name,
          artist: track.artistName,
          album: track.albumName,
          artUri: track.coverArtUri,
          duration: track.durationMs != null
              ? Duration(milliseconds: track.durationMs!)
              : null,
        );
      } else {
        await _audioService!.playFile(
          track.filePath,
          title: track.name,
          artist: track.artistName,
          album: track.albumName,
          artUri: track.coverArtUri,
          duration: track.durationMs != null
              ? Duration(milliseconds: track.durationMs!)
              : null,
        );
      }

      // Try to load lyrics
      _loadLyricsForCurrentTrack(track);
    } catch (e) {
      _log.d('Error playing track: $e');
      rethrow;
    }
  }

  Future<void> _loadLyricsForCurrentTrack(PlaybackTrack track) async {
    // Helper to safely apply state only if the track is still playing
    bool applyLyrics(LyricsData lyrics, String source) {
      if (state.currentTrack?.id != track.id) {
        _log.d(
          'Lyrics: Ignored $source for ${track.name} since track changed.',
        );
        return false;
      }
      _log.d('Lyrics: Loaded ${lyrics.lines.length} lines from $source');
      state = state.copyWith(lyrics: lyrics);
      return true;
    }

    // 0. If it's a stream and lyrics were provided directly from the backend
    if (track.lyricsUrl != null && track.lyricsUrl!.isNotEmpty) {
      _log.d('Lyrics: Parsing direct LRC string from stream metadata');
      try {
        final lyrics = await LyricsParser.parse(track.lyricsUrl!);
        if (lyrics.lines.isNotEmpty) {
          if (applyLyrics(lyrics, 'direct stream metadata')) return;
        }
      } catch (e) {
        _log.d('Lyrics: Error parsing direct stream lyrics: $e');
      }
    }

    final filePath = track.filePath;

    // Only attempt local file checks if there's actually a downloaded file or valid path
    // Skip for Android SAF content:// URIs — Dart's File class cannot access them
    final isContentUri = filePath.startsWith('content://');
    if (filePath.isNotEmpty && !isContentUri) {
      final fileExists = await File(filePath).exists();

      // 1. Try to read embedded lyrics completely offline FIRST
      if (fileExists) {
        try {
          _log.d('Lyrics: Checking for embedded lyrics via readFileMetadata');
          final metadataInfo = await PlatformBridge.readFileMetadata(filePath);
          final metadata = Map<String, String>.from(
            metadataInfo['metadata'] ?? {},
          );
          final embeddedLyrics =
              (metadata['LYRICS'] ?? metadata['UNSYNCEDLYRICS'] ?? '').trim();

          if (embeddedLyrics.isNotEmpty) {
            final lyrics = await LyricsParser.parse(embeddedLyrics);
            if (lyrics.lines.isNotEmpty) {
              if (applyLyrics(lyrics, 'embedded metadata')) return;
            }
          }
        } catch (e) {
          _log.d('Lyrics: Failed to check embedded lyrics: $e');
        }
      }

      // 2. Try sidecar .lrc and .ttml files (fast, no network)
      final dotIndex = filePath.lastIndexOf('.');
      if (dotIndex > 0) {
        final basePath = filePath.substring(0, dotIndex);
        for (final ext in ['.lrc', '.ttml']) {
          final lrcPath = '$basePath$ext';
          _log.d('Lyrics: Checking sidecar file: $lrcPath');
          final fileExists = await File(lrcPath).exists();
          _log.d('Lyrics: Sidecar exists? $fileExists');
          if (fileExists) {
            try {
              final content = await File(lrcPath).readAsString();
              final lyrics = await LyricsParser.parse(content);
              if (lyrics.lines.isNotEmpty) {
                if (applyLyrics(lyrics, 'local $ext file')) return;
              } else {
                _log.d('Lyrics: Sidecar $ext was empty or parsing failed');
              }
            } catch (e) {
              _log.d('Lyrics: Error parsing $ext: $e');
            }
          }
        }
      } else {
        _log.d('Lyrics: File path has no extension, skipping sidecar check: $filePath');
      }
    } // End of local specific checks

    // 3. Use Go backend getLyricsLRC (Network fallback if missing)
    // This MUST run for BOTH streams and local files if previous steps failed
    try {
      if (state.currentTrack?.id != track.id) {
        return; // Quick bail before network
      }

      _log.d('Lyrics: Fetching via getLyricsLRC for: ${track.name}');
      final lrcContent = await PlatformBridge.getLyricsLRC(
        track.id,
        track.name,
        track.artistName,
        filePath: track.filePath,
        durationMs: track.durationMs ?? 0,
      );
      if (lrcContent.isNotEmpty) {
        final lyrics = await LyricsParser.parse(lrcContent);
        if (lyrics.lines.isNotEmpty) {
          if (applyLyrics(lyrics, 'getLyricsLRC (online fallback)')) return;
        }
      }
    } catch (e) {
      _log.d('Lyrics: getLyricsLRC failed: $e');
    }

    if (state.currentTrack?.id == track.id) {
      _log.d('Lyrics: No lyrics found for: ${track.name}');
    }
  }

  /// Toggle between play and pause.
  void togglePlay() {
    _audioService?.togglePlayPause();
  }

  /// Play next track.
  Future<void> next() async {
    if (!state.hasTrack) return;

    int nextIndex;
    switch (state.playMode) {
      case PlayMode.single:
      case PlayMode.singleLoop:
        nextIndex = state.currentIndex;
        break;
      case PlayMode.shuffle:
      case PlayMode.loop:
        nextIndex = (state.currentIndex + 1) % state.playlist.length;
        break;
      case PlayMode.sequence:
        nextIndex = state.currentIndex + 1;
        if (nextIndex >= state.playlist.length) return; // End of list
        break;
    }

    state = state.copyWith(currentIndex: nextIndex, clearLyrics: true);
    await _playCurrentTrack();
  }

  /// Play previous track.
  Future<void> previous() async {
    if (!state.hasTrack) return;

    // If more than 3 seconds in, restart current track
    if (state.position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }

    int prevIndex;
    switch (state.playMode) {
      case PlayMode.single:
      case PlayMode.singleLoop:
        prevIndex = state.currentIndex;
        break;
      case PlayMode.shuffle:
      case PlayMode.loop:
        prevIndex =
            (state.currentIndex - 1 + state.playlist.length) %
            state.playlist.length;
        break;
      case PlayMode.sequence:
        prevIndex = state.currentIndex - 1;
        if (prevIndex < 0) return;
        break;
    }

    state = state.copyWith(currentIndex: prevIndex, clearLyrics: true);
    await _playCurrentTrack();
  }

  /// Seek to a specific position.
  Future<void> seekTo(Duration position) async {
    await _audioService?.seek(position);
  }

  /// Set the play mode.
  Future<void> setPlayMode(PlayMode mode) async {
    state = state.copyWith(playMode: mode);

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('playMode', mode.index);

    // If switching to/from shuffle, reorder playlist
    if (mode == PlayMode.shuffle && state.hasTrack) {
      final shuffled = _shuffleWithCurrentFirst(
        state.playlist,
        state.currentIndex,
      );
      state = state.copyWith(playlist: shuffled, currentIndex: 0);
    }
  }

  /// Set volume (0.0 - 1.0).
  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _audioService?.setVolume(clamped);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('playerVolume', clamped);
  }

  /// Jump to a specific track in the playlist by index.
  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= state.playlist.length) return;
    state = state.copyWith(currentIndex: index, clearLyrics: true);
    await _playCurrentTrack();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.playlist.length) return;
    if (index == state.currentIndex) return; // Don't remove the current track

    final newPlaylist = List<PlaybackTrack>.from(state.playlist)
      ..removeAt(index);
    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    }
    state = state.copyWith(playlist: newPlaylist, currentIndex: newIndex);
  }

  /// Reorder tracks in the queue.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.playlist.length) return;
    if (newIndex < 0 || newIndex > state.playlist.length) return;

    // Adjust newIndex for ReorderableListView's logic when moving down
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final newPlaylist = List<PlaybackTrack>.from(state.playlist);
    final item = newPlaylist.removeAt(oldIndex);
    newPlaylist.insert(newIndex, item);

    // Track the currently playing item
    int newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex &&
        newIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex &&
        newIndex <= state.currentIndex) {
      newCurrentIndex++;
    }

    state = state.copyWith(
      playlist: newPlaylist,
      currentIndex: newCurrentIndex,
    );
  }

  /// Clear all upcoming tracks from the queue (keeps past and current).
  void clearUpcomingQueue() {
    if (state.playlist.isEmpty) return;

    final newPlaylist = state.playlist.sublist(0, state.currentIndex + 1);

    state = state.copyWith(
      playlist: newPlaylist,
      // currentIndex remains the same since we only removed items after it
    );
  }

  /// Stop playback and clear the queue.
  Future<void> stopPlayback() async {
    await _audioService?.stop();
    state = const PlaybackState();
  }

  /// The position ValueNotifier for efficient UI binding.
  ValueNotifier<Duration> get positionNotifier =>
      _audioService?.position ?? ValueNotifier(Duration.zero);

  void _onSongComplete() {
    _completionDebounce?.cancel();
    _completionDebounce = Timer(const Duration(milliseconds: 300), () {
      _handleSongCompletion();
    });
  }

  Future<void> _handleSongCompletion() async {
    switch (state.playMode) {
      case PlayMode.single:
        // Stop after current track
        break;
      case PlayMode.singleLoop:
        await seekTo(Duration.zero);
        _audioService?.play();
        break;
      case PlayMode.sequence:
        if (state.currentIndex < state.playlist.length - 1) {
          await next();
        }
        break;
      case PlayMode.loop:
      case PlayMode.shuffle:
        await next();
        break;
    }
  }

  void _onPlaybackStateChanged() {
    if (_audioService == null) return;
    state = state.copyWith(
      isPlaying: _audioService!.isPlaying,
      duration: _audioService!.duration,
    );
  }

  List<PlaybackTrack> _shuffleWithCurrentFirst(
    List<PlaybackTrack> tracks,
    int currentIndex,
  ) {
    final current = tracks[currentIndex];
    final others = List<PlaybackTrack>.from(tracks)..removeAt(currentIndex);
    others.shuffle(_random);
    return [current, ...others];
  }

  // --- Track resolution (reused from original PlaybackController) ---

  Future<String?> resolveTrackPath(Track track) async {
    final localState = ref.read(localLibraryProvider);
    final historyState = ref.read(downloadHistoryProvider);
    final historyNotifier = ref.read(downloadHistoryProvider.notifier);

    final localItem = _findLocalLibraryItemForTrack(track, localState);
    if (localItem != null && await fileExists(localItem.filePath)) {
      return localItem.filePath;
    }

    final historyItem = _findDownloadHistoryItemForTrack(track, historyState);
    if (historyItem != null) {
      if (await fileExists(historyItem.filePath)) {
        return historyItem.filePath;
      }
      historyNotifier.removeFromHistory(historyItem.id);
    }

    return null;
  }

  LocalLibraryItem? _findLocalLibraryItemForTrack(
    Track track,
    LocalLibraryState localState,
  ) {
    final isLocalSource = (track.source ?? '').toLowerCase() == 'local';
    if (isLocalSource) {
      for (final item in localState.items) {
        if (item.id == track.id) return item;
      }
    }

    final isrc = track.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = localState.getByIsrc(isrc);
      if (byIsrc != null) return byIsrc;
    }

    return localState.findByTrackAndArtist(track.name, track.artistName);
  }

  DownloadHistoryItem? _findDownloadHistoryItemForTrack(
    Track track,
    DownloadHistoryState historyState,
  ) {
    for (final candidateId in _spotifyIdLookupCandidates(track.id)) {
      final bySpotifyId = historyState.getBySpotifyId(candidateId);
      if (bySpotifyId != null) return bySpotifyId;
    }

    final isrc = track.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = historyState.getByIsrc(isrc);
      if (byIsrc != null) return byIsrc;
    }

    return historyState.findByTrackAndArtist(track.name, track.artistName);
  }

  List<String> _spotifyIdLookupCandidates(String rawId) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>{trimmed};
    final lowered = trimmed.toLowerCase();
    if (lowered.startsWith('spotify:track:')) {
      final compact = trimmed.split(':').last.trim();
      if (compact.isNotEmpty) candidates.add(compact);
    } else if (!trimmed.contains(':')) {
      candidates.add('spotify:track:$trimmed');
    }

    final uri = Uri.tryParse(trimmed);
    final segments = uri?.pathSegments ?? const <String>[];
    final trackIndex = segments.indexOf('track');
    if (trackIndex >= 0 && trackIndex + 1 < segments.length) {
      final pathId = segments[trackIndex + 1].trim();
      if (pathId.isNotEmpty) {
        candidates.add(pathId);
        candidates.add('spotify:track:$pathId');
      }
    }

    return candidates.toList(growable: false);
  }
}

final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);
