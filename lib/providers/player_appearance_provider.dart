import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_styles.dart';

const _kMiniPlayerStyleKey = 'pref_mini_player_style';
const _kNowPlayingStyleKey = 'pref_now_playing_style';
const _kAmoledBackgroundKey = 'pref_amoled_background';

class PlayerAppearanceState {
  final MiniPlayerStyle miniPlayerStyle;
  final NowPlayingStyle nowPlayingStyle;

  /// Whether to force a pure AMOLED black background globally
  final bool useAmoledBackground;

  const PlayerAppearanceState({
    this.miniPlayerStyle = MiniPlayerStyle.defaultStyle,
    this.nowPlayingStyle = NowPlayingStyle.defaultStyle,
    this.useAmoledBackground = false,
  });

  PlayerAppearanceState copyWith({
    MiniPlayerStyle? miniPlayerStyle,
    NowPlayingStyle? nowPlayingStyle,
    bool? useAmoledBackground,
  }) {
    return PlayerAppearanceState(
      miniPlayerStyle: miniPlayerStyle ?? this.miniPlayerStyle,
      nowPlayingStyle: nowPlayingStyle ?? this.nowPlayingStyle,
      useAmoledBackground: useAmoledBackground ?? this.useAmoledBackground,
    );
  }
}

class PlayerAppearanceNotifier extends Notifier<PlayerAppearanceState> {
  @override
  PlayerAppearanceState build() {
    // Initiate async load, but return default state immediately
    _loadSettings();
    return const PlayerAppearanceState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final miniStyleId = prefs.getString(_kMiniPlayerStyleKey);
    final npStyleId = prefs.getString(_kNowPlayingStyleKey);
    final useAmoled = prefs.getBool(_kAmoledBackgroundKey);

    state = PlayerAppearanceState(
      miniPlayerStyle: miniStyleId != null
          ? MiniPlayerStyle.fromString(miniStyleId)
          : MiniPlayerStyle.defaultStyle,
      nowPlayingStyle: npStyleId != null
          ? NowPlayingStyle.fromString(npStyleId)
          : NowPlayingStyle.defaultStyle,
      useAmoledBackground: useAmoled ?? false,
    );
  }

  Future<void> setMiniPlayerStyle(MiniPlayerStyle style) async {
    state = state.copyWith(miniPlayerStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMiniPlayerStyleKey, style.id);
  }

  Future<void> setNowPlayingStyle(NowPlayingStyle style) async {
    state = state.copyWith(nowPlayingStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNowPlayingStyleKey, style.id);
  }

  /// Update and persist the AMOLED background preference
  Future<void> setAmoledBackground(bool useAmoled) async {
    state = state.copyWith(useAmoledBackground: useAmoled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAmoledBackgroundKey, useAmoled);
  }
}

final playerAppearanceProvider =
    NotifierProvider<PlayerAppearanceNotifier, PlayerAppearanceState>(() {
      return PlayerAppearanceNotifier();
    });
