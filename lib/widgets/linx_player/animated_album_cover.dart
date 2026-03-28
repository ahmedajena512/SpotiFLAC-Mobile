import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';

/// Animated album cover that transitions between large (full-screen) and
/// small (lyrics mode) layouts with smooth scale and position animations.
class AnimatedAlbumCover extends StatelessWidget {
  final String? albumArtPath;
  final String title;
  final String? artist;
  final bool isPlaying;
  final double animationProgress; // 0.0 = large cover, 1.0 = small cover
  final double smallCoverSize;
  final double largeCoverBorderRadius;
  final double smallCoverBorderRadius;
  final double smallCoverLeft;
  final double smallCoverTop;

  const AnimatedAlbumCover({
    super.key,
    required this.albumArtPath,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.animationProgress,
    this.smallCoverSize = 56.0,
    this.largeCoverBorderRadius = 20.0,
    this.smallCoverBorderRadius = 20.0,
    this.smallCoverLeft = 2.0,
    this.smallCoverTop = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final largeCoverSize = screenWidth;

        final largeCoverCenterX = screenWidth / 2;
        final largeCoverCenterY = largeCoverSize / 2;

        final smallCoverCenterX = smallCoverLeft + smallCoverSize / 2;
        final smallCoverCenterY = smallCoverTop + smallCoverSize / 2;

        final deltaX = smallCoverCenterX - largeCoverCenterX;
        final deltaY = smallCoverCenterY - largeCoverCenterY;

        final t = animationProgress;

        return Stack(
          children: [
            _buildCoverImage(
              largeCoverSize: largeCoverSize,
              deltaX: deltaX,
              deltaY: deltaY,
              t: t,
            ),
            _buildSongInfo(t),
          ],
        );
      },
    );
  }

  Widget _buildCoverImage({
    required double largeCoverSize,
    required double deltaX,
    required double deltaY,
    required double t,
  }) {
    final targetScale = smallCoverSize / largeCoverSize;
    final baseScale = 1.0 + (targetScale - 1.0) * t;
    final opacity = isPlaying ? 1.0 : 0.8;
    final offsetX = deltaX * t;
    final offsetY = deltaY * t;

    final currentVisualRadius =
        lerpDouble(largeCoverBorderRadius, smallCoverBorderRadius, t) ??
        largeCoverBorderRadius;
    final effectiveRadius = currentVisualRadius / baseScale;

    final shadowOpacity = isPlaying ? 0.1 : 0.05;
    final shadowBlur = isPlaying ? 10.0 : 5.0;

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform.scale(
        scale: baseScale,
        alignment: Alignment.center,
        child: Center(
          child: AnimatedScale(
            scale: isPlaying ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    largeCoverBorderRadius +
                        (smallCoverBorderRadius - largeCoverBorderRadius) * t,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: shadowOpacity),
                      blurRadius: shadowBlur / baseScale,
                      spreadRadius: 2 / baseScale,
                      offset: Offset(0, 8 / baseScale),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(effectiveRadius),
                  child: _buildImage(largeCoverSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(double size) {
    if (albumArtPath != null && albumArtPath!.isNotEmpty) {
      // Check if it's a network URL
      if (albumArtPath!.startsWith('http://') ||
          albumArtPath!.startsWith('https://')) {
        return Image.network(
          albumArtPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(size),
        );
      }
      // Local file
      final file = File(albumArtPath!);
      if (file.existsSync()) {
        return Image.file(file, width: size, height: size, fit: BoxFit.cover);
      }
    }
    return _buildPlaceholder(size);
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 80,
      ),
    );
  }

  Widget _buildSongInfo(double t) {
    if (t < 0.3) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(left: smallCoverSize, top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              artist ?? 'Unknown Artist',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
