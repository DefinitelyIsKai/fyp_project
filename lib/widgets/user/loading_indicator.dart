import 'package:flutter/material.dart';

/// Reusable loading indicator widget
/// 
/// Provides consistent loading UI across the application
class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;
  final EdgeInsets? padding;

  const LoadingIndicator({
    super.key,
    this.color,
    this.size,
    this.padding,
  });

  /// Standard loading indicator with app theme color
  const LoadingIndicator.standard({
    super.key,
    this.padding,
  }) : color = const Color(0xFF00C8A0),
       size = null;

  /// Small loading indicator
  const LoadingIndicator.small({
    super.key,
    this.padding,
  }) : color = const Color(0xFF00C8A0),
       size = 20.0;

  /// Large loading indicator
  const LoadingIndicator.large({
    super.key,
    this.padding,
  }) : color = const Color(0xFF00C8A0),
       size = 48.0;

  @override
  Widget build(BuildContext context) {
    Widget indicator = CircularProgressIndicator(
      color: color ?? const Color(0xFF00C8A0),
      strokeWidth: size != null && size! < 30 ? 2.0 : 4.0,
    );

    if (size != null) {
      indicator = SizedBox(
        width: size,
        height: size,
        child: indicator,
      );
    }

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: indicator,
      );
    }

    return Center(child: indicator);
  }
}

