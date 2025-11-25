import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../widgets/user/resume_preview_card.dart';
import '../../../widgets/user/tag_selection_section.dart';
import '../../../widgets/user/location_autocomplete_field.dart';
import '../home_page.dart';

class ProfileSetupFlow extends StatefulWidget {
  const ProfileSetupFlow({super.key});

  @override
  State<ProfileSetupFlow> createState() => _ProfileSetupFlowState();
}

class _ProfileSetupFlowState extends State<ProfileSetupFlow> {
  final PageController _controller = PageController();
  final _authService = AuthService();
  final _tagService = TagService();

  // Step 1
  String _seekingChoice = 'actively';

  // Step 2
  final _step2FormKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _locationController = TextEditingController();
  double? _latitude;
  double? _longitude;

  // Step 3
  final _profProfileCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _workExperienceCtrl = TextEditingController();
  

  // Step 4
  TagSelectionMap _selectedTags = <String, List<String>>{};
  Map<TagCategory, List<Tag>> _tagCategoriesWithTags = {};
  bool _tagsLoading = true;

  // Step 5
  ResumeAttachment? _resumeAttachment;
  bool _acceptedTerms = false;

  int _index = 0;
  bool _saving = false;

  static const int _lastStepIndex = 4;

  @override
  void initState() {
    super.initState();
    _loadTags();
    
    // Listen to location text changes for autocomplete
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

  @override
  void dispose() {
    _controller.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _locationController.dispose();
    _profProfileCtrl.dispose();
    _summaryCtrl.dispose();
    _workExperienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    // Validate Step 2 (Personal Information) before proceeding
    if (_index == 1) {
      if (!_step2FormKey.currentState!.validate()) {
        return;
      }
    }
    
    if (_index < _lastStepIndex) {
      setState(() => _index++);
      await _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (!mounted) return;
    
    // Validate required fields before saving
    if (_workExperienceCtrl.text.trim().isEmpty) {
      // Navigate to Step 3 (Professional Profile step) if workExperience is missing
      if (_index != 2) {
        setState(() => _index = 2);
        await _controller.animateToPage(
          2,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Work Experience is required. Please fill it in.',
      );
      return;
    }
    
    setState(() => _saving = true);
    try {
      // Final step → save profile and finish
      final String role = _seekingChoice == 'hiring' ? 'recruiter' : 'jobseeker';
      final tagsToSave = sanitizeTagSelection(_selectedTags);
      final ageText = _ageCtrl.text.trim();
      final ageValue = ageText.isEmpty ? null : int.tryParse(ageText);
      await _authService.updateUserProfile({
        'fullName': _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'professionalProfile': _profProfileCtrl.text.trim().isEmpty ? null : _profProfileCtrl.text.trim(),
        'professionalSummary': _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        'workExperience': _workExperienceCtrl.text.trim(),
        'age': ageValue,
        'cvUrl': _resumeAttachment?.legacyValue,
        if (_resumeAttachment != null) 'resume': _resumeAttachment!.toMap() else 'resume': FieldValue.delete(),
        'role': role,
        'acceptedTerms': _acceptedTerms,
        if (tagsToSave.isNotEmpty) 'tags': tagsToSave else 'tags': FieldValue.delete(),
        'profileCompleted': true,
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Could not save profile. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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

  void _onBack() {
    if (_index == 0) return;
    setState(() => _index--);
    _controller.animateToPage(
      _index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF00C8A0);

    InputDecoration inputDecoration(String hint) => InputDecoration(
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.work_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'JobSeek',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Step 1
                  _StepContainer(
                    title: 'Are you looking for new opportunities',
                    child: Column(
                      children: [
                        _ChoiceTile(
                          title: 'Yes, Actively looking',
                          subtitle: 'Receive exclusive job invites and get contacted by recruiters',
                          selected: _seekingChoice == 'actively',
                          onTap: () => setState(() => _seekingChoice = 'actively'),
                        ),
                        const SizedBox(height: 12),
                        _ChoiceTile(
                          title: "I'm looking for jobseekers",
                          subtitle: 'Choose this to occasionally receive exclusive job invites',
                          selected: _seekingChoice == 'hiring',
                          onTap: () => setState(() => _seekingChoice = 'hiring'),
                        ),
                      ],
                    ),
                  ),
                  // Step 2
                  _StepContainer(
                    title: 'Personal Information',
                    child: Form(
                      key: _step2FormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full name*',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fullNameCtrl,
                            decoration: inputDecoration('Your full name'),
                            validator: InputValidators.required,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Phone Number*',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: inputDecoration('012-345 6789'),
                            inputFormatters: [
                              // Auto-format as user types: 012-345 6789
                              PhoneNumberFormatter(),
                            ],
                            validator: (v) => InputValidators.phoneNumberMalaysia(v, allowEmpty: false, errorMessage: 'Phone number is required. Format: 012-345 6789'),
                          ),
                          const SizedBox(height: 20),
                          LocationAutocompleteField(
                            controller: _locationController,
                            label: 'Location',
                            required: true,
                            hintText: 'Search location...',
                            onLocationSelected: (description, latitude, longitude) {
                              setState(() {
                                _latitude = latitude;
                                _longitude = longitude;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Age*',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: inputDecoration('e.g. 25'),
                            inputFormatters: [
                              // Only allow digits
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) => InputValidators.age(v, errorMessage: 'Age must be 18 or above'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Step 3
                  _StepContainer(
                    title: 'Professional Profile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Professional Profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(controller: _profProfileCtrl, decoration: inputDecoration('e.g. Mobile Developer')),
                        const SizedBox(height: 20),
                        Text(
                          'Professional Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _summaryCtrl,
                          maxLines: 4,
                          decoration: inputDecoration('Tell us about you'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Work Experience*',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _workExperienceCtrl,
                          maxLines: 5,
                          decoration: inputDecoration('Describe your work experience, years of experience, previous roles, etc.'),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Step 4
                  _StepContainer(
                    title: 'Choose the tags that describe you',
                    child: TagSelectionSection(
                      selections: _selectedTags,
                      onCategoryChanged: _onTagCategoryChanged,
                      tagCategoriesWithTags: _tagCategoriesWithTags,
                      loading: _tagsLoading,
                    ),
                  ),
                  // Step 5
                  _StepContainer(
                    title: 'Upload your CV to get your recruiter know you',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CV',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ResumePicker(
                          value: _resumeAttachment,
                          onChanged: (attachment) => setState(() => _resumeAttachment = attachment),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _acceptedTerms,
                                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                                activeColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'I acknowledge and agree with the terms and privacy of the application',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: _onBack,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_index == _lastStepIndex && !_acceptedTerms) || _saving ? null : _onNext,
                    child: _saving && _index == _lastStepIndex
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _index == _lastStepIndex ? 'Finish' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StepContainer extends StatelessWidget {
  const _StepContainer({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF00C8A0);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.work_outline,
                color: primaryColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF00C8A0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: selected ? primaryColor : Colors.black87,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: primaryColor,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumePicker extends StatefulWidget {
  const _ResumePicker({required this.value, required this.onChanged});
  final ResumeAttachment? value;
  final ValueChanged<ResumeAttachment?> onChanged;

  @override
  State<_ResumePicker> createState() => _ResumePickerState();
}

class _ResumePickerState extends State<_ResumePicker> {
  bool _uploading = false;
  final StorageService _storage = StorageService();

  Future<void> _pick() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final attachment = await _storage.pickAndUploadResume();
      if (!mounted) return;
      if (attachment != null) widget.onChanged(attachment);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResumePreviewCard(
      attachment: widget.value,
      uploading: _uploading,
      onUpload: _pick,
      onRemove: widget.value == null ? null : () => widget.onChanged(null),
    );
  }
}


