import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/user/resume_attachment.dart';
import '../../../models/user/tag_category.dart';
import '../../../models/user/tag.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/storage_service.dart';
import '../../../services/user/tag_service.dart';
import '../../../utils/user/tag_definitions.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/input_validators.dart';
import '../../../utils/user/form_scroll_helper.dart';
import '../../../widgets/user/resume_preview_card.dart';
import '../../../widgets/user/tag_selection_section.dart';
import '../../../widgets/user/location_autocomplete_field.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _authService = AuthService();
  final _tagService = TagService();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _profProfileCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final StorageService _storage = StorageService();
  TagSelectionMap _selectedTags = <String, List<String>>{};
  ResumeAttachment? _resumeAttachment;
  Map<TagCategory, List<Tag>> _tagCategoriesWithTags = {};
  bool _tagsLoading = true;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingResume = false;
  String? _selectedGender; // "male", "female", or "any"

  @override
  void initState() {
    super.initState();
    _load();
    _loadTags();
    
  }
  

  Future<void> _loadTags() async {
    try {
      final tagsData = await _tagService.getActiveTagCategoriesWithTags();
      if (mounted) {
        setState(() {
          _tagCategoriesWithTags = tagsData;
          _tagsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tagsLoading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    try {
      final doc = await _authService.getUserDoc();
      final data = doc.data() ?? <String, dynamic>{};
      _fullNameCtrl.text = (data['fullName'] as String?) ?? '';
      _emailCtrl.text = (FirebaseAuth.instance.currentUser?.email ?? (data['email'] as String?) ?? '');
      _phoneCtrl.text = (data['phoneNumber'] as String?) ?? '';
      final ageValue = data['age'];
      if (ageValue is num) {
        _ageCtrl.text = ageValue.toString();
      } else if (ageValue is String && ageValue.trim().isNotEmpty) {
        _ageCtrl.text = ageValue;
      }
      _locationCtrl.text = (data['location'] as String?) ?? '';
      _profProfileCtrl.text = (data['professionalProfile'] as String?) ?? '';
      _summaryCtrl.text = (data['professionalSummary'] as String?) ?? '';
      _experienceCtrl.text = (data['workExperience'] as String?) ?? '';
      _selectedGender = data['gender'] as String?;
      final attachment =
          ResumeAttachment.fromMap(data['resume']) ?? ResumeAttachment.fromLegacyValue(data['cvUrl']);
      final parsedTags = parseTagSelection(data['tags']);
      if (mounted) {
        setState(() {
          _selectedTags = parsedTags;
          _resumeAttachment = attachment;
        });
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to load profile: $e',
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _locationCtrl.dispose();
    _profProfileCtrl.dispose();
    _summaryCtrl.dispose();
    _experienceCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!FormValidationHelper.validateAndScroll(_formKey, context, scrollController: _scrollController)) return;
    setState(() => _saving = true);
    try {
      final tagsToSave = sanitizeTagSelection(_selectedTags);
      
      // Prepare resume data - only save downloadUrl, not base64 data to avoid Firestore size limit
      Map<String, dynamic>? resumeData;
      if (_resumeAttachment != null) {
        resumeData = {
          'fileName': _resumeAttachment!.fileName,
          'fileType': _resumeAttachment!.fileType,
          // Only save downloadUrl if it exists, don't save base64 data
          if (_resumeAttachment!.downloadUrl != null && _resumeAttachment!.downloadUrl!.isNotEmpty)
            'downloadUrl': _resumeAttachment!.downloadUrl,
          // Don't include base64 data to prevent Firestore document size limit (1MB) error
        };
        // If no downloadUrl and no base64, don't save resume data
        if (resumeData['downloadUrl'] == null) {
          resumeData = null;
        }
      }
      
      final ageText = _ageCtrl.text.trim();
      final ageValue = ageText.isEmpty ? null : int.tryParse(ageText);
      final payload = <String, dynamic>{
        'fullName': _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'location': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'professionalProfile': _profProfileCtrl.text.trim().isEmpty ? null : _profProfileCtrl.text.trim(),
        'professionalSummary': _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        'workExperience': _experienceCtrl.text.trim().isEmpty ? null : _experienceCtrl.text.trim(),
        'age': ageValue,
        'gender': _selectedGender,
        if (tagsToSave.isNotEmpty) 'tags': tagsToSave else 'tags': FieldValue.delete(),
        'profileCompleted': true,
      };
      // Handle resume field
      if (resumeData != null) {
        // Save resume if it has downloadUrl (not base64 data)
        payload['resume'] = resumeData;
      } else {
        // If resume was removed, delete both resume and cvUrl fields
        // (cvUrl is deleted for backward compatibility - clean up old data)
        payload['resume'] = FieldValue.delete();
        payload['cvUrl'] = FieldValue.delete();
      }
      await _authService.updateUserProfile(payload);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to save profile. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadResume() async {
    if (_uploadingResume) return;
    setState(() => _uploadingResume = true);
    try {
      final attachment = await _storage.pickAndUploadResume();
      if (!mounted) return;
      setState(() {
        _uploadingResume = false;
        if (attachment != null) {
          _resumeAttachment = attachment;
        }
      });
      if (attachment != null) {
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Resume uploaded successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingResume = false);
      // Extract error message from exception
      String errorMessage = 'Failed to upload resume';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else if (e is FirebaseException) {
        errorMessage = e.message ?? 'Firestore error: ${e.code}';
      }
      DialogUtils.showWarningMessage(
        context: context,
        message: errorMessage,
      );
    } finally {
      if (mounted && _uploadingResume) {
        setState(() => _uploadingResume = false);
      }
    }
  }

  Future<void> _removeResume() async {
    // Show confirmation dialog
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Remove Resume',
      message: 'Are you sure you want to remove your resume? This action cannot be undone.',
      icon: Icons.delete_outline,
      confirmText: 'Remove',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      // Immediately delete resume and cvUrl from Firestore
      await _authService.updateUserProfile({
        'resume': FieldValue.delete(),
        'cvUrl': FieldValue.delete(),
      });
      
      // Update UI state
      if (mounted) {
        setState(() {
          _resumeAttachment = null;
        });
        
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Resume removed successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to remove resume: $e',
      );
    }
  }

  void _onTagCategoryChanged(String categoryId, List<String> values) {
    setState(() {
      final next = Map<String, List<String>>.from(_selectedTags);
      if (values.isEmpty) {
        next.remove(categoryId);
      } else {
        next[categoryId] = values;
      }
      _selectedTags = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
       
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF00C8A0),
              ),
            )
          : AbsorbPointer(
              absorbing: _saving,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C8A0).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline,
                                size: 24,
                                color: const Color(0xFF00C8A0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Personal Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Update your profile details',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Personal Information Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildFormField(
                              controller: _fullNameCtrl,
                              label: 'Full Name*',
                              icon: Icons.person_outline,
                              validator: (v) => InputValidators.required(v, errorMessage: 'Required'),
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _emailCtrl,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              readOnly: true,
                              onTap: () {
                                DialogUtils.showInfoMessage(
                                  context: context,
                                  message: 'Email is managed by Authentication.',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _phoneCtrl,
                              label: 'Phone Number*',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                // Auto-format as user types: 012-345 6789
                                PhoneNumberFormatter(),
                              ],
                              validator: (v) => InputValidators.phoneNumberMalaysia(v, allowEmpty: false, errorMessage: 'Phone number is required. Format: 012-345 6789'),
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _ageCtrl,
                              label: 'Age*',
                              icon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                // Only allow digits
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) => InputValidators.age(v, errorMessage: 'Age must be 18 or above'),
                            ),
                            const SizedBox(height: 16),
                            _buildGenderDropdown(),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LocationAutocompleteField(
                                  controller: _locationCtrl,
                                  label: 'Location',
                                  hintText: 'Search location...',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Professional Information Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.work_outline,
                                    size: 20,
                                    color: const Color(0xFF00C8A0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Professional Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _profProfileCtrl,
                              label: 'Professional Profile',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _summaryCtrl,
                              label: 'Professional Summary',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _experienceCtrl,
                              label: 'Work Experience',
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Talent Tags Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.sell_outlined,
                                    size: 20,
                                    color: const Color(0xFF00C8A0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Talent Tags',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TagSelectionSection(
                              selections: _selectedTags,
                              onCategoryChanged: _onTagCategoryChanged,
                              tagCategoriesWithTags: _tagCategoriesWithTags,
                              loading: _tagsLoading,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Resume Upload Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.attach_file_outlined,
                                    size: 20,
                                    color: const Color(0xFF00C8A0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Resume & Documents',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ResumePreviewCard(
                              attachment: _resumeAttachment,
                              uploading: _uploadingResume,
                              onUpload: _uploadResume,
                              onRemove: _resumeAttachment == null ? null : _removeResume,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C8A0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: const Color(0xFF00C8A0).withOpacity(0.3),
                          ),
                          child: _saving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.save, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          validator: validator,
          onTap: onTap,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    color: const Color(0xFF00C8A0),
                    size: 20,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00C8A0)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[400]!,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGender,
                hint: Text(
                  'Select gender',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                iconSize: 24,
                dropdownColor: Colors.white,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: 'male',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Male'),
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'female',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Female'),
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'any',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Any'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}