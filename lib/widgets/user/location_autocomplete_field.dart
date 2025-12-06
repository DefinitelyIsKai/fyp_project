import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/user/location_autocomplete_service.dart' show LocationAutocompleteService, kGoogleApiKey;

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool required;
  final Function(String description, double? latitude, double? longitude)? onLocationSelected;
  final String? helperText;
  final String? restrictToCountry; //malaysia
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.required = false,
    this.onLocationSelected,
    this.helperText,
    this.restrictToCountry = 'my',
  });

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onLocationChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay hiding to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus && mounted) {
          setState(() {
            _suggestions = [];
          });
        }
      });
    }
  }

  void _onLocationChanged() {
    //reduce api call delayinmg it
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (widget.controller.text.trim().isNotEmpty && _focusNode.hasFocus) {
        _searchLocations(widget.controller.text);
      } else {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
    });
  }

  Future<void> _searchLocations(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    final suggestions = await LocationAutocompleteService.getAutocomplete(
      query,
      restrictToCountry: widget.restrictToCountry,
    );

    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    }
  }

  Future<void> _selectLocation(Map<String, dynamic> suggestion) async {
    final description = suggestion['description'] as String? ?? '';
    final placeId = suggestion['place_id'] as String?;

    // Get place details to retrieve coordinates
    if (placeId != null) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&key=$kGoogleApiKey'
          '&fields=geometry,formatted_address',
        );

        final response = await http.get(url);
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          final geometry = result['geometry'];
          final location = geometry['location'];

          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();

          setState(() {
            widget.controller.text = description;
            _suggestions = [];
          });
          _focusNode.unfocus();
          widget.onLocationSelected?.call(description, lat, lng);
          return;
        }
      } catch (e) {
        debugPrint('Error getting place details: $e');
      }
    }

    setState(() {
      widget.controller.text = description;
      _suggestions = [];
    });
    _focusNode.unfocus();
    widget.onLocationSelected?.call(description, null, null);
  }

  Widget _buildSuggestions() {
    if (!_focusNode.hasFocus || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00C8A0)),
                ),
              ),
            )
          : _suggestions.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No locations found', style: TextStyle(color: Colors.grey[600])),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final description = suggestion['description'] as String? ?? '';
                return InkWell(
                  onTap: () => _selectLocation(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            description,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
            ),
            if (widget.required) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ],
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(widget.helperText!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.hintText ?? 'Search location...',
            hintText: widget.hintText ?? 'Search location...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {
                        _suggestions = [];
                      });
                      widget.onLocationSelected?.call('', null, null);
                    },
                  )
                : _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00C8A0)),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00C8A0)),
            ),
          ),
        ),
        _buildSuggestions(),
      ],
    );
  }
}
