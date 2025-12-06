import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length > 10) {
      return oldValue;
    }
    
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
    
    int cursorPosition = formatted.length;
    if (oldValue.text.length < newValue.text.length) {
      
      if (formatted.length == 4 || formatted.length == 9) {
        
        cursorPosition = formatted.length;
      } else {
        cursorPosition = newValue.selection.baseOffset + (formatted.length - newValue.text.length);
      }
    } else {
      
      cursorPosition = newValue.selection.baseOffset;
    }
    
    cursorPosition = cursorPosition.clamp(0, formatted.length);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}
