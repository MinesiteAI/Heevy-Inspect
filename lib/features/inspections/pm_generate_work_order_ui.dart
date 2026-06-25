import 'package:flutter/material.dart';

import '../work_orders/create_work_order_screen.dart';

/// Opens create work order flow from PM inspection context.
Future<void> showPmGenerateWorkOrderDialog(
  BuildContext context,
  Map<String, dynamic> pmTemplateShell, {
  String? defectSummary,
  String? location,
  String? sourceSubmissionId,
}) async {
  final plantArea = (pmTemplateShell['plant_area'] as String?)?.trim() ?? '';
  final pmTitle = (pmTemplateShell['pm_title'] as String?)?.trim() ?? 'PM defect';
  final title = defectSummary?.trim().isNotEmpty == true
      ? defectSummary!.trim()
      : 'PM defect — $pmTitle';

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Create work order'),
      content: const Text(
        'Create a basic work order from this PM inspection? Scheduling and crew assignment require Plant CMMS.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CreateWorkOrderScreen(
        initialTitle: title,
        initialDescription: defectSummary ?? 'Defect found during PM: $pmTitle',
        initialLocation: location ?? plantArea,
        initialPriority: 'high',
        sourceType: sourceSubmissionId != null ? 'pm_submission' : 'pm_template',
        sourceId: sourceSubmissionId,
      ),
    ),
  );
}
