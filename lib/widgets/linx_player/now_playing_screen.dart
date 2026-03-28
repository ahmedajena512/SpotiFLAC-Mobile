import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_appearance_provider.dart';
import '../../models/player_styles.dart';
import '../../utils/player_transition_route.dart';
import 'styles/now_playing/style_1_now_playing.dart';
import 'styles/now_playing/style_2_now_playing.dart';
import 'styles/now_playing/style_3_now_playing.dart';
import 'styles/now_playing/style_4_now_playing.dart';
import 'styles/now_playing/style_5_now_playing.dart';
import 'styles/now_playing/style_6_now_playing.dart';

/// Full-screen player router. Chooses the correct style.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(playerAppearanceProvider);

    switch (appearance.nowPlayingStyle) {
      case NowPlayingStyle.defaultStyle:
        return const Style1NowPlaying();
      case NowPlayingStyle.spotify:
        return const Style2NowPlaying();
      case NowPlayingStyle.appleMusic:
        return const Style3NowPlaying();
      case NowPlayingStyle.soundCloud:
        return const Style4NowPlaying();
      case NowPlayingStyle.deezer:
        return const Style5NowPlaying();
      case NowPlayingStyle.tidal:
        return const Style6NowPlaying();
    }
  }
}

/// Helper method to open the Now Playing screen globally.
void openNowPlayingScreen(BuildContext context) {
  Navigator.of(
    context,
  ).push(PlayerTransitionRoute(page: const NowPlayingScreen()));
}
