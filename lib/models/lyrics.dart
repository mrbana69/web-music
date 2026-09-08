class LyricLine {
  final int timestampMs;
  final String text;

  LyricLine({required this.timestampMs, required this.text});
}

class Lyrics {
  final String plainText;
  final List<LyricLine> syncedLines;
  final String? translation;
  final bool isSynced;

  Lyrics({
    required this.plainText,
    this.syncedLines = const [],
    this.translation,
    required this.isSynced,
  });

  factory Lyrics.parse({required String rawLrc, String? translationText}) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final rawLines = rawLrc.split('\n');

    for (final line in rawLines) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
        final text = match.group(4)!.trim();
        final totalMs = (min * 60 + sec) * 1000 + ms;
        lines.add(LyricLine(timestampMs: totalMs, text: text));
      }
    }

    lines.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    final isSync = lines.isNotEmpty;
    final plain = isSync
        ? lines.map((l) => l.text).where((t) => t.isNotEmpty).join('\n')
        : rawLrc;

    return Lyrics(
      plainText: plain,
      syncedLines: lines,
      translation: translationText,
      isSynced: isSync,
    );
  }

  int findActiveIndex(int currentMs) {
    if (!isSynced || syncedLines.isEmpty) return -1;
    for (int i = syncedLines.length - 1; i >= 0; i--) {
      if (currentMs >= syncedLines[i].timestampMs) {
        return i;
      }
    }
    return 0;
  }
}
