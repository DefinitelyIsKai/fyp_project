import 'package:flutter/material.dart';
import 'package:fyp_project/widgets/user/location_autocomplete_field.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/utils/admin/phone_number_formatter.dart';
import 'package:flutter/services.dart';

class AddAdminAdditionalInfoStep extends StatelessWidget {
  final BuildContext pageContext;
  final StateSetter setDialogState;
  final PageController pageController;
  final TextEditingController locationController;
  final TextEditingController ageController;
  final TextEditingController phoneNumberController;
  final TextEditingController currentPasswordController;
  final String? selectedGender;
  final ValueNotifier<bool> obscureCurrentPasswordNotifier;
  final ValueNotifier<String?> ageErrorNotifier;
  final ValueNotifier<String?> phoneNumberErrorNotifier;
  final Function(String?) onGenderChanged;
  final Function(bool) onObscureCurrentPasswordChanged;
  final Function(Map<String, String?>) onErrorsChanged;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String selectedRole;
  final ValueNotifier<String?> nameErrorNotifier;
  final ValueNotifier<String?> emailErrorNotifier;
  final ValueNotifier<String?> passwordErrorNotifier;
  final ValueNotifier<String?> confirmPasswordErrorNotifier;
  final ValueNotifier<String?> selectedImageBase64Notifier;
  final ValueNotifier<String?> selectedImageFileTypeNotifier;
  final VoidCallback onSubmit;

  const AddAdminAdditionalInfoStep({
    super.key,
    required this.pageContext,
    required this.setDialogState,
    required this.pageController,
    required this.locationController,
    required this.ageController,
    required this.phoneNumberController,
    required this.currentPasswordController,
    required this.selectedGender,
    required this.obscureCurrentPasswordNotifier,
    required this.ageErrorNotifier,
    required this.phoneNumberErrorNotifier,
    required this.onGenderChanged,
    required this.onObscureCurrentPasswordChanged,
    required this.onErrorsChanged,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.selectedRole,
    required this.nameErrorNotifier,
    required this.emailErrorNotifier,
    required this.passwordErrorNotifier,
    required this.confirmPasswordErrorNotifier,
    required this.selectedImageBase64Notifier,
    required this.selectedImageFileTypeNotifier,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationAutocompleteField(
                  controller: locationController,
                  label: 'Location (Optional)',
                  hintText: 'Search location... (e.g., Kuala Lumpur)',
                  restrictToCountry: 'my',
                  onLocationSelected: (description, latitude, longitude) {
                    if (latitude != null && longitude != null) {
                      print('Selected location: $description');
                      print('Coordinates: $latitude, $longitude');
                    }
                  },
                ),
                const SizedBox(height: 12),
                
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: ageErrorNotifier,
                    builder: (context, ageError, _) {
                      final hasError = ageError != null;
                      return TextField(
                        controller: ageController,
                        onChanged: (value) {
                          if (ageError != null) {
                            ageErrorNotifier.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Age (Optional)',
                          hintText: 'Enter age (18-80)',
                          errorText: ageError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.cake_outlined, color: hasError ? Colors.red : Colors.grey),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: phoneNumberErrorNotifier,
                    builder: (context, phoneNumberError, _) {
                      final hasError = phoneNumberError != null;
                      return TextField(
                        controller: phoneNumberController,
                        onChanged: (value) {
                          if (phoneNumberError != null) {
                            final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                            if (digitsOnly.length == 10) {
                              phoneNumberErrorNotifier.value = null;
                            }
                          }
                        },
                        inputFormatters: [
                          PhoneNumberFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: 'XXX-XXX XXXX',
                          errorText: phoneNumberError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.phone_outlined, color: hasError ? Colors.red : Colors.grey),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 13,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Gender (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedGender,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                      hint: const Text(
                        'Select gender',
                        style: TextStyle(color: Colors.grey),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Not specified'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Male',
                          child: Text('Male'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          onGenderChanged(value);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Current Password (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your current password to stay logged in after creating the new admin. If left empty, you will need to log in again.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[900],
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: currentPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Your Current Password',
                          hintText: 'Enter your password to stay logged in',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
                          ),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.orange[700]),
                          suffixIcon: ValueListenableBuilder<bool>(
                            valueListenable: obscureCurrentPasswordNotifier,
                            builder: (context, obscureCurrentPassword, _) {
                              return IconButton(
                                icon: Icon(
                                  obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  obscureCurrentPasswordNotifier.value = !obscureCurrentPassword;
                                  onObscureCurrentPasswordChanged(obscureCurrentPasswordNotifier.value);
                                },
                              );
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        obscureText: obscureCurrentPasswordNotifier.value,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The new admin will be able to log in immediately with the provided credentials.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[900],
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text(
                      'Complete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

