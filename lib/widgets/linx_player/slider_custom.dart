import 'package:flutter/material.dart';

/// A custom slider that expands its track height on interaction.
class AnimatedTrackHeightSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final Color? activeColor;
  final Color? inactiveColor;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double trackHeight;

  const AnimatedTrackHeightSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
    this.inactiveColor,
    this.onChanged,
    this.onChangeEnd,
    this.trackHeight = 6,
  });

  @override
  State<AnimatedTrackHeightSlider> createState() =>
      _AnimatedTrackHeightSliderState();
}

class _AnimatedTrackHeightSliderState extends State<AnimatedTrackHeightSlider> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final normalHeight = widget.trackHeight;
    final expandedHeight = normalHeight * 1.8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: _isDragging ? expandedHeight + 16 : normalHeight + 16,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: _isDragging ? expandedHeight : normalHeight,
          activeTrackColor: widget.activeColor ?? Colors.white,
          inactiveTrackColor: widget.inactiveColor ?? Colors.white30,
          thumbColor: Colors.white,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _isDragging ? 8 : 0,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: widget.value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max == 0 ? 1.0 : widget.max,
          onChanged: (val) {
            if (!_isDragging) {
              setState(() => _isDragging = true);
            }
            widget.onChanged?.call(val);
          },
          onChangeEnd: (val) {
            setState(() => _isDragging = false);
            widget.onChangeEnd?.call(val);
          },
        ),
      ),
    );
  }
}
