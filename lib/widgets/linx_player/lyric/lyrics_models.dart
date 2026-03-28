import 'dart:convert';
import 'dart:typed_data';

/// Top-level lyrics container with version, lines, and optional metadata.
class LyricsData {
  final int version;
  final List<LyricLine> lines;
  final Map<String, dynamic>? metadata;

  static const int currentVersion = 1;

  LyricsData({
    this.version = currentVersion,
    required this.lines,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'lines': lines.map((l) => l.toJson()).toList(),
    'metadata': metadata,
  };

  factory LyricsData.fromJson(Map<String, dynamic> json) {
    final int version = (json['version'] as num?)?.toInt() ?? 0;
    switch (version) {
      case 0:
      case 1:
        return LyricsData(
          version: 1,
          lines: (json['lines'] as List)
              .map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
              .toList(),
          metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
        );
      default:
        throw UnsupportedError('Unsupported LyricsData version: $version');
    }
  }

  Uint8List toBlob() {
    final jsonString = jsonEncode(toJson());
    return utf8.encode(jsonString);
  }

  factory LyricsData.fromBlob(Uint8List blob) {
    final jsonString = utf8.decode(blob);
    return LyricsData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  LyricLine? getLineAt(Duration position) {
    if (lines.isEmpty) return null;
    try {
      return lines.firstWhere(
        (line) => position >= line.startTime && position <= line.endTime,
      );
    } catch (_) {
      return null;
    }
  }

  int getLineIndexByProgress(Duration position) {
    if (lines.isEmpty) return 0;
    final index = lines.lastIndexWhere((line) => position >= line.startTime);
    return index == -1 ? 0 : index;
  }
}

/// A single lyric line with word-level timing spans and optional translations.
class LyricLine {
  final List<LyricSpan> spans;
  final Duration startTime;
  final Duration endTime;
  final Map<String, String>? translations;

  LyricLine({
    required this.spans,
    required this.startTime,
    required this.endTime,
    this.translations,
  });

  Map<String, dynamic> toJson() => {
    'spans': spans.map((s) => s.toJson()).toList(),
    'startTime': startTime.inMilliseconds,
    'endTime': endTime.inMilliseconds,
    'translations': translations,
  };

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      spans: (json['spans'] as List)
          .map((e) => LyricSpan.fromJson(e as Map<String, dynamic>))
          .toList(),
      startTime: Duration(milliseconds: (json['startTime'] as num).toInt()),
      endTime: Duration(milliseconds: (json['endTime'] as num).toInt()),
      translations: (json['translations'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }

  LyricSpan? getSpanAt(Duration position) {
    if (spans.isEmpty) return null;
    try {
      return spans.firstWhere(
        (span) => position >= span.start && position <= span.end,
      );
    } catch (_) {
      return null;
    }
  }

  double getLineProgress(Duration position) {
    final total = endTime.inMilliseconds - startTime.inMilliseconds;
    if (total <= 0) return 0.0;
    final current = position.inMilliseconds - startTime.inMilliseconds;
    return (current / total).clamp(0.0, 1.0);
  }

  String? getTranslation(String lang) => translations?[lang];

  String getLineText() {
    if (spans.isEmpty) return '';
    String fullText = spans
        .map((s) => s.text)
        .join()
        .replaceAll(RegExp(r'\s+'), ' ');

    final buffer = StringBuffer();
    int lastType = 0;
    int getCharType(int code) {
      if (code == 32) return 0;
      if ((code >= 48 && code <= 57) ||
          (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122)) {
        return 1;
      }
      if (code <= 127) return 0;
      return 2;
    }

    for (final char in fullText.runes) {
      final currentType = getCharType(char);
      if (lastType != 0 && currentType != 0) {
        if ((lastType == 2 && currentType == 1) ||
            (lastType == 1 && currentType == 2)) {
          buffer.write(' ');
        }
      }
      buffer.write(String.fromCharCode(char));
      lastType = currentType;
    }

    return buffer.toString().trim();
  }
}

/// A single word/character span with start and end timing.
class LyricSpan {
  final String text;
  final Duration start;
  final Duration end;

  LyricSpan({required this.text, required this.start, required this.end});

  Map<String, dynamic> toJson() => {
    'text': text,
    'start': start.inMilliseconds,
    'end': end.inMilliseconds,
  };

  factory LyricSpan.fromJson(Map<String, dynamic> json) {
    return LyricSpan(
      text: json['text'] as String? ?? '',
      start: Duration(milliseconds: (json['start'] as num).toInt()),
      end: Duration(milliseconds: (json['end'] as num).toInt()),
    );
  }

  double getSpanProgress(Duration position) {
    final duration = end.inMilliseconds - start.inMilliseconds;
    if (duration <= 0) return 1.0;
    if (position < start) return 0.0;
    if (position > end) return 1.0;
    final current = position.inMilliseconds - start.inMilliseconds;
    return current / duration;
  }
}
