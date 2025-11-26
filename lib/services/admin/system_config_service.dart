import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/system_config_model.dart';
import 'package:fyp_project/models/admin/matching_rule_model.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';

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
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize default matching rules
        return _getDefaultMatchingRules();
      }

      final rules = snapshot.docs.map((doc) {
        return MatchingRuleModel.fromJson(doc.data(), doc.id);
      }).toList();
      
      // Sort by name in memory (no index required)
      rules.sort((a, b) => a.name.compareTo(b.name));
      
      return rules;
    } catch (e) {
      // If error occurs, try to initialize and return defaults
      print('Error loading matching rules: $e');
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
      // Use merge: true to update existing rules, or create if missing
      // This ensures all 5 rules exist even if some were already created
      batch.set(docRef, rule.toJson(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  List<MatchingRuleModel> _getDefaultMatchingRules() {
    return [
      MatchingRuleModel(
        id: 'text_similarity',
        name: 'Text Similarity (Embedding)',
        description: 'Match based on text similarity using embeddings (title, description, event, job type, location, tags, skills)',
        isEnabled: true,
        weight: 0.35,
        parameters: {
          'weight': 0.35,
          'description': 'Weight for embedding-based text similarity matching',
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'tag_matching',
        name: 'Tag Matching',
        description: 'Match based on direct tag overlap between job posts and candidate profiles',
        isEnabled: true,
        weight: 0.35,
        parameters: {
          'weight': 0.35,
          'description': 'Weight for tag overlap percentage matching',
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'required_skills',
        name: 'Required Skills Matching',
        description: 'Match based on overlap between job required skills and candidate skill set',
        isEnabled: true,
        weight: 0.15,
        parameters: {
          'weight': 0.15,
          'description': 'Weight for required skills overlap percentage',
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'distance',
        name: 'Distance Matching',
        description: 'Match based on geographic proximity between candidate and job location',
        isEnabled: true,
        weight: 0.10,
        parameters: {
          'weight': 0.10,
          'maxDistanceKm': 50.0,
          'decayFactor': 3.0,
          'description': 'Weight for distance-based matching with exponential decay',
        },
        updatedAt: DateTime.now(),
      ),
      MatchingRuleModel(
        id: 'job_type_preference',
        name: 'Job Type Preference',
        description: 'Bonus score for matching candidate job type preferences',
        isEnabled: true,
        weight: 0.02,
        parameters: {
          'weight': 0.02,
          'description': 'Bonus weight for job type preference matching',
        },
        updatedAt: DateTime.now(),
      ),
    ];
  }

  // Report Category Methods
  Future<List<ReportCategoryModel>> getReportCategories() async {
    try {
      final snapshot = await _firestore
          .collection('report_categories')
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize default report categories
        return _getDefaultReportCategories();
      }

      final categories = snapshot.docs.map((doc) {
        return ReportCategoryModel.fromJson(doc.data(), doc.id);
      }).toList();
      
      // Sort by name in memory (no index required)
      categories.sort((a, b) => a.name.compareTo(b.name));
      
      return categories;
    } catch (e) {
      // If error occurs, try to initialize and return defaults
      print('Error loading report categories: $e');
      return _getDefaultReportCategories();
    }
  }

  Future<void> updateReportCategory(ReportCategoryModel category, {String? updatedBy}) async {
    final data = category.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (updatedBy != null) {
      data['updatedBy'] = updatedBy;
    }

    await _firestore.collection('report_categories').doc(category.id).set(data, SetOptions(merge: true));
  }

  Future<void> initializeDefaultReportCategories() async {
    final defaultCategories = _getDefaultReportCategories();
    final batch = _firestore.batch();

    for (final category in defaultCategories) {
      final docRef = _firestore.collection('report_categories').doc(category.id);
      // Use merge: true to update existing categories, or create if missing
      // This ensures all categories exist even if some were already created
      batch.set(docRef, category.toJson(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  List<ReportCategoryModel> _getDefaultReportCategories() {
    return [
      ReportCategoryModel(
        id: 'unprofessional_behavior',
        name: 'Unprofessional Behavior',
        description: 'Reports related to unprofessional conduct, inappropriate behavior, or violation of workplace standards',
        isEnabled: true,
        creditDeduction: 50,
        updatedAt: DateTime.now(),
      ),
      ReportCategoryModel(
        id: 'no_show_cancellation',
        name: 'No Show / Cancellation',
        description: 'Reports for users who fail to show up for scheduled appointments or cancel at the last minute',
        isEnabled: true,
        creditDeduction: 30,
        updatedAt: DateTime.now(),
      ),
      ReportCategoryModel(
        id: 'poor_work_quality',
        name: 'Poor Work Quality',
        description: 'Reports regarding substandard work performance, incomplete tasks, or quality issues',
        isEnabled: true,
        creditDeduction: 40,
        updatedAt: DateTime.now(),
      ),
      ReportCategoryModel(
        id: 'harassment',
        name: 'Harassment',
        description: 'Reports of harassment, discrimination, or any form of abusive behavior',
        isEnabled: true,
        creditDeduction: 100,
        updatedAt: DateTime.now(),
      ),
      ReportCategoryModel(
        id: 'other',
        name: 'Other',
        description: 'Other types of reports that do not fit into the above categories',
        isEnabled: true,
        creditDeduction: 20,
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

