import 'package:flutter/services.dart';

/// Reusable input validators for form fields
/// 
/// This utility provides common validation functions that can be used
/// with Flutter's TextFormField validator parameter.
/// 
/// ## Usage Examples:
/// 
/// ```dart
/// // Required field
/// TextFormField(
///   validator: InputValidators.required,
/// )
/// 
/// // Required field with custom error message
/// TextFormField(
///   validator: (v) => InputValidators.required(v, errorMessage: 'Job title is required'),
/// )
/// 
/// // Email validation (required + format)
/// TextFormField(
///   keyboardType: TextInputType.emailAddress,
///   validator: InputValidators.requiredEmail,
/// )
/// 
/// // Password with minimum length
/// TextFormField(
///   obscureText: true,
///   validator: (v) => InputValidators.password(v, minLength: 8),
/// )
/// 
/// // Integer validation (optional field)
/// TextFormField(
///   keyboardType: TextInputType.number,
///   validator: (v) => InputValidators.integer(v, allowEmpty: true),
/// )
/// 
/// // Decimal with range
/// TextFormField(
///   keyboardType: TextInputType.numberWithOptions(decimal: true),
///   validator: (v) => InputValidators.decimalRange(v, 0.0, 10000.0),
/// )
/// 
/// // Combining multiple validators
/// TextFormField(
///   validator: (v) => InputValidators.combine([
///     InputValidators.required,
///     (v) => InputValidators.minLength(v, 10),
///   ], v),
/// )
/// ```
class InputValidators {
  /// Validates that a field is not empty (after trimming)
  /// 
  /// Returns null if valid, error message if invalid
  static String? required(String? value, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    return null;
  }

  /// Validates email format
  /// 
  /// Returns null if valid, error message if invalid
  static String? email(String? value, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'Please enter your email';
    }
    
    // Basic email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return errorMessage ?? 'Please enter a valid email address';
    }
    
    return null;
  }

  /// Validates email format (required field)
  /// 
  /// Combines required and email validation
  static String? requiredEmail(String? value, {String? errorMessage}) {
    final requiredError = required(value);
    if (requiredError != null) {
      return requiredError;
    }
    return email(value, errorMessage: errorMessage);
  }

  /// Validates password with minimum length
  /// 
  /// Returns null if valid, error message if invalid
  static String? password(String? value, {int minLength = 6, String? errorMessage}) {
    if (value == null || value.isEmpty) {
      return errorMessage ?? 'Please enter your password';
    }
    
    if (value.length < minLength) {
      return errorMessage ?? 'Password must be at least $minLength characters';
    }
    
    return null;
  }

  /// Validates that a value is a valid integer
  /// 
  /// Returns null if valid, error message if invalid
  static String? integer(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'This field is required');
    }
    
    if (int.tryParse(value.trim()) == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    return null;
  }

  /// Validates that a value is a valid double/decimal
  /// 
  /// Returns null if valid, error message if invalid
  static String? decimal(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'This field is required');
    }
    
    if (double.tryParse(value.trim()) == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    return null;
  }

  /// Validates minimum length
  /// 
  /// Returns null if valid, error message if invalid
  static String? minLength(String? value, int minLength, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    
    if (value.trim().length < minLength) {
      return errorMessage ?? 'Must be at least $minLength characters';
    }
    
    return null;
  }

  /// Validates maximum length
  /// 
  /// Returns null if valid, error message if invalid
  static String? maxLength(String? value, int maxLength, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty is valid for maxLength, use required() if needed
    }
    
    if (value.trim().length > maxLength) {
      return errorMessage ?? 'Must be no more than $maxLength characters';
    }
    
    return null;
  }

  /// Validates length range
  /// 
  /// Returns null if valid, error message if invalid
  static String? lengthRange(String? value, int minLength, int maxLength, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    
    final trimmed = value.trim();
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return errorMessage ?? 'Must be between $minLength and $maxLength characters';
    }
    
    return null;
  }

  /// Validates numeric range (for integers)
  /// 
  /// Returns null if valid, error message if invalid
  static String? integerRange(String? value, int min, int max, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'This field is required');
    }
    
    final num = int.tryParse(value.trim());
    if (num == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    if (num < min || num > max) {
      return errorMessage ?? 'Must be between $min and $max';
    }
    
    return null;
  }

  /// Validates numeric range (for decimals)
  /// 
  /// Returns null if valid, error message if invalid
  static String? decimalRange(String? value, double min, double max, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'This field is required');
    }
    
    final num = double.tryParse(value.trim());
    if (num == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    if (num < min || num > max) {
      return errorMessage ?? 'Must be between $min and $max';
    }
    
    return null;
  }

  /// Validates phone number format (basic validation)
  /// 
  /// Returns null if valid, error message if invalid
  static String? phoneNumber(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'Please enter a phone number');
    }
    
    // Basic phone number validation (digits, spaces, dashes, parentheses, plus)
    final phoneRegex = RegExp(r'^[\d\s\-\(\)\+]+$');
    final digitsOnly = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    
    if (!phoneRegex.hasMatch(value.trim()) || digitsOnly.length < 7) {
      return errorMessage ?? 'Please enter a valid phone number';
    }
    
    return null;
  }

  /// Validates phone number format: "012-345 6789" (no alphabets)
  /// 
  /// Format: XXX-XXX XXXX (3 digits, dash, 3 digits, space, 4 digits)
  /// Returns null if valid, error message if invalid
  static String? phoneNumberMalaysia(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'Please enter a phone number');
    }
    
    final trimmed = value.trim();
    
    // Check for alphabets - reject if any found
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return errorMessage ?? 'Phone number cannot contain letters. Format: 012-345 6789';
    }
    
    // Validate format: XXX-XXX XXXX
    final phoneRegex = RegExp(r'^\d{3}-\d{3} \d{4}$');
    
    if (!phoneRegex.hasMatch(trimmed)) {
      return errorMessage ?? 'Invalid format. Please use: 012-345 6789';
    }
    
    return null;
  }

  /// Validates age (must be 18 or above)
  /// 
  /// Returns null if valid, error message if invalid
  static String? age(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'Age is required');
    }
    
    final ageNum = int.tryParse(value.trim());
    if (ageNum == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    if (ageNum < 17) {
      return errorMessage ?? 'Age must be 17 or above';
    }
    
    return null;
  }

  /// Combines multiple validators
  /// 
  /// Returns the first error found, or null if all validators pass
  static String? combine(List<String? Function(String?)> validators, String? value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  /// Creates a validator that checks if value matches a pattern
  /// 
  /// Returns null if valid, error message if invalid
  static String? pattern(String? value, RegExp pattern, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    
    if (!pattern.hasMatch(value.trim())) {
      return errorMessage ?? 'Invalid format';
    }
    
    return null;
  }

  /// Validates URL format
  /// 
  /// Returns null if valid, error message if invalid
  static String? url(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'Please enter a URL');
    }
    
    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlRegex.hasMatch(value.trim())) {
      return errorMessage ?? 'Please enter a valid URL';
    }
    
    return null;
  }
}

/// Text input formatter that automatically formats phone numbers as "012-345 6789"
/// 
/// Format: XXX-XXX XXXX (3 digits, dash, 3 digits, space, 4 digits)
/// Only allows digits and automatically inserts formatting characters
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 10 digits (normal phone number length)
    final limitedDigits = digitsOnly.length > 10 
        ? digitsOnly.substring(0, 10) 
        : digitsOnly;
    
    // Build formatted string
    String formatted = '';
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i == 3) {
        formatted += '-';
      } else if (i == 6) {
        formatted += ' ';
      }
      formatted += limitedDigits[i];
    }
    
    // Calculate cursor position based on digit count
    int cursorPosition;
    if (newValue.selection.baseOffset == -1) {
      // No selection, place cursor at end
      cursorPosition = formatted.length;
    } else {
      // Calculate cursor position in formatted string
      final digitsBeforeCursor = newValue.text
          .substring(0, newValue.selection.baseOffset)
          .replaceAll(RegExp(r'[^\d]'), '')
          .length;
      
      // Map digit position to formatted position
      cursorPosition = 0;
      for (int i = 0; i < digitsBeforeCursor && i < limitedDigits.length; i++) {
        cursorPosition++;
        if (i == 2) cursorPosition++; // After dash
        if (i == 5) cursorPosition++; // After space
      }
    }
    
    // Ensure cursor is within bounds
    if (cursorPosition > formatted.length) {
      cursorPosition = formatted.length;
    }
    if (cursorPosition < 0) {
      cursorPosition = 0;
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

