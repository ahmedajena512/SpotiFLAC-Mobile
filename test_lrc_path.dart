void main() {
  final path = '/storage/sdcard0/Music/track.m4a';
  final dotIndex = path.lastIndexOf('.');
  final basePath = path.substring(0, dotIndex);
  // ignore: avoid_print
  print('$basePath.lrc');
}
