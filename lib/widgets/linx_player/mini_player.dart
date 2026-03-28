import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/player_styles.dart';
import '../../providers/player_appearance_provider.dart';
import 'styles/mini/style_1_mini_player.dart';
import 'styles/mini/style_2_mini_player.dart';
import 'styles/mini/style_3_mini_player.dart';
import 'styles/mini/style_4_mini_player.dart';
import 'styles/mini/style_5_mini_player.dart';
import 'styles/mini/style_6_mini_player.dart';

/// Compact mini player shown at the bottom of the app.
/// Acts as a router to the currently selected Mini Player style.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(playerAppearanceProvider);

    switch (appearance.miniPlayerStyle) {
      case MiniPlayerStyle.defaultStyle:
        return const Style1MiniPlayer();
      case MiniPlayerStyle.spotify:
        return const Style2MiniPlayer();
      case MiniPlayerStyle.appleMusic:
        return const Style3MiniPlayer();
      case MiniPlayerStyle.soundCloud:
        return const Style4MiniPlayer();
      case MiniPlayerStyle.deezer:
        return const Style5MiniPlayer();
      case MiniPlayerStyle.tidal:
        return const Style6MiniPlayer();
    }
  }
}
