import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import 'lyrics_models.dart';

/// Parses LRC and TTML lyrics into [LyricsData].
class LyricsParser {
  /// Unified entry point: auto-detects format and parses.
  static Future<LyricsData> parse(String content) async {
    if (content.trim().isEmpty) {
      return LyricsData(lines: []);
    }

    final trimmed = content.trim();

    // TTML format (XML)
    if (trimmed.startsWith('<tt') || trimmed.contains('xmlns:tt')) {
      return _parseTtml(trimmed);
    }
    // LRC format (contains timestamps)
    else if (RegExp(r'\[\d{2}:\d{2}\.\d{1,3}\]').hasMatch(trimmed)) {
      return _parseLrc(trimmed);
    }
    // Unknown format
    else {
      debugPrint("Unknown lyrics format. Treating as plain text.");
      return LyricsData(lines: []);
    }
  }

  // --- LRC Parsing ---
  static Future<LyricsData> _parseLrc(String lrcContent) async {
    final Map<int, _RawLrcLine> timeToRawLines = {};
    final Map<String, dynamic> metadata = {};
    final lines = lrcContent.split(RegExp(r'\r\n|\r|\n'));

    int globalOffset = 0;

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final metadataMatch = RegExp(
        r'^\[([a-zA-Z]+):(.*)\]$',
      ).firstMatch(trimmedLine);
      if (metadataMatch != null) {
        final key = metadataMatch.group(1)?.toLowerCase();
        final value = metadataMatch.group(2)?.trim();
        if (key != null && value != null) {
          if (key == 'offset') {
            globalOffset = int.tryParse(value) ?? 0;
          } else {
            metadata[key] = value;
          }
        }
        continue;
      }

      final timeMatches = RegExp(
        r'\[(\d{2}):(\d{2})\.(\d{1,3})\]',
      ).allMatches(trimmedLine);
      if (timeMatches.isEmpty) continue;

      final text = trimmedLine
          .replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{1,3}\]'), '')
          .trimLeft();
      if (text.isEmpty) continue;

      for (final match in timeMatches) {
        final m = int.parse(match.group(1)!);
        final s = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = int.parse(msStr.padRight(3, '0'));
        final timeInMs = ((m * 60 + s) * 1000 + ms) - globalOffset;

        if (!timeToRawLines.containsKey(timeInMs)) {
          timeToRawLines[timeInMs] = _RawLrcLine();
        }
        timeToRawLines[timeInMs]!.texts.add(text);
      }
    }

    final sortedTimes = timeToRawLines.keys.toList()..sort();
    final lyricLines = <LyricLine>[];

    for (int i = 0; i < sortedTimes.length; i++) {
      final timeInMs = sortedTimes[i];
      final rawLine = timeToRawLines[timeInMs]!;

      final mainText = rawLine.texts.first;
      final Map<String, String> translations = {};

      if (rawLine.texts.length > 1) {
        translations['zh'] = rawLine.texts[1];
      }

      final nextTimeInMs = (i + 1 < sortedTimes.length)
          ? sortedTimes[i + 1]
          : timeInMs + 5000;

      final startTime = Duration(milliseconds: timeInMs > 0 ? timeInMs : 0);
      final endTime = Duration(milliseconds: nextTimeInMs);

      lyricLines.add(
        LyricLine(
          spans: _parseLrcSpans(mainText, startTime, endTime, globalOffset),
          startTime: startTime,
          endTime: endTime,
          translations: translations.isNotEmpty ? translations : null,
        ),
      );
    }

    return LyricsData(
      lines: lyricLines,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  // --- TTML Parsing ---
  static Future<LyricsData> _parseTtml(String ttmlContent) async {
    try {
      final document = XmlDocument.parse(ttmlContent);
      final paragraphs = document.findAllElements('p');
      final lyricLines = <LyricLine>[];
      final Map<String, dynamic> metadata = {};

      try {
        final head = document.findAllElements('head').firstOrNull;
        if (head != null) {
          final title = head
              .findAllElements('ttm:title')
              .firstOrNull
              ?.innerText;
          if (title != null) metadata['title'] = title;
        }
      } catch (_) {}

      for (final p in paragraphs) {
        final lineStartTimeStr = p.getAttribute('begin') ?? '0.0s';
        final lineEndTimeStr = p.getAttribute('end') ?? '0.0s';
        final lineStartTime = _parseTtmlTime(lineStartTimeStr);
        final lineEndTime = _parseTtmlTime(lineEndTimeStr);

        final tempSpans = <_TempSpan>[];

        for (final node in p.children) {
          if (node is XmlElement && node.name.local == 'span') {
            if (node.getAttribute('ttm:role') != null) continue;

            final text = node.innerText;
            if (text.isNotEmpty) {
              final sTime = _parseTtmlTime(
                node.getAttribute('begin') ?? lineStartTimeStr,
              );
              final eTimeStr = node.getAttribute('end');
              final eTime = eTimeStr != null ? _parseTtmlTime(eTimeStr) : null;

              tempSpans.add(_TempSpan(text, sTime, eTime));
            }
          } else if (node is XmlText &&
              node.value.trim().isEmpty &&
              tempSpans.isNotEmpty) {
            tempSpans.last.text += node.value;
          }
        }

        if (tempSpans.isEmpty) continue;

        final finalSpans = <LyricSpan>[];
        for (int i = 0; i < tempSpans.length; i++) {
          final current = tempSpans[i];

          Duration validEnd;
          if (current.endTime != null) {
            validEnd = current.endTime!;
          } else {
            final nextStart = (i + 1 < tempSpans.length)
                ? tempSpans[i + 1].startTime
                : lineEndTime;
            validEnd = nextStart > current.startTime
                ? nextStart
                : current.startTime + const Duration(milliseconds: 100);
          }

          finalSpans.addAll(
            _tokenizeAndDistribute(current.text, current.startTime, validEnd),
          );
        }

        if (finalSpans.isNotEmpty) {
          lyricLines.add(
            LyricLine(
              spans: finalSpans,
              startTime: lineStartTime,
              endTime: lineEndTime,
              translations: null,
            ),
          );
        }
      }
      return LyricsData(lines: lyricLines, metadata: metadata);
    } catch (e) {
      debugPrint('Error parsing TTML: $e');
      return LyricsData(lines: []);
    }
  }

  /// Tokenizes text into words/characters and distributes time evenly.
  static List<LyricSpan> _tokenizeAndDistribute(
    String text,
    Duration start,
    Duration end,
  ) {
    final spans = <LyricSpan>[];
    final totalDurationMs = (end - start).inMilliseconds;

    if (totalDurationMs <= 0 || text.isEmpty) {
      spans.add(LyricSpan(text: text, start: start, end: end));
      return spans;
    }

    final isEnglishLike = RegExp(r'[a-zA-Z]').hasMatch(text);
    List<String> tokens;

    if (isEnglishLike) {
      final words = text.split(' ');
      tokens = [];
      for (int w = 0; w < words.length; w++) {
        tokens.add(words[w] + (w < words.length - 1 ? ' ' : ''));
      }
    } else {
      tokens = text.split('');
    }

    tokens = tokens.where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return spans;

    final totalLen = tokens.fold(0, (sum, t) => sum + t.length);
    if (totalLen == 0) return spans;

    double msPerChar = totalDurationMs.toDouble() / totalLen;
    Duration currentStart = start;

    for (final token in tokens) {
      final tokenDurationMs = (msPerChar * token.length).round();
      final tokenDuration = Duration(milliseconds: max(1, tokenDurationMs));
      final tokenEnd = currentStart + tokenDuration;

      spans.add(LyricSpan(text: token, start: currentStart, end: tokenEnd));
      currentStart = tokenEnd;
    }

    if (spans.isNotEmpty) {
      final last = spans.removeLast();
      spans.add(LyricSpan(text: last.text, start: last.start, end: end));
    }

    return spans;
  }

  /// TTML time parsing (e.g. "100.5s" or "00:01:02.500").
  static Duration _parseTtmlTime(String time) {
    if (time.endsWith('s')) {
      final seconds = double.tryParse(time.replaceAll('s', '')) ?? 0.0;
      return Duration(milliseconds: (seconds * 1000).round());
    }
    final parts = time.split(':');
    try {
      if (parts.length == 3) {
        return Duration(
          milliseconds:
              int.parse(parts[0]) * 3600000 +
              int.parse(parts[1]) * 60000 +
              (double.parse(parts[2]) * 1000).round(),
        );
      } else if (parts.length == 2) {
        return Duration(
          milliseconds:
              int.parse(parts[0]) * 60000 +
              (double.parse(parts[1]) * 1000).round(),
        );
      }
      return Duration(milliseconds: (double.parse(parts[0]) * 1000).round());
    } catch (e) {
      return Duration.zero;
    }
  }

  static List<LyricSpan> _parseLrcSpans(
    String text,
    Duration lineStart,
    Duration lineEnd,
    int globalOffset,
  ) {
    // 1. Clean up v1: prefix
    String processed = text.replaceAll(RegExp(r'^v\d+:'), '').trimLeft();

    // 2. Find syllable tags
    final regex = RegExp(r'<(\d{2}):(\d{2})\.(\d{1,3})>');
    final matches = regex.allMatches(processed).toList();

    // No tags? Use standard character distribution
    if (matches.isEmpty) {
      return _tokenizeAndDistribute(processed, lineStart, lineEnd);
    }

    final spans = <LyricSpan>[];
    Duration currentStart = lineStart;
    String currentText = '';
    int currentIndex = 0;

    while (currentIndex < processed.length) {
      final match = _findMatchAt(processed, currentIndex, matches);
      if (match != null) {
        final timeInMs = _parseTimeMs(match) - globalOffset;
        final time = Duration(milliseconds: max(0, timeInMs));

        if (currentText.isNotEmpty) {
          spans.add(
            LyricSpan(text: currentText, start: currentStart, end: time),
          );
          currentText = '';
        }

        currentStart = time;
        currentIndex = match.end;
      } else {
        currentText += processed[currentIndex];
        currentIndex++;
      }
    }

    if (currentText.isNotEmpty) {
      final finalEnd = (lineEnd > currentStart)
          ? lineEnd
          : currentStart + const Duration(milliseconds: 500);
      spans.add(
        LyricSpan(text: currentText, start: currentStart, end: finalEnd),
      );
    }

    return spans;
  }

  static RegExpMatch? _findMatchAt(
    String text,
    int index,
    List<RegExpMatch> matches,
  ) {
    for (final m in matches) {
      if (m.start == index) return m;
    }
    return null;
  }

  static int _parseTimeMs(RegExpMatch match) {
    final m = int.parse(match.group(1)!);
    final s = int.parse(match.group(2)!);
    final msStr = match.group(3)!;
    final ms = int.parse(msStr.padRight(3, '0'));
    return (m * 60 + s) * 1000 + ms;
  }
}

class _RawLrcLine {
  final List<String> texts = [];
}

class _TempSpan {
  String text;
  Duration startTime;
  Duration? endTime;
  _TempSpan(this.text, this.startTime, [this.endTime]);
}
