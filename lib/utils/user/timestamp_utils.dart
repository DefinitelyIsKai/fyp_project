import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for parsing Firestore timestamps
/// 
/// Provides safe conversion from Firestore timestamp types to DateTime
class TimestampUtils {
  /// Parses a Firestore timestamp to DateTime
  /// 
  /// Handles multiple input types:
  /// - Timestamp: Converts using toDate()
  /// - DateTime: Returns as-is
  /// - null: Returns current DateTime
  /// - Other types: Returns current DateTime as fallback
  /// 
  /// This is useful when reading data from Firestore where timestamps
  /// can be in different formats depending on how they were stored.
  static DateTime parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is Map) return DateTime.now();
    return DateTime.now();
  }

  /// Safely extracts a DateTime from a Map with a given key
  /// 
  /// Returns null if key doesn't exist or value cannot be parsed
  static DateTime? parseTimestampFromMap(Map<String, dynamic>? map, String key) {
    if (map == null || !map.containsKey(key)) return null;
    try {
      return parseTimestamp(map[key]);
    } catch (e) {
      return null;
    }
  }

  /// Converts DateTime to Firestore Timestamp
  static Timestamp toTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }
}

