import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';


class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

 
  Future<Map<String, dynamic>> autoCompleteExpiredPosts() async {
    try {
      final callable = _functions.httpsCallable('autoCompleteExpiredPosts');
      final result = await callable.call();
      
      debugPrint('Cloud Function result: ${result.data}');
      
      //parse  result
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'success': data['success'] ?? false,
        'completedCount': data['completedCount'] ?? 0,
        'errors': data['errors'],
        'message': data['message'] ?? 'Unknown result',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'completedCount': 0,
        'errors': {'code': e.code, 'message': e.message ?? 'Unknown error'},
        'message': 'Error calling Cloud Function: ${e.message ?? e.code}',
      };
    } catch (e) {
      debugPrint('Unexpected error calling Cloud Function: $e');
      return {
        'success': false,
        'completedCount': 0,
        'errors': {'general': e.toString()},
        'message': 'Unexpected error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> autoApprovePendingPosts() async {
    try {
      debugPrint('CloudFunctionsService: Calling autoApprovePendingPosts...');
      final callable = _functions.httpsCallable('autoApprovePendingPosts');
      debugPrint('CloudFunctionsService: Callable created, calling function...');
      final result = await callable.call();
      
      debugPrint('CloudFunctionsService: autoApprovePendingPosts result: ${result.data}');
      
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'success': data['success'] ?? false,
        'approvedCount': data['approvedCount'] ?? 0,
        'errors': data['errors'],
        'message': data['message'] ?? 'Unknown result',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'approvedCount': 0,
        'errors': {'code': e.code, 'message': e.message ?? 'Unknown error'},
        'message': 'Error calling Cloud Function: ${e.message ?? e.code}',
      };
    } catch (e) {
      debugPrint('Unexpected error calling Cloud Function: $e');
      return {
        'success': false,
        'approvedCount': 0,
        'errors': {'general': e.toString()},
        'message': 'Unexpected error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> autoUnsuspendExpiredUsers() async {
    try {
      debugPrint('CloudFunctionsService: Calling autoUnsuspendExpiredUsers...');
      final callable = _functions.httpsCallable('autoUnsuspendExpiredUsers');
      debugPrint('CloudFunctionsService: Callable created, calling function...');
      final result = await callable.call();
      
      debugPrint('CloudFunctionsService: autoUnsuspendExpiredUsers result: ${result.data}');
      
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'success': data['success'] ?? false,
        'unsuspendedCount': data['unsuspendedCount'] ?? 0,
        'errors': data['errors'],
        'message': data['message'] ?? 'Unknown result',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'unsuspendedCount': 0,
        'errors': {'code': e.code, 'message': e.message ?? 'Unknown error'},
        'message': 'Error calling Cloud Function: ${e.message ?? e.code}',
      };
    } catch (e) {
      debugPrint('Unexpected error calling Cloud Function: $e');
      return {
        'success': false,
        'unsuspendedCount': 0,
        'errors': {'general': e.toString()},
        'message': 'Unexpected error: $e',
      };
    }
  }

  // User login - generates session token
  Future<Map<String, dynamic>> userLogin() async {
    try {
      debugPrint('CloudFunctionsService: Calling userLogin...');
      final callable = _functions.httpsCallable('userLogin');
      final result = await callable.call();
      
      debugPrint('CloudFunctionsService: userLogin result: ${result.data}');
      
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'success': data['success'] ?? false,
        'sessionToken': data['sessionToken'],
        'userId': data['userId'],
        'message': data['message'] ?? 'Unknown result',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'sessionToken': null,
        'userId': null,
        'errors': {'code': e.code, 'message': e.message ?? 'Unknown error'},
        'message': 'Error calling Cloud Function: ${e.message ?? e.code}',
      };
    } catch (e) {
      debugPrint('Unexpected error calling Cloud Function: $e');
      return {
        'success': false,
        'sessionToken': null,
        'userId': null,
        'errors': {'general': e.toString()},
        'message': 'Unexpected error: $e',
      };
    }
  }

  // User logout - clears session
  Future<Map<String, dynamic>> userLogout() async {
    try {
      debugPrint('CloudFunctionsService: Calling userLogout...');
      final callable = _functions.httpsCallable('userLogout');
      final result = await callable.call();
      
      debugPrint('CloudFunctionsService: userLogout result: ${result.data}');
      
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown result',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'errors': {'code': e.code, 'message': e.message ?? 'Unknown error'},
        'message': 'Error calling Cloud Function: ${e.message ?? e.code}',
      };
    } catch (e) {
      debugPrint('Unexpected error calling Cloud Function: $e');
      return {
        'success': false,
        'errors': {'general': e.toString()},
        'message': 'Unexpected error: $e',
      };
    }
  }

  // Update lastActive timestamp
  Future<Map<String, dynamic>> updateLastActive() async {
    try {
      debugPrint('CloudFunctionsService: Calling updateLastActive...');
      final callable = _functions.httpsCallable('updateLastActive');
      final result = await callable.call();
      
      debugPrint('CloudFunctionsService: updateLastActive result: ${result.data}');
      
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown result',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'errors': {'code': e.code, 'message': e.message ?? 'Unknown error'},
        'message': 'Error calling Cloud Function: ${e.message ?? e.code}',
      };
    } catch (e) {
      debugPrint('Unexpected error calling Cloud Function: $e');
      return {
        'success': false,
        'errors': {'general': e.toString()},
        'message': 'Unexpected error: $e',
      };
    }
  }
}

