import 'package:flutter/services.dart';


class InputValidators {
  static String? required(String? value, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    return null;
  }

  static String? email(String? value, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'Please enter your email';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return errorMessage ?? 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? requiredEmail(String? value, {String? errorMessage}) {
    final requiredError = required(value);
    if (requiredError != null) {
      return requiredError;
    }
    return email(value, errorMessage: errorMessage);
  }

  static String? password(String? value, {int minLength = 6, String? errorMessage}) {
    if (value == null || value.isEmpty) {
      return errorMessage ?? 'Please enter your password';
    }
    
    if (value.length < minLength) {
      return errorMessage ?? 'Password must be at least $minLength characters';
    }
    
    return null;
  }

  static String? integer(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'This field is required');
    }
    
    if (int.tryParse(value.trim()) == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    return null;
  }

  static String? decimal(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'This field is required');
    }
    
    if (double.tryParse(value.trim()) == null) {
      return errorMessage ?? 'Please enter a valid number';
    }
    
    return null;
  }

  static String? minLength(String? value, int minLength, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    
    if (value.trim().length < minLength) {
      return errorMessage ?? 'Must be at least $minLength characters';
    }
    
    return null;
  }


  static String? maxLength(String? value, int maxLength, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return null; 
    }
    
    if (value.trim().length > maxLength) {
      return errorMessage ?? 'Must be no more than $maxLength characters';
    }
    
    return null;
  }

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

  static String? phoneNumber(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'Please enter a phone number');
    }
    
    final phoneRegex = RegExp(r'^[\d\s\-\(\)\+]+$');
    final digitsOnly = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    
    if (!phoneRegex.hasMatch(value.trim()) || digitsOnly.length < 7) {
      return errorMessage ?? 'Please enter a valid phone number';
    }
    
    return null;
  }

  static String? phoneNumberMalaysia(String? value, {String? errorMessage, bool allowEmpty = false}) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : (errorMessage ?? 'Please enter a phone number');
    }
    
    final trimmed = value.trim();
    
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return errorMessage ?? 'Phone number cannot contain letters. Format: 012-345 6789';
    }
    
    final phoneRegex = RegExp(r'^\d{3}-\d{3} \d{4}$');
    
    if (!phoneRegex.hasMatch(trimmed)) {
      return errorMessage ?? 'Invalid format. Please use: 012-345 6789';
    }
    
    return null;
  }

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

  static String? combine(List<String? Function(String?)> validators, String? value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  static String? pattern(String? value, RegExp pattern, {String? errorMessage}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage ?? 'This field is required';
    }
    
    if (!pattern.hasMatch(value.trim())) {
      return errorMessage ?? 'Invalid format';
    }
    
    return null;
  }

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

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    final limitedDigits = digitsOnly.length > 10 
        ? digitsOnly.substring(0, 10) 
        : digitsOnly;
    
    String formatted = '';
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i == 3) {
        formatted += '-';
      } else if (i == 6) {
        formatted += ' ';
      }
      formatted += limitedDigits[i];
    }
  
    int cursorPosition;
    if (newValue.selection.baseOffset == -1) {

      cursorPosition = formatted.length;
    } else {
      final digitsBeforeCursor = newValue.text
          .substring(0, newValue.selection.baseOffset)
          .replaceAll(RegExp(r'[^\d]'), '')
          .length;
     
      cursorPosition = 0;
      for (int i = 0; i < digitsBeforeCursor && i < limitedDigits.length; i++) {
        cursorPosition++;
        if (i == 2) cursorPosition++; 
        if (i == 5) cursorPosition++; 
      }
    }
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

