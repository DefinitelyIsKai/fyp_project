import 'package:flutter/material.dart';

/// Utility class for consistent input field decorations
/// 
/// Provides pre-configured InputDecoration styles for TextFormField
class InputDecorations {
  /// Primary app color
  static const Color primaryColor = Color(0xFF00C8A0);

  /// Standard input decoration
  static InputDecoration standard({
    String? hintText,
    String? labelText,
    String? helperText,
    String? prefixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool hasError = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      helperText: helperText,
      prefixText: prefixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? Colors.red : Colors.grey[400]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? Colors.red : primaryColor,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }

  /// Input decoration with icon
  static InputDecoration withIcon({
    required IconData icon,
    String? hintText,
    String? labelText,
    String? helperText,
    bool hasError = false,
  }) {
    return standard(
      hintText: hintText,
      labelText: labelText,
      helperText: helperText,
      prefixIcon: Icon(
        icon,
        color: primaryColor,
        size: 20,
      ),
      hasError: hasError,
    );
  }

  /// Input decoration for search fields
  static InputDecoration search({
    String? hintText,
    VoidCallback? onClear,
  }) {
    return InputDecoration(
      hintText: hintText ?? 'Search...',
      prefixIcon: const Icon(
        Icons.search,
        color: primaryColor,
      ),
      suffixIcon: onClear != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
              color: Colors.grey[600],
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }

  /// Input decoration for text areas (multiline)
  static InputDecoration textArea({
    String? hintText,
    String? labelText,
    bool hasError = false,
  }) {
    return standard(
      hintText: hintText,
      labelText: labelText,
      hasError: hasError,
    ).copyWith(
      contentPadding: const EdgeInsets.all(16),
      alignLabelWithHint: true,
    );
  }
}

