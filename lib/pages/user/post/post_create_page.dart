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
  String? _selectedGender;
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
  bool _hasPopped = false;
  final StorageService _storage = StorageService();
  final List<String> _attachments = <String>[];
  List<Category> _categories = <Category>[];
  bool _categoriesLoading = true;
  String? _categoriesError;
  bool _hasMappedExistingTags = false;
  final FocusNode _jobTypeFocusNode = FocusNode();
  final FocusNode _eventFocusNode = FocusNode();
  bool _jobTypeFocused = false;
  bool _eventFocused = false;
  late String _postId;
  final GlobalKey<FormFieldState<String>> _budgetMinKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _budgetMaxKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _minAgeKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _maxAgeKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _quotaKey = GlobalKey<FormFieldState<String>>();
  //tracking
  final Set<TextEditingController> _focusedFields = {};
  bool _genderFieldTouched = false;
  bool _workTimeStartTouched = false;
  bool _workTimeEndTouched = false;

  StreamSubscription<Post?>? _postStreamSubscription;
  Post? _latestPostFromFirestore;
  bool _hasExternalUpdate = false;
  bool _isUserEditing = false;
  Timer? _editingTimer;

  @override
  void initState() {
    super.initState();
    _postId = widget.existing?.id ?? FirebaseFirestore.instance.collection('posts').doc().id;
    _loadCategories();
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
      //time parsing
      if (p.workTimeStart != null) {
        final parts = p.workTimeStart!.split(':');
        if (parts.length == 2) {
          _workTimeStart = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
        }
      }
      if (p.workTimeEnd != null) {
        final parts = p.workTimeEnd!.split(':');
        if (parts.length == 2) {
          _workTimeEnd = TimeOfDay(hour: int.tryParse(parts[0]) ?? 17, minute: int.tryParse(parts[1]) ?? 0);
        }
      }
      _minAgeController.text = p.minAgeRequirement?.toString() ?? '';
      _maxAgeController.text = p.maxAgeRequirement?.toString() ?? '';
      _quotaController.text = p.applicantQuota?.toString() ?? '';
      final validGenders = ['any', 'male', 'female'];
      _selectedGender = (p.genderRequirement != null && validGenders.contains(p.genderRequirement))
          ? p.genderRequirement
          : null;
      _jobType = p.jobType;
      _loadExistingAttachments(p.id);
      _startRealtimeListener(p.id);
    }

    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);

    _budgetMinController.addListener(() {
      _onFieldChanged();
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
      _budgetMaxKey.currentState?.validate();
    });
    _budgetMaxController.addListener(_onFieldChanged);

    _minAgeController.addListener(() {
      _onFieldChanged();
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
      _maxAgeKey.currentState?.validate();
    });
    _maxAgeController.addListener(_onFieldChanged);

    _quotaController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!mounted) return;
  
    _editingTimer?.cancel();
    _isUserEditing = true;
    setState(() {});
    _editingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isUserEditing = false;
        });
      }
    });
  }

  void _startRealtimeListener(String postId) {
    _postStreamSubscription = _service
        .streamPostById(postId)
        .listen(
          (Post? updatedPost) {
            if (!mounted || updatedPost == null) return;
            //store new data
            _latestPostFromFirestore = updatedPost;
            if (!_isUserEditing && !_saving) {
              _syncWithFirestoreData(updatedPost);
            } else {
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

  void _syncWithFirestoreData(Post updatedPost) {
    if (!mounted) return;
    
    bool needsRebuild = false;
  
    if (_titleController.text != updatedPost.title) {
      final selection = _titleController.selection;
      _titleController.text = updatedPost.title;
      if (selection.isValid && selection.end <= updatedPost.title.length) {
        _titleController.selection = selection;
      }
      needsRebuild = true;
    }
    

    if (_descriptionController.text != updatedPost.description) {
      final selection = _descriptionController.selection;
      _descriptionController.text = updatedPost.description;

      if (selection.isValid && selection.end <= updatedPost.description.length) {
        _descriptionController.selection = selection;
      }
      needsRebuild = true;
    }
    
    final currentMinBudget = _parseDouble(_budgetMinController.text);
    if (currentMinBudget != updatedPost.budgetMin) {
      final selection = _budgetMinController.selection;
      _budgetMinController.text = (updatedPost.budgetMin ?? '').toString();
      if (selection.isValid) {
        _budgetMinController.selection = selection;
      }
      needsRebuild = true;
    }
    final currentMaxBudget = _parseDouble(_budgetMaxController.text);
    if (currentMaxBudget != updatedPost.budgetMax) {
      final selection = _budgetMaxController.selection;
      _budgetMaxController.text = (updatedPost.budgetMax ?? '').toString();
      if (selection.isValid) {
        _budgetMaxController.selection = selection;
      }
      needsRebuild = true;
    }
    
    if (_locationController.text != updatedPost.location) {
      final selection = _locationController.selection;
      _locationController.text = updatedPost.location;
      if (selection.isValid && selection.end <= updatedPost.location.length) {
        _locationController.selection = selection;
      }
      _latitude = updatedPost.latitude;
      _longitude = updatedPost.longitude;
      needsRebuild = true;
    }
    
    if (_selectedEvent != updatedPost.event && updatedPost.event.isNotEmpty) {
      _selectedEvent = updatedPost.event;
      needsRebuild = true;
    }
    
    if (_eventStartDate != updatedPost.eventStartDate) {
      _eventStartDate = updatedPost.eventStartDate;
      needsRebuild = true;
    }
    if (_eventEndDate != updatedPost.eventEndDate) {
      _eventEndDate = updatedPost.eventEndDate;
      needsRebuild = true;
    }
    
    if (updatedPost.workTimeStart != null) {
      final parts = updatedPost.workTimeStart!.split(':');
      if (parts.length == 2) {
        final newTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
        if (_workTimeStart != newTime) {
          _workTimeStart = newTime;
          needsRebuild = true;
        }
      }
    }
    if (updatedPost.workTimeEnd != null) {
      final parts = updatedPost.workTimeEnd!.split(':');
      if (parts.length == 2) {
        final newTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 17, minute: int.tryParse(parts[1]) ?? 0);
        if (_workTimeEnd != newTime) {
          _workTimeEnd = newTime;
          needsRebuild = true;
        }
      }
    }
    
    final currentMinAge = _parseInt(_minAgeController.text);
    if (currentMinAge != updatedPost.minAgeRequirement) {
      final selection = _minAgeController.selection;
      _minAgeController.text = updatedPost.minAgeRequirement?.toString() ?? '';
      if (selection.isValid) {
        _minAgeController.selection = selection;
      }
      needsRebuild = true;
    }
    final currentMaxAge = _parseInt(_maxAgeController.text);
    if (currentMaxAge != updatedPost.maxAgeRequirement) {
      final selection = _maxAgeController.selection;
      _maxAgeController.text = updatedPost.maxAgeRequirement?.toString() ?? '';
      if (selection.isValid) {
        _maxAgeController.selection = selection;
      }
      needsRebuild = true;
    }
    
    final currentQuota = _parseInt(_quotaController.text);
    if (currentQuota != updatedPost.applicantQuota) {
      final selection = _quotaController.selection;
      _quotaController.text = updatedPost.applicantQuota?.toString() ?? '';
      if (selection.isValid) {
        _quotaController.selection = selection;
      }
      needsRebuild = true;
    }

    final validGenders = ['any', 'male', 'female'];
    if (_selectedGender != updatedPost.genderRequirement) {
      _selectedGender =
          (updatedPost.genderRequirement != null && validGenders.contains(updatedPost.genderRequirement))
          ? updatedPost.genderRequirement
          : null;
      needsRebuild = true;
    }
    
    if (_jobType != updatedPost.jobType) {
      _jobType = updatedPost.jobType;
      needsRebuild = true;
    }
    
    if (updatedPost.tags.isNotEmpty) {
      _tagService.getActiveTagCategoriesWithTags().then((tagCategoriesWithTags) {
        if (mounted) {
          _mapExistingTagsToCategories(updatedPost.tags, tagCategoriesWithTags);
        }
      });
    }
    
    if (updatedPost.attachments.isNotEmpty && _attachments != updatedPost.attachments) {
      _attachments.clear();
      _attachments.addAll(updatedPost.attachments);
      needsRebuild = true;
    }
    
    _hasExternalUpdate = false;
    
    //refrsh when changed
    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExistingAttachments(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      final data = doc.data();
      if (data != null && data['attachments'] != null) {
        final attachments = data['attachments'] as List?;
        if (attachments != null && attachments.isNotEmpty) {
          //extract base64 strings
          final List<String> base64Strings = [];
          for (final a in attachments) {
            if (a is Map) {
              final base64 = a['base64'] as String?;
              if (base64 != null && base64.isNotEmpty) {
                base64Strings.add(base64);
              }
            } else if (a is String) {
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

  void _mapExistingTagsToCategories(List<String> existingTagNames, Map<TagCategory, List<Tag>> tagCategoriesWithTags) {
    final Map<String, List<String>> mappedTags = {};
    final Map<String, String> tagNameToCategoryId = {};
 
    for (final entry in tagCategoriesWithTags.entries) {
      final category = entry.key;
      final tags = entry.value;
      for (final tag in tags.where((tag) => tag.isActive)) {
        tagNameToCategoryId[tag.name] = category.id;
      }
    }

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
    _editingTimer?.cancel();
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

  String? _validateRequiredFieldsForPublish() {
    //title and desc
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      String missingFields = '';
      if (_titleController.text.trim().isEmpty) missingFields += 'Title, ';
      if (_descriptionController.text.trim().isEmpty) missingFields += 'Description, ';
      if (_budgetMinController.text.trim().isEmpty) missingFields += 'Min Budget, ';
      if (_budgetMaxController.text.trim().isEmpty) missingFields += 'Max Budget, ';
      if (_minAgeController.text.trim().isEmpty) missingFields += 'Min Age, ';
      if (_maxAgeController.text.trim().isEmpty) missingFields += 'Max Age, ';
      if (_quotaController.text.trim().isEmpty) missingFields += 'Applicant Quota, ';
      
      if (missingFields.isNotEmpty) {
        missingFields = missingFields.substring(0, missingFields.length - 2);
        return 'Please fill in the following required fields: $missingFields';
      }
      return 'Please fill in all required form fields';
    }
 
    if (_locationController.text.trim().isEmpty) {
      return 'Location is required';
    }
    if (_latitude == null || _longitude == null) {
      return 'Please select a valid location from the suggestions';
    }
   
    if (_selectedEvent == null || _selectedEvent!.isEmpty) {
      return 'Event type is required';
    }

    if (_eventStartDate == null) {
      return 'Event start date is required';
    }
    if (_eventEndDate == null) {
      return 'Event end date is required';
    }
    //prevent event start date from now day
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventStartDateOnly = DateTime(_eventStartDate!.year, _eventStartDate!.month, _eventStartDate!.day);
    if (eventStartDateOnly.isAtSameMomentAs(today)) {
      return 'Event start date cannot be today';
    }
    if (_eventEndDate!.isBefore(_eventStartDate!)) {
      return 'Event end date cannot be before start date';
    }
   
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
    if (minAge < 18) {
      return 'Minimum age must be 18 or above';
    }
    if (minAge > 50) {
      return 'Minimum age must be 50 or below';
    }
    if (maxAge < 18) {
      return 'Maximum age must be 18 or above';
    }
    if (maxAge > 50) {
      return 'Maximum age must be 50 or below';
    }
    if (maxAge < minAge) {
      return 'Maximum age cannot be lower than minimum age';
    }
    if (_quotaController.text.trim().isEmpty) {
      return 'Applicant quota is required';
    }
    final quota = _parseInt(_quotaController.text);
    if (quota == null || quota <= 0) {
      return 'Please enter a valid applicant quota (must be greater than 0)';
    }

    if (_workTimeStart == null) {
      return 'Work start time is required';
    }
    if (_workTimeEnd == null) {
      return 'Work end time is required';
    }
    //check if end time after start time  overnight time equals
    final startMinutes = _workTimeStart!.hour * 60 + _workTimeStart!.minute;
    final endMinutes = _workTimeEnd!.hour * 60 + _workTimeEnd!.minute;

    if (_eventStartDate != null && _eventEndDate != null) {
      final duration = _eventEndDate!.difference(_eventStartDate!);
      final daysDifference = duration.inDays;

      if (daysDifference == 0 && endMinutes <= startMinutes) {
        return 'Work end time must be after start time';
      }
    } else {
      if (endMinutes <= startMinutes) {
        return 'Work end time must be after start time';
      }
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      return 'Gender requirement is required';
    }
    return null;
  }

  bool _canPublish() {
    if (_saving) return false;
    final formState = _formKey.currentState;
    if (formState == null) return false;

    if (_titleController.text.trim().isEmpty) {
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      return false;
    }
    if (_locationController.text.trim().isEmpty || _latitude == null || _longitude == null) {
      return false;
    }
    if (_selectedEvent == null || _selectedEvent!.isEmpty) {
      return false;
    }
    if (_eventStartDate == null || _eventEndDate == null) {
      return false;
    }
    if (_budgetMinController.text.trim().isEmpty || _budgetMaxController.text.trim().isEmpty) {
      return false;
    }
    if (_minAgeController.text.trim().isEmpty || _maxAgeController.text.trim().isEmpty) {
      return false;
    }
    if (_quotaController.text.trim().isEmpty) {
      return false;
    }
    if (_workTimeStart == null || _workTimeEnd == null) {
      return false;
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save({required bool publish}) async {
    //prevent multi action
    if (_saving) return;
    _saving = true;
    if (mounted) {
      setState(() {}); 
    }

    //verify
    if (publish) {
      try {
        final userDoc = await _authService.getUserDoc();
        final userData = userDoc.data();
        final isVerified = userData?['isVerified'] as bool? ?? false;
        
        if (!isVerified) {
          if (mounted) {
            setState(() => _saving = false);
            DialogUtils.showWarningMessage(
              context: context,
              message: 'Please verify your account before creating a post. Go to your profile to complete verification.',
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Failed to verify account status. Please try again.',
          );
        }
        return;
      }
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
      _budgetMinKey.currentState?.didChange(_budgetMinController.text);
      _budgetMinKey.currentState?.validate();
      _budgetMaxKey.currentState?.didChange(_budgetMaxController.text);
      _budgetMaxKey.currentState?.validate();
      _minAgeKey.currentState?.didChange(_minAgeController.text);
      _minAgeKey.currentState?.validate();
      _maxAgeKey.currentState?.didChange(_maxAgeController.text);
      _maxAgeKey.currentState?.validate();
      _quotaKey.currentState?.didChange(_quotaController.text);
      _quotaKey.currentState?.validate();

      final formState = _formKey.currentState;
      if (formState != null && !formState.validate()) {
        if (mounted) setState(() => _saving = false);
        return;
      }

      final validationError = _validateRequiredFieldsForPublish();
      if (validationError != null) {
        if (mounted) setState(() => _saving = false);
        DialogUtils.showWarningMessage(context: context, message: validationError);
        return;
      }
    } else {
      //disable drafting for published posts
      if (widget.existing != null &&
          !widget.existing!.isDraft &&
          (widget.existing!.status == PostStatus.active || widget.existing!.status == PostStatus.pending)) {
        if (mounted) {
          setState(() => _saving = false);
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Cannot save as draft. This post has already been published.',
          );
        }
        return;
      }

      if (_eventStartDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final eventStartDateOnly = DateTime(_eventStartDate!.year, _eventStartDate!.month, _eventStartDate!.day);
        if (eventStartDateOnly.isAtSameMomentAs(today)) {
          if (mounted) {
            setState(() => _saving = false);
            DialogUtils.showWarningMessage(context: context, message: 'Event start date cannot be today');
          }
          return;
        }
      }

      final formState = _formKey.currentState;
      if (formState == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
//draft title
      if (_titleController.text.trim().isEmpty) {
        if (mounted) {
          setState(() => _saving = false);
          _scrollToFirstField();
        }
        return;
      }
    }

    if (!mounted) {
      _saving = false;
      return;
    }

    final String id = widget.existing?.id ?? _postId;
    final selectedTags = _selectedTags.values.expand((list) => list).toList();
    final minAge = _parseInt(_minAgeController.text);
    final maxAge = _parseInt(_maxAgeController.text);
    final quota = _parseInt(_quotaController.text);

    String? workTimeStartStr;
    String? workTimeEndStr;
    if (_workTimeStart != null) {
      workTimeStartStr =
          '${_workTimeStart!.hour.toString().padLeft(2, '0')}:${_workTimeStart!.minute.toString().padLeft(2, '0')}';
    }
    if (_workTimeEnd != null) {
      workTimeEndStr =
          '${_workTimeEnd!.hour.toString().padLeft(2, '0')}:${_workTimeEnd!.minute.toString().padLeft(2, '0')}';
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
      _hasPopped = true;
      Navigator.pop(context, publish);
    } catch (e) {
      if (!mounted || _hasPopped) return;

      String errorMessage = 'Failed to save: $e';
      final errorString = e.toString();

      final isSizeError =
          errorString.contains('exceeds the maximum allowed size') ||
          errorString.contains('cannot be written because its size') ||
          errorString.contains('invalid-argument') ||
          errorString.contains('INVALID_ARGUMENT');

      if (isSizeError) {
        RegExpMatch? sizeMatch = RegExp(r'size \((\d+(?:,\d+)*) bytes\)').firstMatch(errorString);
        RegExpMatch? maxSizeMatch = RegExp(r'maximum allowed size of (\d+(?:,\d+)*) bytes').firstMatch(errorString);
        if (sizeMatch == null) {
          sizeMatch = RegExp(r'size \((\d+) bytes\)').firstMatch(errorString);
        }
        if (maxSizeMatch == null) {
          maxSizeMatch = RegExp(r'maximum.*?(\d+) bytes').firstMatch(errorString);
        }

        //extract large numbers
        if (sizeMatch == null || maxSizeMatch == null) {
          final allLargeNumbers = RegExp(r'\d{6,}').allMatches(errorString).toList();
          if (allLargeNumbers.isNotEmpty) {
            final numbers = allLargeNumbers.map((m) => int.parse(m.group(0)!)).toList()..sort((a, b) => b.compareTo(a));
            if (numbers.isNotEmpty && numbers[0] > 1000000) {
              final actualSize = numbers[0];
              final maxSize = 1048576;
              final exceededSize = actualSize - maxSize;

              errorMessage = _buildSizeErrorMessage(actualSize, maxSize, exceededSize);
            } else {
              errorMessage = _buildGenericSizeErrorMessage();
            }
          } else {
            errorMessage = _buildGenericSizeErrorMessage();
          }
        } else {
          //pasing size
          try {
            String actualSizeStr = sizeMatch.groupCount > 0 && sizeMatch.group(1) != null
                ? sizeMatch.group(1)!.replaceAll(',', '').trim()
                : sizeMatch.group(0)!.replaceAll(RegExp(r'[^\d]'), '').trim();

            String maxSizeStr = maxSizeMatch.groupCount > 0 && maxSizeMatch.group(1) != null
                ? maxSizeMatch.group(1)!.replaceAll(',', '').trim()
                : maxSizeMatch.group(0)!.replaceAll(RegExp(r'[^\d]'), '').trim();

            final actualSize = int.parse(actualSizeStr);
            final maxSize = int.parse(maxSizeStr);
            final exceededSize = actualSize - maxSize;

            errorMessage = _buildSizeErrorMessage(actualSize, maxSize, exceededSize);
          } catch (_) {
            //alternative to extarct large numbers
            final allLargeNumbers = RegExp(r'\d{6,}').allMatches(errorString).toList();
            if (allLargeNumbers.isNotEmpty) {
              final numbers = allLargeNumbers.map((m) => int.parse(m.group(0)!)).toList()
                ..sort((a, b) => b.compareTo(a));
              if (numbers.isNotEmpty && numbers[0] > 1000000) {
                errorMessage = _buildSizeErrorMessage(numbers[0], 1048576, numbers[0] - 1048576);
              } else {
                errorMessage = _buildGenericSizeErrorMessage();
              }
            } else {
              errorMessage = _buildGenericSizeErrorMessage();
            }
          }
        }
      }

      DialogUtils.showWarningMessage(context: context, message: errorMessage, duration: const Duration(seconds: 8));
    } finally {
      if (mounted && !_hasPopped) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  //format bytes to readable string
  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
  }

  //size error message
  String _buildSizeErrorMessage(int actualSize, int maxSize, int exceededSize) {
    final actualSizeReadable = _formatBytes(actualSize);
    final maxSizeReadable = _formatBytes(maxSize);
    final exceededSizeReadable = _formatBytes(exceededSize);
    final recommendedMax = (maxSize * 0.9).round();
    final recommendedMaxReadable = _formatBytes(recommendedMax);

    return 'Image Size exceeds the limit!\n\n'
        'Current size: $actualSizeReadable\n'
        'Maximum allowed: $maxSizeReadable\n'
        'Exceeded by: $exceededSizeReadable\n\n'
        'Suggestion:\n'
        'Please remove some images or select smaller photos.\n'
        'Recommended total size: less than $recommendedMaxReadable.';
  }

  //size error message
  String _buildGenericSizeErrorMessage() {
    return 'Image Size exceeds the limit!\n\n'
        'Document size exceeds the 1MB limit.\n\n'
        'Please remove some images or select smaller photos.\n'
        'Recommended total size: less than 900 KB.';
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

  bool _isPostPublished() {
    if (widget.existing == null) return false;
    return !widget.existing!.isDraft &&
        (widget.existing!.status == PostStatus.active || widget.existing!.status == PostStatus.pending);
  }

  //scrolls to the first field when draft
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
          if (_scrollController.hasClients) {
            _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        }
      } else if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });
  }

  void _onTagCategoryChanged(String categoryId, List<String> values) {
    final currentValues = _selectedTags[categoryId] ?? <String>[];
    final valuesChanged = currentValues.length != values.length ||
        !currentValues.every((v) => values.contains(v)) ||
        !values.every((v) => currentValues.contains(v));
    
    if (!valuesChanged && values.isEmpty == currentValues.isEmpty) {
      return; 
    }
    
    setState(() {
      final next = Map<String, List<String>>.from(_selectedTags);
      if (values.isEmpty) {
        next.remove(categoryId);
      } else {
        next[categoryId] = values;
      }
      _selectedTags = next;
    });
    _onFieldChanged(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Create New Post' : 'Edit Post',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.existing == null ? Icons.add_circle_outline : Icons.edit_outlined,
                          size: 20,
                          color: const Color(0xFF00C8A0),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.existing == null ? 'Create New Job Post' : 'Edit Job Post',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.existing == null
                          ? 'Fill in the details to create a new job posting'
                          : 'Update your job post information',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _titleController,
                      'Job Title*',
                      key: _titleFieldKey,
                      validator: (v) => InputValidators.required(v, errorMessage: 'Required'),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _descriptionController,
                      'Description*',
                      maxLines: 5,
                      validator: (v) => InputValidators.required(v, errorMessage: 'Required'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              //budget  location
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _budgetMinController,
                            'Min Budget*',
                            prefixText: 'RM ',
                            keyboardType: TextInputType.number,
                            showErrorBelow: true,
                            validator: (v) => InputValidators.required(v, errorMessage: 'Required'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            _budgetMaxController,
                            'Max Budget*',
                            prefixText: 'RM ',
                            keyboardType: TextInputType.number,
                            showErrorBelow: true,
                            validator: (v) {
                              final requiredError = InputValidators.required(v, errorMessage: 'Required');
                              if (requiredError != null) return requiredError;

                              if (v == null || v.trim().isEmpty) return null; 

                              final maxBudget = _parseDouble(v);
                              final minBudget = _parseDouble(_budgetMinController.text);

                              if (maxBudget == null) {
                                return 'Please enter a valid number';
                              }

                              if (minBudget != null && maxBudget < minBudget) {
                                return 'Max budget cannot be lower than min budget';
                              }

                              return null;
                            },
                          ),
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
                        _onFieldChanged(); 
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              //job details
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
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
                                if (_eventEndDate != null && _eventEndDate!.isBefore(date)) {
                                  _eventEndDate = null;
                                }
                              });
                              _onFieldChanged();
                            },
                            firstDate: DateTime.now().add(const Duration(days: 1)), //at least tomorrow
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            required: true,
                            helperText: 'At least 1 day from today',
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
                            firstDate:
                                _eventStartDate ??
                                DateTime.now().add(
                                  const Duration(days: 1),
                                ), 
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            required: true,
                            helperText: ' ', 
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

                    _TagSelectionStreamBuilder(
                      tagService: _tagService,
                      selections: _selectedTags,
                      onCategoryChanged: _onTagCategoryChanged,
                      existing: widget.existing,
                      onTagsMapped: () {
                        if (mounted) {
                          setState(() {
                            _hasMappedExistingTags = true;
                          });
                        }
                      },
                      hasMappedExistingTags: _hasMappedExistingTags,
                      mapExistingTagsToCategories: _mapExistingTagsToCategories,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              //candidate
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
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
                              if (v == null || v.trim().isEmpty) return null;
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
                              final maxAge = _parseInt(_maxAgeController.text);
                              if (maxAge != null && minAge > maxAge) {
                                return 'Min age cannot be higher than max age';
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

                              if (v == null || v.trim().isEmpty) return null;

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

                        if (v == null || v.trim().isEmpty) return null;

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
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: ImageUploadSection(
                  images: _attachments,
                  onImagesAdded: (newUrls) {
                    setState(() {
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
                  title: 'Attachments (Optional)',
                  description: 'Add images to showcase your project (optional)',
                  storageService: _storage,
                  uploadId: widget.existing?.id ?? _postId,
                  disabled: _saving,
                  maxImages: 3, 
                ),
              ),
              const SizedBox(height: 24),

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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save as Draft', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_authService.currentUserId)
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          final isVerified = userSnapshot.hasData
                              ? (userSnapshot.data?.data()?['isVerified'] as bool? ?? false)
                              : false;
                          
                          final canPublish = _canPublish() && isVerified;
                          
                          return ElevatedButton(
                            onPressed: canPublish ? () => _save(publish: true) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canPublish
                                  ? const Color(0xFF00C8A0)
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              shadowColor: canPublish
                                  ? const Color(0xFF00C8A0).withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    isVerified ? 'Publish Post' : 'Verify to Publish',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                          );
                        },
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
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
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
                color: _jobTypeFocused ? const Color(0xFF00C8A0) : Colors.grey[400]!,
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
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  items: JobType.values
                      .map(
                        (jt) => DropdownMenuItem<JobType>(
                          value: jt,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(jt.label, style: const TextStyle(color: Colors.black)),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _jobType = v ?? JobType.weekdays);
                    _jobTypeFocusNode.unfocus();
                    _onFieldChanged();
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
                        child: Text(jt.label, style: const TextStyle(color: Colors.black, fontSize: 16)),
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
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _eventFocused ? const Color(0xFF00C8A0) : Colors.grey[400]!,
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
                              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF00C8A0)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Loading event types...',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                              style: TextStyle(color: Colors.red[600], fontSize: 13),
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
                            child: Text('Retry', style: TextStyle(color: const Color(0xFF00C8A0), fontSize: 12)),
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
                              style: TextStyle(color: Colors.orange[600], fontSize: 13),
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
                            child: Text('Retry', style: TextStyle(color: const Color(0xFF00C8A0), fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  : DropdownButton<String>(
                      value: _selectedEvent != null && _categories.any((c) => c.name == _selectedEvent)
                          ? _selectedEvent
                          : null,
                      focusNode: _eventFocusNode,
                      hint: Text('Select event', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      iconSize: 24,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category.name,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(category.name, style: const TextStyle(color: Colors.black)),
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
                          _onFieldChanged(); 
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
    bool showErrorBelow = false, 
  }) {
    if (showErrorBelow) {
      final fieldKey = controller == _budgetMinController
          ? _budgetMinKey
          : (controller == _budgetMaxController
                ? _budgetMaxKey
                : (controller == _minAgeController
                      ? _minAgeKey
                      : (controller == _maxAgeController
                            ? _maxAgeKey
                            : (controller == _quotaController ? _quotaKey : GlobalKey<FormFieldState<String>>()))));

      return FormField<String>(
        key: fieldKey,
        initialValue: controller.text,
        validator: (value) {
          return validator?.call(controller.text);
        },
        builder: (FormFieldState<String> field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: key,
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                onTap: () {
                  if (!_focusedFields.contains(controller)) {
                    setState(() {
                      _focusedFields.add(controller);
                    });
                  }
                },
                onChanged: (value) {
                  field.didChange(value);
                  if (_focusedFields.contains(controller)) {
                    field.validate();
                  }
                },
                decoration: InputDecoration(
                  hintText: hintText,
                  helperText: helperText,
                  prefixText: prefixText,
                  errorText: null,
                  errorStyle: const TextStyle(height: 0), 
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: (field.hasError && _focusedFields.contains(controller)) ? Colors.red : Colors.grey[400]!,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              //show error when focused
              if (field.hasError && _focusedFields.contains(controller)) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(field.errorText ?? '', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    const validGenders = ['any', 'male', 'female'];
    final String? safeSelectedGender = (_selectedGender != null && validGenders.contains(_selectedGender))? _selectedGender : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender Requirement*',
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: (safeSelectedGender == null && _genderFieldTouched) ? Colors.red : Colors.grey[400]!,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeSelectedGender,
                hint: Text('Select gender requirement', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                iconSize: 24,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                items: [
                  DropdownMenuItem<String>(
                    value: 'any',
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Any')),
                  ),
                  DropdownMenuItem<String>(
                    value: 'male',
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Male')),
                  ),
                  DropdownMenuItem<String>(
                    value: 'female',
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Female')),
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
        if (safeSelectedGender == null && _genderFieldTouched) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('Required', style: const TextStyle(color: Colors.red, fontSize: 12)),
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
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
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
                  border: Border.all(color: showError ? Colors.red : Colors.grey[400]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: showError ? Colors.red : Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        time == null ? 'time' : time.format(context),
                        style: TextStyle(color: time == null ? Colors.grey[400] : Colors.black, fontSize: 16),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
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
                    child: Text('Required', style: const TextStyle(color: Colors.red, fontSize: 12)),
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

class _TagSelectionStreamBuilder extends StatefulWidget {
  const _TagSelectionStreamBuilder({
    required this.tagService,
    required this.selections,
    required this.onCategoryChanged,
    this.existing,
    required this.onTagsMapped,
    required this.hasMappedExistingTags,
    required this.mapExistingTagsToCategories,
  });

  final TagService tagService;
  final TagSelectionMap selections;
  final void Function(String categoryId, List<String> values) onCategoryChanged;
  final Post? existing;
  final VoidCallback onTagsMapped;
  final bool hasMappedExistingTags;
  final void Function(List<String> existingTagNames, Map<TagCategory, List<Tag>> tagCategoriesWithTags) mapExistingTagsToCategories;

  @override
  State<_TagSelectionStreamBuilder> createState() => _TagSelectionStreamBuilderState();
}

class _TagSelectionStreamBuilderState extends State<_TagSelectionStreamBuilder> {
  Map<TagCategory, List<Tag>>? _cachedData;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<TagCategory, List<Tag>>>(
      stream: widget.tagService.streamActiveTagCategoriesWithTags(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_cachedData != null) {
            return TagSelectionSection(
              selections: widget.selections,
              onCategoryChanged: widget.onCategoryChanged,
              tagCategoriesWithTags: _cachedData!,
              loading: false,
            );
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(
                color: Color(0xFF00C8A0),
              ),
            ),
          );
        }

        final tagCategoriesWithTags = snapshot.data ?? {};
        
        if (tagCategoriesWithTags.isNotEmpty) {
          _cachedData = tagCategoriesWithTags;
        } else if (_cachedData == null) {
          _cachedData = {};
        }
        
        //existing tags when data first loads 
        if (widget.existing != null && 
            widget.existing!.tags.isNotEmpty && 
            tagCategoriesWithTags.isNotEmpty &&
            widget.selections.isEmpty &&
            !widget.hasMappedExistingTags) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !widget.hasMappedExistingTags) {
              widget.mapExistingTagsToCategories(widget.existing!.tags, tagCategoriesWithTags);
              widget.onTagsMapped();
            }
          });
        }

        return TagSelectionSection(
          selections: widget.selections,
          onCategoryChanged: widget.onCategoryChanged,
          tagCategoriesWithTags: _cachedData ?? tagCategoriesWithTags,
          loading: false,
        );
      },
    );
  }
}
