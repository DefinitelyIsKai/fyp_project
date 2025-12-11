import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/attendance.dart';
import 'auth_service.dart';
import 'storage_service.dart';
import 'dart:convert';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('attendance');

  // Get or create attendance for an application
  Future<Attendance> getOrCreateAttendance({
    required String applicationId,
    required String postId,
    required String recruiterId,
  }) async {
    final jobseekerId = _authService.currentUserId;
    
    // Check if attendance already exists
    final existing = await _col
        .where('applicationId', isEqualTo: applicationId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return Attendance.fromFirestore(existing.docs.first);
    }

    // Create new attendance
    final attendance = Attendance(
      id: '',
      applicationId: applicationId,
      postId: postId,
      jobseekerId: jobseekerId,
      recruiterId: recruiterId,
      createdAt: DateTime.now(),
    );

    final docRef = await _col.add(attendance.toFirestore());
    return Attendance.fromFirestore(await docRef.get());
  }

  // Get attendance by application ID
  Future<Attendance?> getAttendanceByApplicationId(String applicationId) async {
    final jobseekerId = _authService.currentUserId;
    final result = await _col
        .where('applicationId', isEqualTo: applicationId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .get();

    if (result.docs.isEmpty) return null;
    return Attendance.fromFirestore(result.docs.first);
  }

  // Stream attendance by application ID
  Stream<Attendance?> streamAttendanceByApplicationId(String applicationId) {
    final jobseekerId = _authService.currentUserId;
    return _col
        .where('applicationId', isEqualTo: applicationId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return Attendance.fromFirestore(snapshot.docs.first);
        })
        .handleError((error) {
          debugPrint('Error in streamAttendanceByApplicationId: $error');
          return null;
        });
  }

  // Upload start image
  Future<void> uploadStartImage({
    required String attendanceId,
    required bool fromCamera,
    String? preferredCamera, 
  }) async {
    try {
      // Pick and get image as base64
      final imageBytes = await _storageService.pickImageBytes(
        fromCamera: fromCamera,
        preferredCamera: preferredCamera,
      );
      if (imageBytes == null) {
        throw StateError('No image selected');
      }

      // Convert to base64
      final base64String = base64Encode(imageBytes);
      
      // Check size limit (Firestore document limit is 1MB)
      const int maxBase64Size = 900 * 1024; // 900KB to leave room for other fields
      if (base64String.length > maxBase64Size) {
        throw StateError('Image is too large. Please try taking the photo again with lower resolution.');
      }

      // Update attendance with start image
      await _col.doc(attendanceId).update({
        'startImageUrl': base64String,
        'startTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error uploading start image: $e');
      rethrow;
    }
  }

  // Upload end image
  Future<void> uploadEndImage({
    required String attendanceId,
    required bool fromCamera,
    String? preferredCamera, 
  }) async {
    try {
      final imageBytes = await _storageService.pickImageBytes(
        fromCamera: fromCamera,
        preferredCamera: preferredCamera,
      );
      if (imageBytes == null) {
        throw StateError('No image selected');
      }

      // Convert to base64
      final base64String = base64Encode(imageBytes);
      
      // Check size limit
      const int maxBase64Size = 900 * 1024; // 900KB 
      if (base64String.length > maxBase64Size) {
        throw StateError('Image is too large. Please try taking the photo again with lower resolution.');
      }

      // Update attendance with end image
      await _col.doc(attendanceId).update({
        'endImageUrl': base64String,
        'endTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error uploading end image: $e');
      rethrow;
    }
  }

  // Get all attendances for current jobseeker
  Stream<List<Attendance>> streamMyAttendances() {
    final jobseekerId = _authService.currentUserId;
    return _col
        .where('jobseekerId', isEqualTo: jobseekerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Attendance.fromFirestore(doc))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        })
        .handleError((error) {
          debugPrint('Error in streamMyAttendances: $error');
          return <Attendance>[];
        });
  }

  Future<void> removeStartImage({required String attendanceId}) async {
    try {
      await _col.doc(attendanceId).update({
        'startImageUrl': FieldValue.delete(),
        'startTime': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error removing start image: $e');
      rethrow;
    }
  }

  Future<void> removeEndImage({required String attendanceId}) async {
    try {
      await _col.doc(attendanceId).update({
        'endImageUrl': FieldValue.delete(),
        'endTime': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error removing end image: $e');
      rethrow;
    }
  }

  // Get all attendances for a specific post (for recruiter to view)
  Stream<List<Attendance>> streamAttendancesByPostId(String postId) {
    return _col
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Attendance.fromFirestore(doc))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        })
        .handleError((error) {
          debugPrint('Error in streamAttendancesByPostId: $error');
          return <Attendance>[];
        });
  }
}