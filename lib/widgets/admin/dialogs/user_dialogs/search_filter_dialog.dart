import 'package:flutter/material.dart';
import '../../../../models/user/category.dart';
import '../../../../services/user/category_service.dart';
import '../../../../widgets/user/location_autocomplete_field.dart';

/// Filter dialog for search/discovery pages
/// Allows filtering by location, budget, event type, and distance range
class SearchFilterDialog extends StatefulWidget {
  final String? location;
  final double? minBudget;
  final double? maxBudget;
  final double? distanceRange;
  final List<String> selectedEvents;
  final CategoryService categoryService;

  const SearchFilterDialog({
    super.key,
    required this.location,
    required this.minBudget,
    required this.maxBudget,
    required this.distanceRange,
    required this.selectedEvents,
    required this.categoryService,
  });

  @override
  State<SearchFilterDialog> createState() => _SearchFilterDialogState();
}

class _SearchFilterDialogState extends State<SearchFilterDialog> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();
  final GlobalKey _locationFieldKey = GlobalKey();
  late double _distanceRange;
  late bool _distanceEnabled;
  late List<String> _selectedEvents;
  List<Category> _categories = [];
  bool _categoriesLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _locationController.text = widget.location!;
    }
    if (widget.minBudget != null) {
      _minController.text = widget.minBudget!.toStringAsFixed(0);
    }
    if (widget.maxBudget != null) {
      _maxController.text = widget.maxBudget!.toStringAsFixed(0);
    }
    _distanceEnabled = widget.distanceRange != null;
    _distanceRange = widget.distanceRange ?? 50.0;
    _selectedEvents = List<String>.from(widget.selectedEvents);
    _loadCategories();

  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.categoryService.getActiveCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _categoriesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoriesLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Location',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              LocationAutocompleteField(
                key: _locationFieldKey,
                controller: _locationController,
                label: 'Location',
                hintText: 'Search location...',
              ),
              const SizedBox(height: 24),
              const Text(
                'Budget Range',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _minController,
                decoration: InputDecoration(
                  labelText: 'Min Budget (\$)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00C8A0)),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _maxController,
                decoration: InputDecoration(
                  labelText: 'Max Budget (\$)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00C8A0)),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              const Text(
                'Event Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _categoriesLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(
                          color: const Color(0xFF00C8A0),
                        ),
                      ),
                    )
                  : _categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No event types available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final selected = _selectedEvents.contains(
                          category.name,
                        );
                        return FilterChip(
                          label: Text(category.name),
                          selected: selected,
                          selectedColor: const Color(
                            0xFF00C8A0,
                          ).withOpacity(0.2),
                          backgroundColor: Colors.grey[100],
                          checkmarkColor: const Color(0xFF00C8A0),
                          labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF00C8A0)
                                : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedEvents.add(category.name);
                              } else {
                                _selectedEvents.remove(category.name);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Distance Range (km)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Switch.adaptive(
                    value: _distanceEnabled,
                    activeColor: const Color(0xFF00C8A0),
                    onChanged: (value) {
                      setState(() {
                        _distanceEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _distanceRange,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: '${_distanceRange.toStringAsFixed(0)} km',
                      activeColor: const Color(0xFF00C8A0),
                      inactiveColor: Colors.grey[300],
                      onChanged: _distanceEnabled
                          ? (value) {
                              setState(() {
                                _distanceRange = value;
                              });
                            }
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_distanceRange.toStringAsFixed(0)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _locationController.clear();
                      _minController.clear();
                      _maxController.clear();
                      setState(() {
                        _distanceRange = 50.0;
                        _distanceEnabled = false;
                        _selectedEvents.clear();
                      });
                      Navigator.pop(context, {
                        'location': null,
                        'minBudget': null,
                        'maxBudget': null,
                        'distanceRange': null,
                        'events': <String>[],
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final location = _locationController.text.trim().isEmpty
                          ? null
                          : _locationController.text.trim();
                      final min = _minController.text.isEmpty
                          ? null
                          : double.tryParse(_minController.text);
                      final max = _maxController.text.isEmpty
                          ? null
                          : double.tryParse(_maxController.text);
                      Navigator.pop(context, {
                        'location': location,
                        'minBudget': min,
                        'maxBudget': max,
                        'distanceRange': _distanceEnabled
                            ? _distanceRange
                            : null,
                        'events': List<String>.from(_selectedEvents),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C8A0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


