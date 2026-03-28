import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/logger.dart';

final _log = AppLogger('AudioPlayerService');

/// Core audio playback service using just_audio for audio engine
/// and audio_service for background playback / lock screen controls.
///
/// just_audio uses native AVFoundation on iOS (works on simulator + real device)
/// and ExoPlayer on Android. Supports FLAC, MP3, AAC, OGG, WAV, etc.
class AudioPlayerService extends BaseAudioHandler with SeekHandler {
  static AudioPlayerService? _instance;

  /// The underlying just_audio player.
  late final AudioPlayer _player;

  /// Current playback position as a ValueNotifier for efficient UI updates.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  /// Current duration.
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  /// Whether audio is currently playing.
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Stream subscriptions for cleanup.
  final List<StreamSubscription> _subscriptions = [];

  /// Callback when current song completes.
  VoidCallback? onSongComplete;

  /// Callback when playback state changes.
  VoidCallback? onPlaybackStateChanged;

  AudioPlayerService._();

  /// Initialize and return the singleton service.
  static Future<AudioPlayerService> init() async {
    if (_instance != null) return _instance!;

    final service = AudioPlayerService._();
    service._player = AudioPlayer();

    // Configure audio session for music playback
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );

      // Handle audio interruptions (phone calls, other apps)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              service._player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (service._isPlaying) {
                service.pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              service._player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Don't auto-resume after interruption
              break;
          }
        }
      });

      // Handle becoming noisy (headphones unplugged)
      session.becomingNoisyEventStream.listen((_) {
        if (service._isPlaying) {
          service.pause();
        }
      });
    } catch (e) {
      _log.d('Audio session configuration failed: $e');
    }

    // Listen to player position updates
    service._subscriptions.add(
      service._player.positionStream.listen((pos) {
        service.position.value = pos;
      }),
    );

    // Listen to duration changes
    service._subscriptions.add(
      service._player.durationStream.listen((dur) {
        if (dur != null) {
          _log.d('Duration changed: $dur');
          service._duration = dur;
          service.onPlaybackStateChanged?.call();
        }
      }),
    );

    // Listen to playing state
    service._subscriptions.add(
      service._player.playingStream.listen((playing) {
        _log.d('Playing state changed: $playing');
        service._isPlaying = playing;
        service._updatePlaybackState();
        service.onPlaybackStateChanged?.call();
      }),
    );

    // Listen for processing state (to detect song completion)
    service._subscriptions.add(
      service._player.processingStateStream.listen((processingState) {
        if (processingState == ProcessingState.completed) {
          _log.d('Song completed');
          service.onSongComplete?.call();
        }
      }),
    );

    // Listen for player errors
    service._subscriptions.add(
      service._player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          _log.d('⚠️ Player ERROR: $e');
        },
      ),
    );

    // Register as audio_service handler for lock screen controls
    try {
      _instance = await AudioService.init(
        builder: () => service,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.zarz.spotiflac.audio',
          androidNotificationChannelName: 'SpotiFLAC Music',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e) {
      _log.d('AudioService init failed (may already be initialized): $e');
      _instance = service;
    }

    return _instance!;
  }

  /// Get the current singleton instance.
  static AudioPlayerService get instance {
    assert(_instance != null, 'AudioPlayerService.init() must be called first');
    return _instance!;
  }

  /// Play an audio stream from a URL.
  Future<void> playUrl(
    String url, {
    String? title,
    String? artist,
    String? album,
    String? artUri,
    Duration? duration,
  }) async {
    _log.d('▶ playUrl called with: $url');

    try {
      _log.d('  Setting audio source url...');

      final mediaItemTag = MediaItem(
        id: url,
        title: title ?? 'Unknown Title',
        artist: artist ?? 'Unknown Artist',
        album: album ?? 'Unknown Album',
        duration: duration, // wait for metadata if null
        artUri: artUri != null ? Uri.tryParse(artUri) : null,
      );

      // Use LockCachingAudioSource for robust streaming on iOS/AVPlayer
      final source = LockCachingAudioSource(Uri.parse(url), tag: mediaItemTag);

      await _player.setAudioSource(source);
      _log.d('  Audio source set, calling play()...');
      await _player.play();
      _log.d('  play() called, player.playing=${_player.playing}');
      _log.d('  player.duration=${_player.duration}');

      // Update media notification metadata
      mediaItem.add(mediaItemTag);
      _log.d('  MediaItem updated for notification');

      _updatePlaybackState();
    } catch (e) {
      _log.e('Failed to play URL: $e');
    }
  }

  /// Play a local audio file or content URI.
  Future<void> playFile(
    String filePath, {
    String? title,
    String? artist,
    String? album,
    String? artUri,
    Duration? duration,
  }) async {
    _log.d('▶ playFile called with: $filePath');

    // Android SAF uses content:// URIs which Dart's File class cannot handle.
    // just_audio's ExoPlayer backend natively supports content:// URIs via
    // AudioSource.uri(), so we route those through that path instead.
    final isContentUri = filePath.startsWith('content://');

    if (!isContentUri) {
      // Regular filesystem path — check existence
      final file = File(filePath);
      final exists = await file.exists();
      _log.d('  File exists: $exists');
      if (!exists) {
        _log.d('  ❌ FILE NOT FOUND: $filePath');
        return;
      }
    } else {
      _log.d('  📂 Content URI detected, using URI-based source');
    }

    try {
      _log.d('  Setting audio source...');
      if (isContentUri) {
        // ExoPlayer on Android natively supports content:// URIs
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(filePath)),
        );
      } else {
        // Regular file path (iOS, desktop, etc.)
        await _player.setFilePath(filePath);
      }
      _log.d('  Audio source set, calling play()...');
      await _player.play();
      _log.d('  play() called, player.playing=${_player.playing}');
      _log.d('  player.duration=${_player.duration}');

      // Update media notification metadata
      mediaItem.add(
        MediaItem(
          id: filePath,
          title: title ?? _extractFileName(filePath),
          artist: artist ?? 'Unknown Artist',
          album: album ?? 'Unknown Album',
          duration: duration ?? _player.duration,
          artUri: artUri != null ? Uri.tryParse(artUri) : null,
        ),
      );
      _log.d('  MediaItem updated for notification');
    } catch (e, stack) {
      _log.d('  ❌ Error playing file: $e');
      _log.d('  Stack: $stack');
      rethrow;
    }
  }

  /// Update MediaItem metadata (e.g., when lyrics or art become available).
  Future<void> updateMetadata({
    String? title,
    String? artist,
    String? album,
    String? artUri,
    Duration? duration,
  }) async {
    final current = mediaItem.valueOrNull;
    if (current == null) return;

    mediaItem.add(
      current.copyWith(
        title: title ?? current.title,
        artist: artist ?? current.artist,
        album: album ?? current.album,
        duration: duration ?? current.duration,
        artUri: artUri != null ? Uri.tryParse(artUri) : current.artUri,
      ),
    );
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  /// Toggle between play and pause.
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    // Handled externally by PlaybackController
  }

  @override
  Future<void> skipToPrevious() async {
    // Handled externally by PlaybackController
  }

  /// Set volume (0.0 to 1.0).
  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    await _player.setVolume(clamped);
  }

  /// Get current volume (0.0 to 1.0).
  double get volume => _player.volume;

  /// Jump forward by duration.
  Future<void> jumpForward(Duration offset) async {
    final newPos = position.value + offset;
    final clamped = newPos > _duration ? _duration : newPos;
    await seek(clamped);
  }

  /// Jump backward by duration.
  Future<void> jumpBackward(Duration offset) async {
    final newPos = position.value - offset;
    final clamped = newPos < Duration.zero ? Duration.zero : newPos;
    await seek(clamped);
  }

  void _updatePlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: _isPlaying,
        updatePosition: position.value,
      ),
    );
  }

  String _extractFileName(String path) {
    final name = path.split('/').last.split('\\').last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  /// Dispose the service.
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    _instance = null;
  }
}
