import 'package:flutter/material.dart';

/// Utility class for consistent button styles
/// 
/// Provides pre-configured button styles matching the app theme
class ButtonStyles {
  /// Primary app color
  static const Color primaryColor = Color(0xFF00C8A0);

  /// Standard primary elevated button style
  static ButtonStyle primaryElevated({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    double? elevation,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      elevation: elevation ?? 2,
      shadowColor: primaryColor.withOpacity(0.3),
    );
  }

  /// Primary filled button style
  static ButtonStyle primaryFilled({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    );
  }

  /// Primary outlined button style
  static ButtonStyle primaryOutlined({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    );
  }

  /// Secondary (white background) button style
  static ButtonStyle secondaryElevated({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    double? elevation,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      elevation: elevation ?? 2,
    );
  }

  /// Disabled button style
  static ButtonStyle disabled({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[400],
      foregroundColor: Colors.grey[600],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      elevation: 0,
    );
  }

  /// Destructive (red) button style
  static ButtonStyle destructive({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      elevation: 2,
    );
  }

  /// Small button style (for compact spaces)
  static ButtonStyle small({
    Color? backgroundColor,
    Color? foregroundColor,
    double? borderRadius,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

