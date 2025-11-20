import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/system_config_model.dart';
import 'package:fyp_project/models/matching_rule_model.dart';
import 'package:fyp_project/models/booking_rule_model.dart';

class SystemConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // System Config Methods
  Future<List<SystemConfigModel>> getRulesConfigs() async {
    try {
      final snapshot = await _firestore
          .collection('system_config')
          .where('category', isEqualTo: 'rules')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SystemConfigModel(
          id: doc.id,
          key: data['key'] ?? '',
          value: data['value'],
          description: data['description'],
          dataType: data['dataType'] ?? 'string',
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedBy: data['updatedBy'],
        );
      }).toList();
    } catch (e) {
      // Return default configs if Firestore fails
      return [
        SystemConfigModel(
          id: '1',
          key: 'matching_logic',
          value: 'default',
          description: 'Job matching algorithm',
          dataType: 'string',
          updatedAt: DateTime.now(),
        ),
        SystemConfigModel(
          id: '2',
          key: 'credit_allocation',
          value: 10,
          description: 'Default credit allocation per user',
          dataType: 'number',
          updatedAt: DateTime.now(),
        ),
        SystemConfigModel(
          id: '3',
          key: 'abuse_threshold',
          value: 5,
          description: 'Number of reports before auto-suspension',
          dataType: 'number',
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  Future<List<SystemConfigModel>> getPlatformSettings() async {
    try {
      final snapshot = await _firestore
          .collection('system_config')
          .where('category', isEqualTo: 'platform')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SystemConfigModel(
          id: doc.id,
          key: data['key'] ?? '',
          value: data['value'],
          description: data['description'],
          dataType: data['dataType'] ?? 'string',
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedBy: data['updatedBy'],
        );
      }).toList();
    } catch (e) {
      // Return default settings if Firestore fails
      return [
        SystemConfigModel(
          id: '1',
          key: 'platform_name',
          value: 'JobSeek',
          description: 'Platform name',
          dataType: 'string',
          updatedAt: DateTime.now(),
        ),
        SystemConfigModel(
          id: '2',
          key: 'maintenance_mode',
          value: false,
          description: 'Enable maintenance mode',
          dataType: 'boolean',
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  Future<void> updateConfig(String configId, dynamic value, {String? updatedBy}) async {
    await _firestore.collection('system_config').doc(configId).update({
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    });
  }

  // Matching Rules Methods
  Future<List<MatchingRuleModel>> getMatchingRules() async {
    try {
      final snapshot = await _firestore
          .collection('matching_rules')
          .orderBy('name')
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize default matching rules
        return _getDefaultMatchingRules();
      }

      return snapshot.docs.map((doc) {
        return MatchingRuleModel.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      return _getDefaultMatchingRules();
    }
  }

  Future<void> updateMatchingRule(MatchingRuleModel rule, {String? updatedBy}) async {
    final data = rule.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (updatedBy != null) {
      data['updatedBy'] = updatedBy;
    }

    await _firestore.collection('matching_rules').doc(rule.id).set(data, SetOptions(merge: true));
  }

  Future<void> initializeDefaultMatchingRules() async {
    final defaultRules = _getDefaultMatchingRules();
    final batch = _firestore.batch();

    for (final rule in defaultRules) {
      final docRef = _firestore.collection('matching_rules').doc(rule.id);
      batch.set(docRef, rule.toJson());
    }

    await batch.commit();
  }

  List<MatchingRuleModel> _getDefaultMatchingRules() {
    return [
      MatchingRuleModel(
        id: 'skills_match',
        name: 'Skills Matching',
        description: 'Match jobs based on required skills and user skills',
        isEnabled: true,
        weight: 0.4,
        parameters: {
          'minMatchPercentage': 60,
          'requiredSkillsWeight': 0.7,
          'preferredSkillsWeight': 0.3,
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'location_match',
        name: 'Location Matching',
        description: 'Match jobs based on location proximity',
        isEnabled: true,
        weight: 0.2,
        parameters: {
          'maxDistanceKm': 50,
          'exactLocationBonus': 10,
          'remoteWorkAllowed': true,
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'budget_match',
        name: 'Budget Matching',
        description: 'Match jobs based on budget range compatibility',
        isEnabled: true,
        weight: 0.15,
        parameters: {
          'minBudgetMatch': 80,
          'flexibleBudgetRange': 20,
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'experience_match',
        name: 'Experience Matching',
        description: 'Match jobs based on work experience level',
        isEnabled: true,
        weight: 0.15,
        parameters: {
          'minExperienceMatch': 70,
          'yearsOfExperienceWeight': 0.6,
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'category_match',
        name: 'Category Matching',
        description: 'Match jobs based on job category preferences',
        isEnabled: true,
        weight: 0.1,
        parameters: {
          'categoryPreferenceWeight': 0.8,
        },
        updatedAt: DateTime.now(),
      ),
    ];
  }

  // Booking Rules Methods
  Future<List<BookingRuleModel>> getBookingRules() async {
    try {
      final snapshot = await _firestore
          .collection('booking_rules')
          .orderBy('name')
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize default booking rules
        return _getDefaultBookingRules();
      }

      return snapshot.docs.map((doc) {
        return BookingRuleModel.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      return _getDefaultBookingRules();
    }
  }

  Future<void> updateBookingRule(BookingRuleModel rule, {String? updatedBy}) async {
    final data = rule.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (updatedBy != null) {
      data['updatedBy'] = updatedBy;
    }

    await _firestore.collection('booking_rules').doc(rule.id).set(data, SetOptions(merge: true));
  }

  Future<void> initializeDefaultBookingRules() async {
    final defaultRules = _getDefaultBookingRules();
    final batch = _firestore.batch();

    for (final rule in defaultRules) {
      final docRef = _firestore.collection('booking_rules').doc(rule.id);
      batch.set(docRef, rule.toJson());
    }

    await batch.commit();
  }

  List<BookingRuleModel> _getDefaultBookingRules() {
    return [
      BookingRuleModel(
        id: 'booking_window',
        name: 'Booking Window',
        description: 'Define the time window for making bookings',
        isEnabled: true,
        parameters: {
          'advanceBookingDays': 30,
          'minimumBookingHours': 24,
          'maximumBookingDays': 90,
        },
        updatedAt: DateTime.now(),
      ),
      BookingRuleModel(
        id: 'cancellation_policy',
        name: 'Cancellation Policy',
        description: 'Rules for cancelling bookings',
        isEnabled: true,
        parameters: {
          'freeCancellationHours': 24,
          'cancellationFeePercentage': 10,
          'noShowPenalty': 20,
        },
        updatedAt: DateTime.now(),
      ),
      BookingRuleModel(
        id: 'booking_limits',
        name: 'Booking Limits',
        description: 'Maximum number of bookings per user',
        isEnabled: true,
        parameters: {
          'maxActiveBookings': 5,
          'maxBookingsPerDay': 3,
          'maxBookingsPerWeek': 10,
        },
        updatedAt: DateTime.now(),
      ),
      BookingRuleModel(
        id: 'rescheduling_policy',
        name: 'Rescheduling Policy',
        description: 'Rules for rescheduling bookings',
        isEnabled: true,
        parameters: {
          'maxReschedules': 2,
          'rescheduleNoticeHours': 12,
          'rescheduleFee': 5,
        },
        updatedAt: DateTime.now(),
      ),
      BookingRuleModel(
        id: 'booking_confirmation',
        name: 'Booking Confirmation',
        description: 'Automatic confirmation and reminder settings',
        isEnabled: true,
        parameters: {
          'autoConfirm': true,
          'reminderHoursBefore': [24, 2],
          'confirmationRequired': false,
        },
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

