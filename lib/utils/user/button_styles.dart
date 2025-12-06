import 'package:flutter/material.dart';



class ButtonStyles {
  
  static const Color primaryColor = Color(0xFF00C8A0);
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

