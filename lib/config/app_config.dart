class AppConfig {
  static const String appName = 'Preluded';
  static const String appVersion = '2.0.0';
  static const String appCommit = '098579a';
  static const String buildTime = '08/09/2026, 17:00';

  // Default Backend URL on Vercel
  static const String defaultBaseUrl = 'https://web-music-pi.vercel.app';

  static String formatArtwork(String? rawUrl, {String size = '500x500'}) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return 'https://resources.tidal.com/images/default/500x500.jpg';
    }
    String str = rawUrl.trim();
    if (str.contains('googleusercontent.com') || str.contains('ggpht.com')) {
      str = str.replaceAll(RegExp(r'=[ws]\d+.*$'), '=w500-h500-l90-rj');
      if (!str.contains('=w500-h500-l90-rj') && !str.contains('=')) {
        str += '=w500-h500-l90-rj';
      }
      return str;
    }
    if (str.contains('i.ytimg.com')) {
      return str
          .replaceAll('/default.jpg', '/hqdefault.jpg')
          .replaceAll('/mqdefault.jpg', '/hqdefault.jpg')
          .replaceAll('/maxresdefault.jpg', '/hqdefault.jpg');
    }
    if (str.startsWith('http://') || str.startsWith('https://') || str.startsWith('data:')) {
      return str;
    }
    return 'https://resources.tidal.com/images/' + str.replaceAll('-', '/') + '/' + size + '.jpg';
  }

  static String sanitizeArtist(dynamic raw) {
    if (raw == null) return 'Unknown Artist';
    String name = raw is String ? raw : (raw['name'] ?? '');
    if (name.isEmpty) return 'Unknown Artist';
    String clean = name.trim();
    clean = clean.replaceAll(RegExp(r'\s*-\s*Topic\b', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'Topic$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*VEVO\b', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'VEVO$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*Official(?:\s*Channel|\s*Artist\s*Channel)?\b', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*-\s*Official$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*Records\b', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isEmpty ? 'Artist' : clean;
  }
}
