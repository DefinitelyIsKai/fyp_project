import 'package:cloud_firestore/cloud_firestore.dart';
class TimestampUtils {
  //pparses firestore timestamp to DateTime
  static DateTime parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is Map) return DateTime.now();
    return DateTime.now();
  }

  static DateTime? parseTimestampFromMap(Map<String, dynamic>? map, String key) {
    if (map == null || !map.containsKey(key)) return null;
    try {
      return parseTimestamp(map[key]);
    } catch (e) {
      return null;
    }
  }

  static Timestamp toTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }
}

