import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 18,
    this.blur = 20,
    this.color,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.macOS;
    final enableBlur = isApple && blur > 0;

    Widget container = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (enableBlur ? AppTheme.card.withOpacity(0.65) : AppTheme.surfaceContainerHigh.withOpacity(0.85)),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(enableBlur ? 0.25 : 0.18),
            blurRadius: enableBlur ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    Widget content = enableBlur
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: container,
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: container,
          );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
