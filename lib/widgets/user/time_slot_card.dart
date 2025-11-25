import 'package:flutter/material.dart';
import '../../services/user/availability_service.dart';
import '../../services/user/application_service.dart';
import '../../services/user/auth_service.dart';
import '../../services/user/post_service.dart';
import '../../models/user/availability_slot.dart';
import '../../models/user/booking_request.dart';
import '../admin/dialogs/user_dialogs/pending_request_dialog.dart';
import '../admin/dialogs/user_dialogs/booked_slot_dialog.dart';
import '../../utils/user/dialog_utils.dart';

class TimeSlotCard extends StatelessWidget {
  final AvailabilitySlot slot;
  final bool isRecruiter;
  final bool hasPendingRequest;
  final Function(bool) onToggle;
  final VoidCallback onDelete;
  final ApplicationService applicationService;
  final AuthService authService;
  final PostService postService;
  final AvailabilityService availabilityService;

  const TimeSlotCard({
    super.key,
    required this.slot,
    required this.isRecruiter,
    this.hasPendingRequest = false,
    required this.onToggle,
    required this.onDelete,
    required this.applicationService,
    required this.authService,
    required this.postService,
    required this.availabilityService,
  });

  Future<void> _showBookedSlotDetails(BuildContext context) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => BookedSlotDialog(
        slot: slot,
        availabilityService: availabilityService,
        applicationService: applicationService,
        authService: authService,
        postService: postService,
      ),
    );
  }

  Future<void> _showPendingRequestDetails(BuildContext context) async {
    if (!context.mounted) return;

    // Get pending booking requests for this slot
    try {
      final requests = await availabilityService
          .streamBookingRequestsForRecruiter()
          .first;

      final pendingRequests = requests
          .where((req) =>
      req.slotId == slot.id &&
          req.status == BookingRequestStatus.pending)
          .toList();

      if (!context.mounted) return;

      if (pendingRequests.isEmpty) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'No pending requests for this slot',
        );
        return;
      }

      // Show dialog with pending request details
      showDialog(
        context: context,
        builder: (context) => PendingRequestDialog(
          slot: slot,
          requests: pendingRequests,
          availabilityService: availabilityService,
          applicationService: applicationService,
          authService: authService,
          postService: postService,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Error loading requests: $e',
        );
      }
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    // Check if slot is booked or has pending requests
    final isBooked = slot.bookedBy != null;
    String message;

    if (isBooked) {
      message = 'This slot is currently booked. Deleting it will cancel the booking. Are you sure you want to delete this slot?';
    } else if (hasPendingRequest) {
      message = 'This slot has pending booking requests. Deleting it will cancel those requests. Are you sure you want to delete this slot?';
    } else {
      message = 'Are you sure you want to delete this time slot (${slot.timeDisplay})?';
    }

    final confirmed = await DialogUtils.showDestructiveConfirmation(
      context: context,
      title: 'Delete Time Slot',
      message: message,
      icon: Icons.delete_outline,
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true && context.mounted) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBooked = slot.bookedBy != null;
    final themeColor = const Color(0xFF00C8A0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          color: !slot.isAvailable || isBooked
              ? themeColor.withOpacity(0.05)
              : hasPendingRequest && isRecruiter
              ? Colors.amber[50]
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBooked
                  ? Icons.person
                  : hasPendingRequest && isRecruiter
                  ? Icons.pending
                  : slot.isAvailable
                  ? Icons.check_circle
                  : Icons.cancel,
              color: isBooked
                  ? themeColor
                  : hasPendingRequest && isRecruiter
                  ? Colors.amber[700]
                  : themeColor,
              size: 20,
            ),
          ),
          title: Text(
            slot.timeDisplay,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: slot.isAvailable
              ? hasPendingRequest && isRecruiter
              ? Row(
            children: [
              Icon(
                Icons.pending,
                size: 14,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Pending booking request',
                  style: TextStyle(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
              : Row(
            children: [
              Expanded(
                child: Text(
                  isBooked ? 'Booked' : 'Available for booking',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBooked) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: themeColor,
                ),
              ],
            ],
          )
              : Row(
            children: [
              Text(
                'Unavailable',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (isBooked) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: themeColor,
                ),
              ],
            ],
          ),
          trailing: isRecruiter
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: slot.isAvailable,
                onChanged: onToggle,
                activeColor: themeColor,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                onPressed: () => _handleDelete(context),
              ),
            ],
          )
              : null,
          onTap: (isBooked && isRecruiter)
              ? () => _showBookedSlotDetails(context)
              : (hasPendingRequest && isRecruiter)
              ? () => _showPendingRequestDetails(context)
              : null,
        ),
      ),
    );
  }
}

