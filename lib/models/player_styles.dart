/// Represents the available styles for the Mini Player component
enum MiniPlayerStyle {
  /// Style 1: Default - SpotiFLAC Gradient
  defaultStyle('style_1_default'),

  /// Style 2: Spotify - Dark flat bar
  spotify('style_2_spotify'),

  /// Style 3: Apple Music - Glassmorphic hovering pill
  appleMusic('style_3_apple'),

  /// Style 4: SoundCloud - Circular Progress Ring with Cover insight
  soundCloud('style_4_soundcloud'),

  /// Style 5: Deezer - Vibrant minimalist
  deezer('style_5_deezer'),

  /// Style 6: Tidal - Ultra minimalist hi-fi
  tidal('style_6_tidal');

  final String id;
  const MiniPlayerStyle(this.id);

  static MiniPlayerStyle fromString(String id) {
    return MiniPlayerStyle.values.firstWhere(
      (style) => style.id == id,
      orElse: () => MiniPlayerStyle.defaultStyle,
    );
  }

  String get displayName {
    switch (this) {
      case MiniPlayerStyle.defaultStyle:
        return 'SpotiFLAC (Default)';
      case MiniPlayerStyle.spotify:
        return 'Spotify';
      case MiniPlayerStyle.appleMusic:
        return 'Apple Music (Glass)';
      case MiniPlayerStyle.soundCloud:
        return 'SoundCloud (Ring)';
      case MiniPlayerStyle.deezer:
        return 'Deezer';
      case MiniPlayerStyle.tidal:
        return 'Tidal (Minimal)';
    }
  }

  bool get usesAlbumColors {
    switch (this) {
      case MiniPlayerStyle.defaultStyle:
      case MiniPlayerStyle.appleMusic:
      case MiniPlayerStyle.deezer:
        return true;
      case MiniPlayerStyle.spotify:
      case MiniPlayerStyle.soundCloud:
      case MiniPlayerStyle.tidal:
        return false;
    }
  }
}

/// Represents the available styles for the Now Playing screen
enum NowPlayingStyle {
  /// Style 1: Default - SpotiFLAC full-screen gradient
  defaultStyle('np_style_1_default'),

  /// Style 2: Spotify - Flat solid gradient, canvas focus
  spotify('np_style_2_spotify'),

  /// Style 3: Apple Music - Immersive blur, heavy shadow cover
  appleMusic('np_style_3_apple'),

  /// Style 4: SoundCloud - Huge waveform visualizer dominant
  soundCloud('np_style_4_soundcloud'),

  /// Style 5: Deezer - Bright glassmorphism and synced lyrics
  deezer('np_style_5_deezer'),

  /// Style 6: Tidal - Pure black, audiophile minimalist focus
  tidal('np_style_6_tidal');

  final String id;
  const NowPlayingStyle(this.id);

  static NowPlayingStyle fromString(String id) {
    return NowPlayingStyle.values.firstWhere(
      (style) => style.id == id,
      orElse: () => NowPlayingStyle.defaultStyle,
    );
  }

  String get displayName {
    switch (this) {
      case NowPlayingStyle.defaultStyle:
        return 'SpotiFLAC (Default)';
      case NowPlayingStyle.spotify:
        return 'Spotify';
      case NowPlayingStyle.appleMusic:
        return 'Apple Music (Blur)';
      case NowPlayingStyle.soundCloud:
        return 'SoundCloud (Wave)';
      case NowPlayingStyle.deezer:
        return 'Deezer';
      case NowPlayingStyle.tidal:
        return 'Tidal (Minimal)';
    }
  }

  bool get usesAlbumColors {
    switch (this) {
      case NowPlayingStyle.defaultStyle:
      case NowPlayingStyle.spotify:
      case NowPlayingStyle.appleMusic:
      case NowPlayingStyle.deezer:
        return true;
      case NowPlayingStyle.soundCloud:
      case NowPlayingStyle.tidal:
        return false;
    }
  }
}
