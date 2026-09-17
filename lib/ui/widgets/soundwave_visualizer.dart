import 'package:flutter/material.dart';

class SoundwaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final double height;
  final int barCount;

  const SoundwaveVisualizer({
    super.key,
    required this.isPlaying,
    this.color,
    this.height = 18.0,
    this.barCount = 4,
  });

  @override
  State<SoundwaveVisualizer> createState() => _SoundwaveVisualizerState();
}

class _SoundwaveVisualizerState extends State<SoundwaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundwaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFFA2D48),
      Color(0xFFFE6B00),
      Color(0xFFFF525E),
      Color(0xFFFFB693),
      Color(0xFFFA2D48),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (i) {
            final t = _controller.value;
            // Phase offset for each bar
            final offset = (i * 0.23) % 1.0;
            final val = (t + offset) % 1.0;
            final wave = (0.3 + 0.7 * (val < 0.5 ? val * 2 : (1 - val) * 2));
            final barH = widget.isPlaying ? (widget.height * wave).clamp(3.0, widget.height) : 3.0;
            final barColor = widget.color ?? colors[i % colors.length];

            return Container(
              width: 2.5,
              height: barH,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: barColor.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, -1),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}
