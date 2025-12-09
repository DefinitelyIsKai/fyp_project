import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/role_model.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class AddAdminBasicInfoStep extends StatelessWidget {
  final StateSetter setDialogState;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String selectedRole;
  final List<RoleModel> adminRoles;
  final ValueNotifier<bool> obscurePasswordNotifier;
  final ValueNotifier<bool> obscureConfirmPasswordNotifier;
  final ValueNotifier<String?> nameErrorNotifier;
  final ValueNotifier<String?> emailErrorNotifier;
  final ValueNotifier<String?> passwordErrorNotifier;
  final ValueNotifier<String?> confirmPasswordErrorNotifier;
  final Function(String) onRoleChanged;
  final Function(bool) onObscurePasswordChanged;
  final Function(bool) onObscureConfirmPasswordChanged;
  final VoidCallback onNext;
  final String Function(String) getRoleDisplayName;

  const AddAdminBasicInfoStep({
    super.key,
    required this.setDialogState,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.selectedRole,
    required this.adminRoles,
    required this.obscurePasswordNotifier,
    required this.obscureConfirmPasswordNotifier,
    required this.nameErrorNotifier,
    required this.emailErrorNotifier,
    required this.passwordErrorNotifier,
    required this.confirmPasswordErrorNotifier,
    required this.onRoleChanged,
    required this.onObscurePasswordChanged,
    required this.onObscureConfirmPasswordChanged,
    required this.onNext,
    required this.getRoleDisplayName,
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_circle_outlined, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      RepaintBoundary(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: nameErrorNotifier,
                          builder: (context, nameError, _) {
                            final hasError = nameError != null;
                            return TextField(
                              controller: nameController,
                              onChanged: (value) {
                                if (nameError != null) {
                                  nameErrorNotifier.value = null;
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Full Name *',
                                hintText: 'Enter full name',
                                errorText: nameError,
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
                                prefixIcon: Icon(Icons.person_outline, color: hasError ? Colors.red : Colors.grey),
                                filled: true,
                                fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              textCapitalization: TextCapitalization.words,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      RepaintBoundary(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: emailErrorNotifier,
                          builder: (context, emailError, _) {
                            final hasError = emailError != null;
                            return TextField(
                              controller: emailController,
                              onChanged: (value) {
                                if (emailError != null) {
                                  emailErrorNotifier.value = null;
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Email Address *',
                                hintText: 'example@email.com',
                                errorText: emailError,
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
                                prefixIcon: Icon(Icons.email_outlined, color: hasError ? Colors.red : Colors.grey),
                                filled: true,
                                fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      RepaintBoundary(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: passwordErrorNotifier,
                          builder: (context, passwordError, _) {
                            final hasError = passwordError != null;
                            return ValueListenableBuilder<bool>(
                              valueListenable: obscurePasswordNotifier,
                              builder: (context, obscurePassword, _) {
                                return TextField(
                                  controller: passwordController,
                                  onChanged: (value) {
                                    if (passwordError != null) {
                                      passwordErrorNotifier.value = null;
                                    }
                                    if (confirmPasswordErrorNotifier.value != null && value == confirmPasswordController.text) {
                                      confirmPasswordErrorNotifier.value = null;
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Password *',
                                    hintText: 'Minimum 6 characters',
                                    errorText: passwordError,
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
                                    prefixIcon: Icon(Icons.lock_outline, color: hasError ? Colors.red : Colors.grey),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: hasError ? Colors.red : Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        obscurePasswordNotifier.value = !obscurePassword;
                                        onObscurePasswordChanged(obscurePasswordNotifier.value);
                                      },
                                    ),
                                    filled: true,
                                    fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  obscureText: obscurePassword,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      RepaintBoundary(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: confirmPasswordErrorNotifier,
                          builder: (context, confirmPasswordError, _) {
                            final hasError = confirmPasswordError != null;
                            return ValueListenableBuilder<bool>(
                              valueListenable: obscureConfirmPasswordNotifier,
                              builder: (context, obscureConfirmPassword, _) {
                                return TextField(
                                  controller: confirmPasswordController,
                                  onChanged: (value) {
                                    if (confirmPasswordError != null && value == passwordController.text) {
                                      confirmPasswordErrorNotifier.value = null;
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password *',
                                    hintText: 'Re-enter password',
                                    errorText: confirmPasswordError,
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
                                    prefixIcon: Icon(Icons.lock_outline, color: hasError ? Colors.red : Colors.grey),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: hasError ? Colors.red : Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        obscureConfirmPasswordNotifier.value = !obscureConfirmPassword;
                                        onObscureConfirmPasswordChanged(obscureConfirmPasswordNotifier.value);
                                      },
                                    ),
                                    filled: true,
                                    fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  obscureText: obscureConfirmPassword,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      const Text(
                        'Role *',
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
                          child: DropdownButton<String>(
                            value: selectedRole,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: adminRoles.map((role) {
                              return DropdownMenuItem(
                                value: role.name,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      getRoleDisplayName(role.name),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (role.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        role.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  onRoleChanged(value);
                                });
                              }
                            },
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

