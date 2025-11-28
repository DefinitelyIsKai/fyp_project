import 'package:flutter/services.dart';

/// Custom TextInputFormatter for phone number formatting (XXX-XXX XXXX)
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 10 digits
    if (digitsOnly.length > 10) {
      return oldValue;
    }
    
    // Format as XXX-XXX XXXX
    String formatted = '';
    if (digitsOnly.isNotEmpty) {
      formatted = digitsOnly.substring(0, digitsOnly.length > 3 ? 3 : digitsOnly.length);
      if (digitsOnly.length > 3) {
        formatted += '-${digitsOnly.substring(3, digitsOnly.length > 6 ? 6 : digitsOnly.length)}';
      }
      if (digitsOnly.length > 6) {
        formatted += ' ${digitsOnly.substring(6)}';
      }
    }
    
    // Calculate cursor position
    int cursorPosition = formatted.length;
    if (oldValue.text.length < newValue.text.length) {
      // User is typing forward
      if (formatted.length == 4 || formatted.length == 9) {
        // Skip past dash/space when typing
        cursorPosition = formatted.length;
      } else {
        cursorPosition = newValue.selection.baseOffset + (formatted.length - newValue.text.length);
      }
    } else {
      // User is deleting
      cursorPosition = newValue.selection.baseOffset;
    }
    
    cursorPosition = cursorPosition.clamp(0, formatted.length);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

