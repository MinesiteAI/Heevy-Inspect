import 'package:flutter/material.dart';

/// Stub for v1 — WO generation is a full CMMS feature unlocked on upgrade.
Future<void> showPmGenerateWorkOrderDialog(
  BuildContext context,
  Map<String, dynamic> pmTemplateShell,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Work order generation'),
      content: const Text(
        'Upgrade to Plant CMMS on the web to generate work orders from PM inspections.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}
