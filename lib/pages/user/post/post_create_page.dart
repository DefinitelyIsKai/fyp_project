import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user/post.dart';
import '../../../models/user/category.dart';
import '../../../models/user/tag_category.dart';
import '../../../models/user/tag.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/category_service.dart';
import '../../../services/user/tag_service.dart';
import '../../../services/user/storage_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../utils/user/tag_definitions.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/input_validators.dart';
import '../../../widgets/user/tag_selection_section.dart';
import '../../../widgets/user/date_picker_field.dart';
import '../../../widgets/user/location_autocomplete_field.dart';
import '../../../widgets/user/image_upload_section.dart';
import 'dart:async';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key, this.existing});

  final Post? existing;

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetMinController = TextEditingController();
  final TextEditingController _budgetMaxController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  double? _latitude;
  double? _longitude;
  String? _selectedEvent;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _quotaController = TextEditingController();
  TagSelectionMap _selectedTags = <String, List<String>>{};
  JobType _jobType = JobType.weekdays;
  final PostService _service = PostService();
  final CategoryService _categoryService = CategoryService();
  final TagService _tagService = TagService();
  final AuthService _authService = AuthService();
  bool _saving = false;
  bool _hasPopped = false; // Track if we've already navigated away
  final StorageService _storage = StorageService();
  final List<String> _attachments = <String>[];
  List<Category> _categories = <Category>[];
  bool _categoriesLoading = true;
  String? _categoriesError;
  Map<TagCategory, List<Tag>> _tagCategoriesWithTags = {};
  bool _tagsLoading = true;
  final FocusNode _jobTypeFocusNode = FocusNode();
  final FocusNode _eventFocusNode = FocusNode();
  bool _jobTypeFocused = false;
  bool _eventFocused = false;
  late String _postId; // Generated upfront for new posts to avoid temp document
  final GlobalKey<FormFieldState<String>> _budgetMinKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _budgetMaxKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _minAgeKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _maxAgeKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _quotaKey = GlobalKey<FormFieldState<String>>();
  // Track which fields have been focused/clicked
  final Set<TextEditingController> _focusedFields = {};

  @override
  void initState() {
    super.initState();
    // Generate post ID upfront for new posts to avoid creating temp document
    // For existing posts, use the existing ID
    _postId = widget.existing?.id ?? 
        FirebaseFirestore.instance.collection('posts').doc().id;
    
    _loadCategories();
    _loadTags();
    _jobTypeFocusNode.addListener(() {
      setState(() {
        _jobTypeFocused = _jobTypeFocusNode.hasFocus;
      });
    });
    _eventFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _eventFocused = _eventFocusNode.hasFocus;
        });
      }
    });
    final Post? p = widget.existing;
    if (p != null) {
      _titleController.text = p.title;
      _descriptionController.text = p.description;
      _budgetMinController.text = (p.budgetMin ?? '').toString();
      _budgetMaxController.text = (p.budgetMax ?? '').toString();
      _locationController.text = p.location;
      _latitude = p.latitude;
      _longitude = p.longitude;
      _selectedEvent = p.event.isEmpty ? null : p.event;
      _eventStartDate = p.eventStartDate;
      _eventEndDate = p.eventEndDate;
      _minAgeController.text = p.minAgeRequirement?.toString() ?? '';
      _maxAgeController.text = p.maxAgeRequirement?.toString() ?? '';
      _quotaController.text = p.applicantQuota?.toString() ?? '';
      _jobType = p.jobType;
      
      // Load existing attachments from Firestore (similar to post_details_page.dart)
      _loadExistingAttachments(p.id);
    }
    
    // Add listeners to update button state when fields change
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _budgetMinController.addListener(() {
      _onFieldChanged();
      // Re-validate max budget when min budget changes
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
      // Also validate max budget FormField directly
      _budgetMaxKey.currentState?.validate();
    });
    _budgetMaxController.addListener(_onFieldChanged);
    _minAgeController.addListener(() {
      _onFieldChanged();
      // Re-validate max age when min age changes
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
      // Also validate max age FormField directly
      _maxAgeKey.currentState?.validate();
    });
    _maxAgeController.addListener(_onFieldChanged);
    _quotaController.addListener(_onFieldChanged);
  }
  
  void _onFieldChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to update button state
      });
    }
  }

  // Load attachments from Firestore (similar to post_details_page.dart)
  Future<void> _loadExistingAttachments(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      final data = doc.data();
      if (data != null && data['attachments'] != null) {
        final attachments = data['attachments'] as List?;
        if (attachments != null && attachments.isNotEmpty) {
          // Extract base64 strings from attachments (supports both old and new format)
          final List<String> base64Strings = [];
          for (final a in attachments) {
            if (a is Map) {
              // Old format: object with base64 field
              final base64 = a['base64'] as String?;
              if (base64 != null && base64.isNotEmpty) {
                base64Strings.add(base64);
              }
            } else if (a is String) {
              // New format: direct base64 string
              if (a.isNotEmpty) {
                base64Strings.add(a);
              }
            }
          }
          if (mounted && base64Strings.isNotEmpty) {
            setState(() {
              _attachments.clear();
              _attachments.addAll(base64Strings);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading attachments: $e');
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final categories = await _categoryService.getActiveCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _categoriesLoading = false;
          if (categories.isEmpty) {
            _categoriesError = 'No event types available. Please contact support.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoriesLoading = false;
          _categoriesError = 'Failed to load event types: $e';
        });
      }
    }
  }

  Future<void> _loadTags() async {
    try {
      final tagsData = await _tagService.getActiveTagCategoriesWithTags();
      if (mounted) {
        setState(() {
          _tagCategoriesWithTags = tagsData;
          _tagsLoading = false;
        });
        // If editing an existing post, map existing tags to categories
        if (widget.existing != null && widget.existing!.tags.isNotEmpty) {
          _mapExistingTagsToCategories(widget.existing!.tags);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tagsLoading = false;
        });
      }
    }
  }

  /// Maps existing tag names to their category IDs
  void _mapExistingTagsToCategories(List<String> existingTagNames) {
    final Map<String, List<String>> mappedTags = {};
    
    // Create a map of tag name -> category ID for quick lookup
    final Map<String, String> tagNameToCategoryId = {};
    for (final entry in _tagCategoriesWithTags.entries) {
      final category = entry.key;
      final tags = entry.value;
      for (final tag in tags) {
        tagNameToCategoryId[tag.name] = category.id;
      }
    }
    
    // Group existing tags by their category
    for (final tagName in existingTagNames) {
      final categoryId = tagNameToCategoryId[tagName];
      if (categoryId != null) {
        if (!mappedTags.containsKey(categoryId)) {
          mappedTags[categoryId] = [];
        }
        if (!mappedTags[categoryId]!.contains(tagName)) {
          mappedTags[categoryId]!.add(tagName);
        }
      }
    }
    
    setState(() {
      _selectedTags = mappedTags;
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _locationController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _locationController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _quotaController.dispose();
    _jobTypeFocusNode.dispose();
    _eventFocusNode.dispose();
    super.dispose();
  }

  /// Validates all required fields for publishing
  String? _validateRequiredFieldsForPublish() {
    // Validate form fields (title, description)
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return 'Please fill in all required form fields';
    }
    
    // Validate location
    if (_locationController.text.trim().isEmpty) {
      return 'Location is required';
    }
    if (_latitude == null || _longitude == null) {
      return 'Please select a valid location from the suggestions';
    }
    
    // Validate event type
    if (_selectedEvent == null || _selectedEvent!.isEmpty) {
      return 'Event type is required';
    }
    
    // Validate event dates (required fields)
    if (_eventStartDate == null) {
      return 'Event start date is required';
    }
    if (_eventEndDate == null) {
      return 'Event end date is required';
    }
    if (_eventEndDate!.isBefore(_eventStartDate!)) {
      return 'Event end date cannot be before start date';
    }
    
    // Validate budget (required fields)
    if (_budgetMinController.text.trim().isEmpty) {
      return 'Minimum budget is required';
    }
    if (_budgetMaxController.text.trim().isEmpty) {
      return 'Maximum budget is required';
    }
    final minBudget = _parseDouble(_budgetMinController.text);
    final maxBudget = _parseDouble(_budgetMaxController.text);
    if (minBudget == null || maxBudget == null) {
      return 'Please enter valid budget amounts';
    }
    if (maxBudget < minBudget) {
      return 'Maximum budget cannot be lower than minimum budget';
    }
    
    // Validate age requirements (required fields)
    if (_minAgeController.text.trim().isEmpty) {
      return 'Minimum age is required';
    }
    if (_maxAgeController.text.trim().isEmpty) {
      return 'Maximum age is required';
    }
    final minAge = _parseInt(_minAgeController.text);
    final maxAge = _parseInt(_maxAgeController.text);
    if (minAge == null || maxAge == null) {
      return 'Please enter valid age values';
    }
    if (minAge < 17) {
      return 'Minimum age must be 17 or above';
    }
    if (maxAge < 17) {
      return 'Maximum age must be 17 or above';
    }
    if (maxAge > 50) {
      return 'Maximum age must be 50 or below';
    }
    if (maxAge < minAge) {
      return 'Maximum age cannot be lower than minimum age';
    }
    
    // Validate applicant quota (required field)
    if (_quotaController.text.trim().isEmpty) {
      return 'Applicant quota is required';
    }
    final quota = _parseInt(_quotaController.text);
    if (quota == null || quota <= 0) {
      return 'Please enter a valid applicant quota (must be greater than 0)';
    }
    
    return null; // All validations passed
  }

  /// Checks if all required fields are filled (for button state)
  bool _canPublish() {
    if (_saving) return false;
    
    // Check if form is initialized
    final formState = _formKey.currentState;
    if (formState == null) return false;
    
    // Check title (required field)
    if (_titleController.text.trim().isEmpty) {
      return false;
    }
    
    // Check description (required field)
    if (_descriptionController.text.trim().isEmpty) {
      return false;
    }
    
    // Check location (required field with coordinates)
    if (_locationController.text.trim().isEmpty || 
        _latitude == null || 
        _longitude == null) {
      return false;
    }
    
    // Check event type (required field)
    if (_selectedEvent == null || _selectedEvent!.isEmpty) {
      return false;
    }
    
    // Check event dates (required fields)
    if (_eventStartDate == null || _eventEndDate == null) {
      return false;
    }
    
    // Check budget (required fields)
    if (_budgetMinController.text.trim().isEmpty || 
        _budgetMaxController.text.trim().isEmpty) {
      return false;
    }
    
    // Check age requirements (required fields)
    if (_minAgeController.text.trim().isEmpty || 
        _maxAgeController.text.trim().isEmpty) {
      return false;
    }
    
    // Check applicant quota (required field)
    if (_quotaController.text.trim().isEmpty) {
      return false;
    }
    
    return true;
  }

  Future<void> _save({required bool publish}) async {
    // Prevent multiple simultaneous save operations - check and set atomically
    if (_saving) return;
    _saving = true;
    if (mounted) {
      setState(() {}); // Trigger rebuild to disable buttons
    }
    
    // For publishing, validate all required fields
    if (publish) {
      // Mark all budget and age fields as focused to show errors after validation
      if (mounted) {
        setState(() {
          _focusedFields.add(_budgetMinController);
          _focusedFields.add(_budgetMaxController);
          _focusedFields.add(_minAgeController);
          _focusedFields.add(_maxAgeController);
          _focusedFields.add(_quotaController);
        });
      }
      
      // Trigger validation on all FormFields
      _budgetMinKey.currentState?.validate();
      _budgetMaxKey.currentState?.validate();
      _minAgeKey.currentState?.validate();
      _maxAgeKey.currentState?.validate();
      _quotaKey.currentState?.validate();
      
      final formState = _formKey.currentState;
      if (formState != null && !formState.validate()) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      
      final validationError = _validateRequiredFieldsForPublish();
      if (validationError != null) {
        if (mounted) setState(() => _saving = false);
        DialogUtils.showWarningMessage(
          context: context,
          message: validationError,
        );
        return;
      }
    } else {
      // For drafts, only validate form fields
      final formState = _formKey.currentState;
      if (formState == null || !formState.validate()) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }
    
    if (!mounted) {
      _saving = false;
      return;
    }
    
    final String id = widget.existing?.id ?? _postId; // Use generated ID for new posts
    final selectedTags = _selectedTags.values.expand((list) => list).toList();
    
    final minAge = _parseInt(_minAgeController.text);
    final maxAge = _parseInt(_maxAgeController.text);
    final quota = _parseInt(_quotaController.text);
    
    final Post post = Post(
      id: id,
      ownerId: widget.existing?.ownerId ?? _authService.currentUserId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      budgetMin: _parseDouble(_budgetMinController.text),
      budgetMax: _parseDouble(_budgetMaxController.text),
      location: _locationController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      event: _selectedEvent ?? '',
      jobType: _jobType,
      tags: selectedTags,
      requiredSkills: selectedTags,
      minAgeRequirement: minAge,
      maxAgeRequirement: maxAge,
      applicantQuota: quota,
      attachments: _attachments,
      isDraft: !publish,
      status: widget.existing == null ? PostStatus.pending : widget.existing!.status,
      createdAt: widget.existing?.createdAt,
      eventStartDate: _eventStartDate,
      eventEndDate: _eventEndDate,
      views: widget.existing?.views ?? 0,
      applicants: widget.existing?.applicants ?? 0,
    );
    
    try {
      if (widget.existing == null) {
        await _service.create(post);
      } else {
        await _service.update(post);
      }
      if (!mounted || _hasPopped) return;
      // Return publish status: true if published, false if draft
      // Only pop once to prevent "Future already completed" error
      _hasPopped = true;
      Navigator.pop(context, publish);
    } catch (e) {
      if (!mounted || _hasPopped) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to save: $e',
      );
    } finally {
      if (mounted && !_hasPopped) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  double? _parseDouble(String input) {
    final String t = input.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _parseInt(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
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
        title: Text(
          widget.existing == null ? 'Create New Post' : 'Edit Post',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                    Text(
                      widget.existing == null ? 'Create New Job Post' : 'Edit Job Post',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.existing == null 
                          ? 'Fill in the details to create a new job posting'
                          : 'Update your job post information',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Basic Information Card
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
                        Icon(Icons.info_outline, size: 20, color: const Color(0xFF00C8A0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_titleController, 'Job Title*', 
                      validator: (v) => InputValidators.required(v, errorMessage: 'Required')),
                    const SizedBox(height: 16),
                    _buildTextField(_descriptionController, 'Description*', 
                      maxLines: 5, 
                      validator: (v) => InputValidators.required(v, errorMessage: 'Required')),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Budget & Location Card
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
                        Icon(Icons.attach_money, size: 20, color: const Color(0xFF00C8A0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Budget & Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_budgetMinController, 'Min Budget*',
                            prefixText: '\$ ',
                            keyboardType: TextInputType.number,
                            showErrorBelow: true,
                            validator: (v) => InputValidators.required(v, errorMessage: 'Required')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(_budgetMaxController, 'Max Budget*',
                            prefixText: '\$ ',
                            keyboardType: TextInputType.number,
                            showErrorBelow: true,
                            validator: (v) {
                              final requiredError = InputValidators.required(v, errorMessage: 'Required');
                              if (requiredError != null) return requiredError;
                              
                              if (v == null || v.trim().isEmpty) return null; // Already handled by required
                              
                              final maxBudget = _parseDouble(v);
                              final minBudget = _parseDouble(_budgetMinController.text);
                              
                              if (maxBudget == null) {
                                return 'Please enter a valid number';
                              }
                              
                              if (minBudget != null && maxBudget < minBudget) {
                                return 'Max budget cannot be lower than min budget';
                              }
                              
                              return null;
                            }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                        _onFieldChanged(); // Update button state
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Job Details Card
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
                        Icon(Icons.work_outline, size: 20, color: const Color(0xFF00C8A0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Job Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _eventDropdown()),
                        const SizedBox(width: 12),
                        Expanded(child: _jobTypeDropdown()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DatePickerField(
                            label: 'Event Start Date',
                            selectedDate: _eventStartDate,
                            onDateSelected: (date) {
                              setState(() {
                                _eventStartDate = date;
                                // If end date is before new start date, clear it
                                if (_eventEndDate != null && _eventEndDate!.isBefore(date)) {
                                  _eventEndDate = null;
                                }
                              });
                              _onFieldChanged();
                            },
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DatePickerField(
                            label: 'Event End Date',
                            selectedDate: _eventEndDate,
                            onDateSelected: (date) {
                              setState(() {
                                _eventEndDate = date;
                              });
                              _onFieldChanged();
                            },
                            firstDate: _eventStartDate ?? DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            required: true,
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
              
              const SizedBox(height: 16),
              
              // Attachments Card
              const SizedBox(height: 16),

              // Candidate Requirements Card
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
                        Icon(Icons.rule_outlined, size: 20, color: const Color(0xFF00C8A0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Candidate Requirements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _minAgeController,
                            'Minimum Age*',
                            keyboardType: TextInputType.number,
                            showErrorBelow: true,
                            validator: (v) {
                              final requiredError = InputValidators.required(v, errorMessage: 'Required');
                              if (requiredError != null) return requiredError;
                              
                              if (v == null || v.trim().isEmpty) return null; // Already handled by required
                              
                              final minAge = _parseInt(v);
                              if (minAge == null) {
                                return 'Please enter a valid number';
                              }
                              
                              if (minAge < 18) {
                                return 'Minimum age must be 18 or above';
                              }
                              
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            _maxAgeController,
                            'Maximum Age*',
                            keyboardType: TextInputType.number,
                            showErrorBelow: true,
                            validator: (v) {
                              final requiredError = InputValidators.required(v, errorMessage: 'Required');
                              if (requiredError != null) return requiredError;
                              
                              if (v == null || v.trim().isEmpty) return null; // Already handled by required
                              
                              final maxAge = _parseInt(v);
                              final minAge = _parseInt(_minAgeController.text);
                              
                              if (maxAge == null) {
                                return 'Please enter a valid number';
                              }
                              
                              if (maxAge < 18) {
                                return 'Maximum age must be 18 or above';
                              }
                              
                              if (maxAge > 50) {
                                return 'Maximum age must be 50 or below';
                              }
                              
                              if (minAge != null && maxAge < minAge) {
                                return 'Max age cannot be lower than min age';
                              }
                              
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _quotaController,
                      'Applicant Quota*',
                      hintText: 'e.g. 10',
                      keyboardType: TextInputType.number,
                      helperText: 'Maximum number of applicants you plan to approve',
                      showErrorBelow: true,
                      validator: (v) {
                        final requiredError = InputValidators.required(v, errorMessage: 'Required');
                        if (requiredError != null) return requiredError;
                        
                        if (v == null || v.trim().isEmpty) return null; // Already handled by required
                        
                        final quota = _parseInt(v);
                        if (quota == null) {
                          return 'Please enter a valid number';
                        }
                        
                        if (quota <= 0) {
                          return 'Applicant quota must be greater than 0';
                        }
                        
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                child: ImageUploadSection(
                  images: _attachments,
                  onImagesAdded: (newUrls) {
                    setState(() {
                      // Limit to maximum 3 images
                      final remainingSlots = 3 - _attachments.length;
                      if (remainingSlots > 0) {
                        _attachments.addAll(newUrls.take(remainingSlots));
                      }
                    });
                  },
                  onImageRemoved: (index) {
                    setState(() {
                      _attachments.removeAt(index);
                    });
                  },
                  title: 'Attachments',
                  description: 'Add images to showcase your project',
                  storageService: _storage,
                  uploadId: widget.existing?.id ?? _postId,
                  disabled: _saving,
                  maxImages: 3, // Maximum 3 images allowed
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(publish: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save as Draft',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canPublish() ? () => _save(publish: true) : null,
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
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  color: Colors.white
                                ),
                              )
                            : const Text(
                                'Publish Post',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability*',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {
              _jobTypeFocused = hasFocus;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _jobTypeFocused 
                    ? const Color(0xFF00C8A0) 
                    : Colors.grey[400]!,
                width: _jobTypeFocused ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<JobType>(
                  value: _jobType,
                  isExpanded: true,
                  focusNode: _jobTypeFocusNode,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  iconSize: 24,
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  items: JobType.values
                      .map((jt) => DropdownMenuItem<JobType>(
                            value: jt,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                jt.label,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _jobType = v ?? JobType.weekdays);
                    _jobTypeFocusNode.unfocus();
                    _onFieldChanged(); // Update button state
                  },
                  onTap: () {
                    if (!_jobTypeFocused) {
                      _jobTypeFocusNode.requestFocus();
                    }
                  },
                  selectedItemBuilder: (BuildContext context) {
                    return JobType.values.map((jt) {
                      return Container(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          jt.label,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _eventDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Type*',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _eventFocused 
                  ? const Color(0xFF00C8A0) 
                  : Colors.grey[400]!,
              width: _eventFocused ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
                child: _categoriesLoading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF00C8A0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Loading event types...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _categoriesError != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 16, color: Colors.red[400]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _categoriesError!,
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadCategories,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: const Color(0xFF00C8A0),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _categories.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.orange[400]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No event types available. Please contact support or try again later.',
                                        style: TextStyle(
                                          color: Colors.orange[600],
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loadCategories,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Retry',
                                        style: TextStyle(
                                          color: const Color(0xFF00C8A0),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButton<String>(
                                value: _selectedEvent,
                                focusNode: _eventFocusNode,
                                hint: Text(
                                  'Select event',
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
                                items: _categories
                                    .map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category.name,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            category.name,
                                            style: const TextStyle(color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedEvent = value;
                                      _eventFocused = false;
                                    });
                                    _eventFocusNode.unfocus();
                                    _onFieldChanged(); // Update button state
                                  }
                                },
                                onTap: () {
                                  setState(() {
                                    _eventFocused = true;
                                  });
                                },
                              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildTextField(
    TextEditingController controller, 
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
    String? hintText,
    String? helperText,
    String? prefixText,
    TextInputType? keyboardType,
    bool showErrorBelow = false, // New parameter to control error display
  }) {
    // If showErrorBelow is true, use FormField to control error display
    if (showErrorBelow) {
      // Create a unique key based on controller identity
      final fieldKey = controller == _budgetMinController 
          ? _budgetMinKey
          : (controller == _budgetMaxController 
              ? _budgetMaxKey
              : (controller == _minAgeController 
                  ? _minAgeKey
                  : (controller == _maxAgeController 
                      ? _maxAgeKey
                      : (controller == _quotaController
                          ? _quotaKey
                          : GlobalKey<FormFieldState<String>>()))));
      
      return FormField<String>(
        key: fieldKey,
        initialValue: controller.text,
        validator: validator,
        builder: (FormFieldState<String> field) {
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
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                onTap: () {
                  // Mark field as focused when clicked
                  if (!_focusedFields.contains(controller)) {
                    setState(() {
                      _focusedFields.add(controller);
                    });
                  }
                },
                onChanged: (value) {
                  field.didChange(value);
                  // Only validate if field has been focused
                  if (_focusedFields.contains(controller)) {
                    field.validate();
                  }
                },
                decoration: InputDecoration(
                  hintText: hintText,
                  helperText: helperText,
                  prefixText: prefixText,
                  errorText: null, // Don't show error in decoration
                  errorStyle: const TextStyle(height: 0), // Hide default error text
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: (field.hasError && _focusedFields.contains(controller)) 
                          ? Colors.red 
                          : Colors.grey[400]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: (field.hasError && _focusedFields.contains(controller)) 
                          ? Colors.red 
                          : const Color(0xFF00C8A0),
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
                ),
              ),
              // Only show error if field has been focused
              if (field.hasError && _focusedFields.contains(controller)) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    field.errorText ?? '',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
    }
    
    // Default behavior - show error in decoration
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            prefixText: prefixText,
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
          validator: validator,
        ),
      ],
    );
  }
}