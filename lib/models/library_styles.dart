enum LibraryStyle {
  defaultStyle('default', 'Default'),
  spotifyStyle('spotify', 'Spotify'),
  appleMusicStyle('apple_music', 'Apple Music');

  final String id;
  final String displayName;

  const LibraryStyle(this.id, this.displayName);

  static LibraryStyle fromString(String id) {
    return values.firstWhere(
      (style) => style.id == id,
      orElse: () => LibraryStyle.defaultStyle,
    );
  }
}
