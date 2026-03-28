import 'dart:math';

import 'package:flutter/material.dart';

/// Animated liquid gradient background inspired by Linx Music.
/// 7 floating blobs with smooth color transitions.
class LiquidGeneratorPage extends StatefulWidget {
  final List<Color> liquidColors;
  final bool isPlaying;
  final Duration speed;

  const LiquidGeneratorPage({
    super.key,
    List<Color>? liquidColors,
    this.isPlaying = true,
    this.speed = const Duration(seconds: 15),
  }) : liquidColors =
           liquidColors ??
           const [
             Color(0xFF00C6FB),
             Color(0xFF005BEA),
             Color(0xFFFF1053),
             Color(0xFFFF8D00),
           ];

  @override
  State<LiquidGeneratorPage> createState() => _LiquidGeneratorPageState();
}

class _LiquidGeneratorPageState extends State<LiquidGeneratorPage>
    with TickerProviderStateMixin {
  late AnimationController _loopController;
  late AnimationController _colorTransitionController;

  late List<Color> _oldColors;
  late List<Color> _targetColors;

  static const int _fixedBlobCount = 7;

  @override
  void initState() {
    super.initState();
    _oldColors = widget.liquidColors;
    _targetColors = widget.liquidColors;

    _loopController = AnimationController(vsync: this, duration: widget.speed);
    if (widget.isPlaying) {
      _loopController.repeat();
    }

    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(LiquidGeneratorPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _loopController.repeat();
      } else {
        _loopController.stop();
      }
    }

    if (widget.speed != oldWidget.speed) {
      _loopController.duration = widget.speed;
      if (widget.isPlaying) _loopController.repeat();
    }

    if (!_areListsEqual(widget.liquidColors, oldWidget.liquidColors)) {
      _oldColors = _getCurrentMixedColors();
      _targetColors = widget.liquidColors;
      _colorTransitionController.forward(from: 0.0);
    }
  }

  bool _areListsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<Color> _getCurrentMixedColors() {
    final double t = _colorTransitionController.value;
    final List<Color> result = [];

    for (int i = 0; i < _fixedBlobCount; i++) {
      final Color c1 = _oldColors[i % _oldColors.length];
      final Color c2 = _targetColors[i % _targetColors.length];

      if (_colorTransitionController.isCompleted) {
        result.add(c2);
      } else {
        result.add(Color.lerp(c1, c2, t)!);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _loopController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _loopController,
        _colorTransitionController,
      ]),
      builder: (context, child) {
        final List<Color> currentColors = _getCurrentMixedColors();

        return CustomPaint(
          painter: LiquidGradientPainter(
            colors: currentColors,
            progress: _loopController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class LiquidGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;

  LiquidGradientPainter({required this.colors, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()..color = _getDominantColor();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final int blobCount = colors.length;

    for (int i = 0; i < blobCount; i++) {
      final color = colors[i];
      _drawResponsiveBlob(canvas, size, i, blobCount, color);
    }
  }

  Color _getDominantColor() {
    if (colors.isEmpty) return Colors.black;
    final Color mix = Color.alphaBlend(
      colors[0].withValues(alpha: 0.5),
      colors.length > 1 ? colors[1] : colors[0],
    );

    return _adjustColor(mix, saturation: 0.8, value: 0.25);
  }

  Color _adjustColor(Color c, {double? saturation, double? value}) {
    final hsv = HSVColor.fromColor(c);
    return hsv
        .withSaturation(saturation ?? hsv.saturation)
        .withValue(value ?? hsv.value)
        .toColor();
  }

  void _drawResponsiveBlob(
    Canvas canvas,
    Size size,
    int index,
    int total,
    Color color,
  ) {
    final double maxSide = max(size.width, size.height);
    final double minSide = min(size.width, size.height);
    final double blurSigma = minSide * 0.2;

    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    final double angle = 2 * pi * progress;
    final double speedX = (index % 3) + 1.0;
    final double speedY = (index % 2) + 1.0;
    final double phase = index * (2 * pi / total);

    final double moveX = sin(angle * speedX + phase);
    final double moveY = cos(angle * speedY + phase);

    final double centerX = size.width / 2 + moveX * (size.width * 0.45);
    final double centerY = size.height / 2 + moveY * (size.height * 0.45);

    final double baseRadius = maxSide * 0.55;
    final double radiusBreath = sin(angle * 2 + index) * (minSide * 0.1);
    final double radius = baseRadius + radiusBreath;

    canvas.drawCircle(Offset(centerX, centerY), radius, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidGradientPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
