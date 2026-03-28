import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class ColorExtractor {
  // Simple in-memory cache to avoid repeated image processing
  static final Map<String, List<Color>> _cache = {};

  /// Extracts dominant colors from an image path or URL.
  /// Returns an empty list if extraction fails.
  static Future<List<Color>> getColors(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return [];

    // Return cached colors if available
    if (_cache.containsKey(imagePath)) {
      return _cache[imagePath]!;
    }

    try {
      ImageProvider imageProvider;
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        imageProvider = NetworkImage(imagePath);
      } else {
        imageProvider = FileImage(File(imagePath));
      }

      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 16,
      );

      final List<Color> colors = [];
      if (palette.dominantColor != null) {
        colors.add(palette.dominantColor!.color);
      }
      if (palette.vibrantColor != null) {
        colors.add(palette.vibrantColor!.color);
      }
      if (palette.mutedColor != null) {
        colors.add(palette.mutedColor!.color);
      }
      if (palette.darkVibrantColor != null) {
        colors.add(palette.darkVibrantColor!.color);
      }

      if (colors.isNotEmpty) {
        // Ensure we have enough colors for a gradient
        if (colors.length < 2) {
          colors.add(colors.first.withValues(alpha: 0.8));
          if (colors.length < 3) {
            colors.add(colors.last.withValues(alpha: 0.6));
          }
        }
        _cache[imagePath] = colors;
        return colors;
      }
    } catch (_) {
      // Ignore errors (e.g., file not found, bad network)
    }

    return [];
  }
}
