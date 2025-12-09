import 'package:flutter/material.dart';


class CardDecorations {
  static BoxDecoration standard({
    Color? color,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      border: borderColor != null
          ? Border.all(
              color: borderColor,
              width: borderWidth ?? 1,
            )
          : null,
    );
  }

  static BoxDecoration bordered({
    Color? color,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      border: Border.all(
        color: borderColor ?? Colors.grey[100]!,
        width: borderWidth ?? 1,
      ),
    );
  }

  static BoxDecoration subtle({
    Color? color,
    double? borderRadius,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  static BoxDecoration accent({
    Color? color,
    double? borderRadius,
    double opacity = 0.05,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      border: Border.all(
        color: const Color(0xFF00C8A0).withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00C8A0).withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration unread({
    double? borderRadius,
  }) {
    return BoxDecoration(
      color: const Color(0xFF00C8A0).withOpacity(0.05),
      borderRadius: BorderRadius.circular(borderRadius ?? 12),
      border: Border.all(
        color: const Color(0xFF00C8A0).withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00C8A0).withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration read({
    double? borderRadius,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 12),
      border: Border.all(
        color: Colors.grey[100]!,
        width: 1,
      ),
    );
  }
  
  static BoxDecoration section({
    double? borderRadius,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

