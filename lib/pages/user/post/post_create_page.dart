import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _titleFieldKey = GlobalKey();
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
  TimeOfDay? _workTimeStart;
  TimeOfDay? _workTimeEnd;
  String? _selectedGender; // "male", "female", or "any"
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
  bool _genderFieldTouched = false; // Track if gender field has been interacted with
  bool _workTimeStartTouched = false; // Track if work time start has been interacted with
  bool _workTimeEndTouched = false; // Track if work time end has been interacted with
  
  // Real-time update related variables
  StreamSubscription<Post?>? _postStreamSubscription;
  Post? _latestPostFromFirestore;
  bool _hasExternalUpdate = false; // Track if there's an external update
  bool _isUserEditing = false; // Track if user is actively editing

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
      // Parse work time from string format "HH:mm"
      if (p.workTimeStart != null) {
        final parts = p.workTimeStart!.split(':');
        if (parts.length == 2) {
          _workTimeStart = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      if (p.workTimeEnd != null) {
        final parts = p.workTimeEnd!.split(':');
        if (parts.length == 2) {
          _workTimeEnd = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 17,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      _minAgeController.text = p.minAgeRequirement?.toString() ?? '';
      _maxAgeController.text = p.maxAgeRequirement?.toString() ?? '';
      _quotaController.text = p.applicantQuota?.toString() ?? '';
      _selectedGender = p.genderRequirement;
      _jobType = p.jobType;
      
      // Load existing attachments from Firestore (similar to post_details_page.dart)
      _loadExistingAttachments(p.id);
      
      // Start real-time listener for existing posts
      _startRealtimeListener(p.id);
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
        _isUserEditing = true;
        // Trigger rebuild to update button state
      });
      // Reset editing flag after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isUserEditing = false;
          });
        }
      });
    }
  }
  
  /// Start real-time listener for post updates from Firestore
  void _startRealtimeListener(String postId) {
    _postStreamSubscription = _service.streamPostById(postId).listen(
      (Post? updatedPost) {
        if (!mounted || updatedPost == null) return;
        
        // Store the latest post from Firestore
        _latestPostFromFirestore = updatedPost;
        
        // Only update UI if user is not actively editing
        // This prevents overwriting user's current input
        if (!_isUserEditing && !_saving) {
          _syncWithFirestoreData(updatedPost);
        } else {
          // Mark that there's an external update available
          if (mounted) {
            setState(() {
              _hasExternalUpdate = true;
            });
          }
        }
      },
      onError: (error) {
        debugPrint('Error in real-time post stream: $error');
      },
    );
  }
  
  /// Sync UI with Firestore data (only updates fields user is not editing)
  void _syncWithFirestoreData(Post updatedPost) {
    if (!mounted) return;
    
    setState(() {
      // Update title
      if (_titleController.text != updatedPost.title) {
        _titleController.text = updatedPost.title;
      }
      
      // Update description
      if (_descriptionController.text != updatedPost.description) {
        _descriptionController.text = updatedPost.description;
      }
      
      // Update budget
      final currentMinBudget = _parseDouble(_budgetMinController.text);
      if (currentMinBudget != updatedPost.budgetMin) {
        _budgetMinController.text = (updatedPost.budgetMin ?? '').toString();
      }
      final currentMaxBudget = _parseDouble(_budgetMaxController.text);
      if (currentMaxBudget != updatedPost.budgetMax) {
        _budgetMaxController.text = (updatedPost.budgetMax ?? '').toString();
      }
      
      // Update location
      if (_locationController.text != updatedPost.location) {
        _locationController.text = updatedPost.location;
        _latitude = updatedPost.latitude;
        _longitude = updatedPost.longitude;
      }
      
      // Update event type
      if (_selectedEvent != updatedPost.event && updatedPost.event.isNotEmpty) {
        _selectedEvent = updatedPost.event;
      }
      
      // Update dates
      if (_eventStartDate != updatedPost.eventStartDate) {
        _eventStartDate = updatedPost.eventStartDate;
      }
      if (_eventEndDate != updatedPost.eventEndDate) {
        _eventEndDate = updatedPost.eventEndDate;
      }
      
      // Update work times
      if (updatedPost.workTimeStart != null) {
        final parts = updatedPost.workTimeStart!.split(':');
        if (parts.length == 2) {
          final newTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
          if (_workTimeStart != newTime) {
            _workTimeStart = newTime;
          }
        }
      }
      if (updatedPost.workTimeEnd != null) {
        final parts = updatedPost.workTimeEnd!.split(':');
        if (parts.length == 2) {
          final newTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 17,
            minute: int.tryParse(parts[1]) ?? 0,
          );
          if (_workTimeEnd != newTime) {
            _workTimeEnd = newTime;
          }
        }
      }
      
      // Update age requirements
      final currentMinAge = _parseInt(_minAgeController.text);
      if (currentMinAge != updatedPost.minAgeRequirement) {
        _minAgeController.text = updatedPost.minAgeRequirement?.toString() ?? '';
      }
      final currentMaxAge = _parseInt(_maxAgeController.text);
      if (currentMaxAge != updatedPost.maxAgeRequirement) {
        _maxAgeController.text = updatedPost.maxAgeRequirement?.toString() ?? '';
      }
      
      // Update quota
      final currentQuota = _parseInt(_quotaController.text);
      if (currentQuota != updatedPost.applicantQuota) {
        _quotaController.text = updatedPost.applicantQuota?.toString() ?? '';
      }
      
      // Update gender
      if (_selectedGender != updatedPost.genderRequirement) {
        _selectedGender = updatedPost.genderRequirement;
      }
      
      // Update job type
      if (_jobType != updatedPost.jobType) {
        _jobType = updatedPost.jobType;
      }
      
      // Update tags
      if (updatedPost.tags.isNotEmpty) {
        _mapExistingTagsToCategories(updatedPost.tags);
      }
      
      // Update attachments
      if (updatedPost.attachments.isNotEmpty && _attachments != updatedPost.attachments) {
        _attachments.clear();
        _attachments.addAll(updatedPost.attachments);
      }
      
      _hasExternalUpdate = false;
    });
  }
  
  /// Refresh UI with latest Firestore data
  void _refreshFromFirestore() {
    if (_latestPostFromFirestore != null) {
      _syncWithFirestoreData(_latestPostFromFirestore!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已同步最新数据'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
          } else {
            // Validate that _selectedEvent exists in the loaded categories
            // If not, reset it to null to avoid DropdownButton assertion error
            if (_selectedEvent != null && _selectedEvent!.isNotEmpty) {
              final categoryNames = categories.map((c) => c.name).toList();
              if (!categoryNames.contains(_selectedEvent)) {
                _selectedEvent = null;
              }
            }
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
    // Cancel real-time stream subscription
    _postStreamSubscription?.cancel();
    
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
    _scrollController.dispose();
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
    if (minAge > 50) {
      return 'Minimum age must be 50 or below';
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
    
    // Validate work time (required fields)
    if (_workTimeStart == null) {
      return 'Work start time is required';
    }
    if (_workTimeEnd == null) {
      return 'Work end time is required';
    }
    // Check if end time is after start time
    // If the job post spans multiple days (including overnight), allow end time to be before or equal to start time
    final startMinutes = _workTimeStart!.hour * 60 + _workTimeStart!.minute;
    final endMinutes = _workTimeEnd!.hour * 60 + _workTimeEnd!.minute;
    
    // Calculate the duration between start and end dates
    if (_eventStartDate != null && _eventEndDate != null) {
      final duration = _eventEndDate!.difference(_eventStartDate!);
      final daysDifference = duration.inDays;
      
      // Only validate end time > start time if it's the same day (daysDifference == 0)
      // If the job spans multiple days (daysDifference >= 1), allow overnight shifts
      if (daysDifference == 0 && endMinutes <= startMinutes) {
        return 'Work end time must be after start time';
      }
    } else {
      // If dates are not set, use the original validation
      if (endMinutes <= startMinutes) {
        return 'Work end time must be after start time';
      }
    }
    
    // Validate gender requirement (required field)
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      return 'Gender requirement is required';
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
    
    // Check work time (required fields)
    if (_workTimeStart == null || _workTimeEnd == null) {
      return false;
    }
    
    // Check gender requirement (required field)
    if (_selectedGender == null || _selectedGender!.isEmpty) {
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
        // Also mark gender and time fields as touched
        if (mounted) {
          setState(() {
            _focusedFields.add(_budgetMinController);
            _focusedFields.add(_budgetMaxController);
            _focusedFields.add(_minAgeController);
            _focusedFields.add(_maxAgeController);
            _focusedFields.add(_quotaController);
            _genderFieldTouched = true;
            _workTimeStartTouched = true;
            _workTimeEndTouched = true;
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
      // For drafts, check if post is already published
      // If post is already published (not draft and status is active/pending), cannot save as draft
      if (widget.existing != null && 
          !widget.existing!.isDraft && 
          (widget.existing!.status == PostStatus.active || 
           widget.existing!.status == PostStatus.pending)) {
        if (mounted) {
          setState(() => _saving = false);
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Cannot save as draft. This post has already been published.',
          );
        }
        return;
      }
      
      // For drafts, only validate title field (required for draft)
      // Description and other fields are optional for drafts
      final formState = _formKey.currentState;
      if (formState == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      
      // Only validate title field for drafts
      if (_titleController.text.trim().isEmpty) {
        if (mounted) {
          setState(() => _saving = false);
          // Scroll to first field (Job Title) if validation fails
          _scrollToFirstField();
        }
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
    
    // Convert TimeOfDay to string format "HH:mm"
    String? workTimeStartStr;
    String? workTimeEndStr;
    if (_workTimeStart != null) {
      workTimeStartStr = '${_workTimeStart!.hour.toString().padLeft(2, '0')}:${_workTimeStart!.minute.toString().padLeft(2, '0')}';
    }
    if (_workTimeEnd != null) {
      workTimeEndStr = '${_workTimeEnd!.hour.toString().padLeft(2, '0')}:${_workTimeEnd!.minute.toString().padLeft(2, '0')}';
    }
    
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
      workTimeStart: workTimeStartStr,
      workTimeEnd: workTimeEndStr,
      genderRequirement: _selectedGender,
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

  /// Checks if the post is already published
  bool _isPostPublished() {
    if (widget.existing == null) return false;
    // Post is considered published if it's not a draft and status is active or pending
    return !widget.existing!.isDraft && 
           (widget.existing!.status == PostStatus.active || 
            widget.existing!.status == PostStatus.pending);
  }

  /// Scrolls to the first field (Job Title) when validation fails for draft
  void _scrollToFirstField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_titleFieldKey.currentContext != null && _scrollController.hasClients) {
        try {
          Scrollable.ensureVisible(
            _titleFieldKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        } catch (e) {
          debugPrint('Error scrolling to first field: $e');
          // Fallback: scroll to top
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      } else if (_scrollController.hasClients) {
        // Fallback: scroll to top if field key not found
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
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
        actions: [
          // Show refresh button if there's an external update
          if (widget.existing != null && _hasExternalUpdate)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: _refreshFromFirestore,
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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
                      key: _titleFieldKey,
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerField(
                            label: 'Work Start Time*',
                            time: _workTimeStart,
                            onTimeSelected: (time) {
                              setState(() {
                                _workTimeStart = time;
                              });
                              _onFieldChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePickerField(
                            label: 'Work End Time*',
                            time: _workTimeEnd,
                            onTimeSelected: (time) {
                              setState(() {
                                _workTimeEnd = time;
                              });
                              _onFieldChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGenderDropdown(),
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
                              
                              if (minAge > 50) {
                                return 'Minimum age must be 50 or below';
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
                        onPressed: (_saving || _isPostPublished()) ? null : () => _save(publish: false),
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
                                value: _selectedEvent != null && 
                                       _categories.any((c) => c.name == _selectedEvent)
                                    ? _selectedEvent
                                    : null,
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
    Key? key,
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
                key: key,
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
          key: key,
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

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender Requirement*',
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
              color: (_selectedGender == null && _genderFieldTouched) ? Colors.red : Colors.grey[400]!,
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
                  'Select gender requirement',
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
                    value: 'any',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Any'),
                    ),
                  ),
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
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                    _genderFieldTouched = true;
                  });
                  _onFieldChanged();
                },
                onTap: () {
                  if (!_genderFieldTouched) {
                    setState(() {
                      _genderFieldTouched = true;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        if (_selectedGender == null && _genderFieldTouched) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Required',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TimeOfDay? time,
    required Function(TimeOfDay?) onTimeSelected,
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
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final isStartTime = label.contains('Start');
            if (isStartTime && !_workTimeStartTouched) {
              setState(() {
                _workTimeStartTouched = true;
              });
            } else if (!isStartTime && !_workTimeEndTouched) {
              setState(() {
                _workTimeEndTouched = true;
              });
            }
            
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: time ?? TimeOfDay(hour: 9, minute: 0),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: const Color(0xFF00C8A0),
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onTimeSelected(picked);
            }
          },
          child: Builder(
            builder: (context) {
              final isStartTime = label.contains('Start');
              final isTouched = isStartTime ? _workTimeStartTouched : _workTimeEndTouched;
              final showError = time == null && isTouched;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: showError ? Colors.red : Colors.grey[400]!,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: showError ? Colors.red : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    time == null
                        ? 'time'
                        : time.format(context),
                    style: TextStyle(
                      color: time == null ? Colors.grey[400] : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          );
            },
          ),
        ),
        Builder(
          builder: (context) {
            final isStartTime = label.contains('Start');
            final isTouched = isStartTime ? _workTimeStartTouched : _workTimeEndTouched;
            if (time == null && isTouched) {
              return Column(
                children: [
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Required',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}