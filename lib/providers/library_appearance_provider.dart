import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_styles.dart';

const _kLibraryStyleKey = 'pref_library_style';

class LibraryAppearanceState {
  final LibraryStyle libraryStyle;

  const LibraryAppearanceState({
    this.libraryStyle = LibraryStyle.defaultStyle,
  });

  LibraryAppearanceState copyWith({
    LibraryStyle? libraryStyle,
  }) {
    return LibraryAppearanceState(
      libraryStyle: libraryStyle ?? this.libraryStyle,
    );
  }
}

class LibraryAppearanceNotifier extends Notifier<LibraryAppearanceState> {
  @override
  LibraryAppearanceState build() {
    _loadSettings();
    return const LibraryAppearanceState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final styleId = prefs.getString(_kLibraryStyleKey);

    state = LibraryAppearanceState(
      libraryStyle: styleId != null
          ? LibraryStyle.fromString(styleId)
          : LibraryStyle.defaultStyle,
    );
  }

  Future<void> setLibraryStyle(LibraryStyle style) async {
    state = state.copyWith(libraryStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLibraryStyleKey, style.id);
  }
}

final libraryAppearanceProvider =
    NotifierProvider<LibraryAppearanceNotifier, LibraryAppearanceState>(() {
  return LibraryAppearanceNotifier();
});
