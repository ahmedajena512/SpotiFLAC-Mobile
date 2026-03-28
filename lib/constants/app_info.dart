
/// App version and info constants
/// Update version here only - all other files will reference this
class AppInfo {
  static const String version = '3.8.8';
  static const String buildNumber = '113';
  static const String fullVersion = '$version+$buildNumber';

  /// Shows actual version instead of "Internal" in debug builds
  static String get displayVersion => version;

  static const String appName = 'SpotiFLAC';
  static const String copyright = '© 2026 SpotiFLAC';

  static const String mobileAuthor = 'zarzet';
  static const String originalAuthor = 'afkarxyz';

  static const String githubRepo = 'zarzet/SpotiFLAC-Mobile';
  static const String githubUrl = 'https://github.com/$githubRepo';
  static const String originalGithubUrl =
      'https://github.com/afkarxyz/SpotiFLAC';

  static const String kofiUrl = 'https://ko-fi.com/zarzet';
  static const String githubSponsorsUrl = 'https://github.com/sponsors/zarzet/';
}
