import 'package:flutter/material.dart';

import '../features/inspections/pm_schedule_inbox_screen.dart';
import '../features/inspections/pm_submission_detail_screen.dart';
import '../features/work_orders/work_order_detail_screen.dart';
import '../features/work_requests/work_request_detail_screen.dart';
import '../notifications/notification_service.dart';

/// Routes in-app notifications to the relevant detail screen.
class NotificationRouter {
  static Future<void> open(
    BuildContext context,
    AppNotification notification,
  ) async {
    final payload = notification.payload;
    final type = notification.type.toLowerCase();

    String? wrId = payload['work_request_id']?.toString();

    if (type.contains('work_request') && wrId != null && wrId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkRequestDetailScreen(workRequestId: wrId),
        ),
      );
      return;
    }

    final woId = notification.workOrderId ??
        payload['work_order_id']?.toString();
    if (type.contains('work_order') && woId != null && woId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(workOrderId: woId),
        ),
      );
      return;
    }

    final pmId = payload['pm_submission_id']?.toString();
    if (type.contains('pm_inspection') && pmId != null && pmId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PmSubmissionDetailScreen(submissionId: pmId),
        ),
      );
      return;
    }

    if (type.contains('pm_overdue')) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PmScheduleInboxScreen()),
      );
      return;
    }

    // Generic fallback: try WR id in payload.
    final genericWr = payload['work_request_id']?.toString();
    if (genericWr != null && genericWr.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkRequestDetailScreen(workRequestId: genericWr),
        ),
      );
    }
  }
}
