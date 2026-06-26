import 'package:flutter/material.dart';

import '../config/heevy_brand.dart';
import '../theme/app_colors.dart';
import 'history_card.dart';

class WrTimelineStep {
  const WrTimelineStep({
    required this.label,
    required this.detail,
    this.completed = false,
    this.active = false,
  });

  final String label;
  final String detail;
  final bool completed;
  final bool active;
}

List<WrTimelineStep> buildWrTimelineSteps({
  required Map<String, dynamic> wr,
  Map<String, dynamic>? linkedWo,
  Map<String, dynamic>? supervisorAck,
}) {
  final status = (wr['status']?.toString() ?? '').toLowerCase();
  final createdAt = wr['created_at']?.toString() ?? '';
  final updatedAt = wr['updated_at']?.toString() ?? '';
  final approvedAt = wr['approved_at']?.toString() ?? '';
  final isDraft = status == 'draft';
  final submitted = !isDraft;
  final ackAt = supervisorAck?['acknowledged_at']?.toString() ?? '';
  final ackBy = supervisorAck?['acknowledged_by_name']?.toString() ?? '';

  final steps = <WrTimelineStep>[
    WrTimelineStep(
      label: 'Created',
      detail: createdAt.isNotEmpty ? formatHistoryDate(createdAt) : 'Logged in the field',
      completed: true,
    ),
    WrTimelineStep(
      label: 'Submitted to site queue',
      detail: submitted
          ? (updatedAt.isNotEmpty ? formatHistoryDate(updatedAt) : 'Sent to supervisor')
          : 'Waiting — submit from this screen',
      completed: submitted,
      active: isDraft,
    ),
  ];

  if (status == 'pending approval') {
    steps.add(
      const WrTimelineStep(
        label: 'In approval queue',
        detail: 'Review and approve on web Plant CMMS',
        completed: false,
        active: true,
      ),
    );
  } else if (status == 'open') {
    steps.add(
      const WrTimelineStep(
        label: 'In site queue',
        detail: 'Visible for planning and assignment on web',
        completed: true,
        active: true,
      ),
    );
  }

  if (ackAt.isNotEmpty) {
    steps.add(
      WrTimelineStep(
        label: 'Supervisor acknowledged',
        detail: ackBy.isNotEmpty
            ? '$ackBy · ${formatHistoryDate(ackAt)}'
            : formatHistoryDate(ackAt),
        completed: true,
      ),
    );
  }

  if (approvedAt.isNotEmpty) {
    final approver = wr['approved_by']?.toString() ?? '';
    steps.add(
      WrTimelineStep(
        label: 'Approved',
        detail: approver.isNotEmpty
            ? '$approver · ${formatHistoryDate(approvedAt)}'
            : formatHistoryDate(approvedAt),
        completed: true,
      ),
    );
  }

  if (linkedWo != null) {
    final woNum = linkedWo['work_order_number']?.toString() ?? '';
    final woStatus = linkedWo['status']?.toString() ?? '';
    steps.add(
      WrTimelineStep(
        label: 'Work order created',
        detail: [
          if (woNum.isNotEmpty) woNum,
          if (woStatus.isNotEmpty) woStatus,
        ].join(' · '),
        completed: true,
      ),
    );
  }

  return steps;
}

class WrStatusTimeline extends StatelessWidget {
  const WrStatusTimeline({super.key, required this.steps});

  final List<WrTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status timeline',
            style: TextStyle(
              color: AppColors.text(context),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final WrTimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = step.completed
        ? HeevyBrand.accent
        : step.active
        ? AppColors.textMuted(context)
        : AppColors.textFaint(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border(context),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: TextStyle(
                      color: AppColors.textFaint(context),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
