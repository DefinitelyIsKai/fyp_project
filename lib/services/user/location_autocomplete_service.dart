import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String kGoogleApiKey = 'AIzaSyCwNKysMyhIndCzLxpdbNJxnAofw2xdA4A';

class LocationAutocompleteService {
  /// Fetches location autocomplete predictions from Google Places API
  /// 
  /// [query] - The search query text
  /// [restrictToCountry] - Optional country code (e.g., 'my' for Malaysia)
  /// Returns a list of predictions with 'description' and 'place_id'
  static Future<List<Map<String, dynamic>>> getAutocomplete(
    String query, {
    String? restrictToCountry,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final components = restrictToCountry != null ? '&components=country:$restrictToCountry' : '';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$kGoogleApiKey'
        '$components'
        '&language=en',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        return List<Map<String, dynamic>>.from(data['predictions']);
      } else if (data['status'] == 'ZERO_RESULTS') {
        return [];
      } else {
        // Log error but don't throw - return empty list
        debugPrint('Places API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching autocomplete: $e');
      return [];
    }
  }

  /// Gets the formatted address for a place ID
  static Future<String?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=$kGoogleApiKey'
        '&fields=formatted_address',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        return data['result']['formatted_address'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }
}

