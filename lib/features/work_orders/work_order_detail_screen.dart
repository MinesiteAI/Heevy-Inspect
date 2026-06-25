import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/heevy_urls.dart';
import '../../data/storage_url_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../chat/field_guide_screen.dart';
import 'work_order_service.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  final String workOrderId;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<List<String>> _photosFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = WorkOrderService(Supabase.instance.client)
        .getWorkOrder(widget.workOrderId);
    _photosFuture = _future.then((wo) {
      final raw = wo['photo_urls'];
      final list = raw is List ? raw : const [];
      return StorageUrlService(Supabase.instance.client).resolvePhotoUrls(list);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Work order'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.textMuted(context),
                strokeWidth: 2.2,
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return HeevyEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load work order',
              subtitle: snapshot.error?.toString() ?? '',
            );
          }
          final wo = snapshot.data!;
          final title = wo['title']?.toString() ?? 'Work order';
          final num = wo['work_order_number']?.toString() ?? '';
          final status = wo['status']?.toString() ?? '';
          final priority = wo['priority']?.toString() ?? '';
          final location = wo['location']?.toString() ?? '';
          final description = wo['description']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (num.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  num,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [status, priority, location]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: TextStyle(color: AppColors.textFaint(context)),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  description,
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
              const SizedBox(height: 20),
              FutureBuilder<List<String>>(
                future: _photosFuture,
                builder: (context, photoSnap) {
                  final urls = photoSnap.data ?? [];
                  if (urls.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          urls[i],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              HeevyListTile(
                icon: Icons.chat_bubble_outline,
                title: 'Ask Field guide',
                subtitle: 'Questions about this work order',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FieldGuideScreen(
                        sourceType: 'work_order',
                        sourceId: widget.workOrderId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Plant CMMS features',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _LockedAction(
                icon: Icons.calendar_month_outlined,
                label: 'Schedule',
                onUpgrade: () => launchUrl(HeevyUrls.captureUpgrade()),
              ),
              _LockedAction(
                icon: Icons.groups_outlined,
                label: 'Assign crew',
                onUpgrade: () => launchUrl(HeevyUrls.captureUpgrade()),
              ),
              _LockedAction(
                icon: Icons.inventory_2_outlined,
                label: 'Parts & stores',
                onUpgrade: () => launchUrl(HeevyUrls.captureUpgrade()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LockedAction extends StatelessWidget {
  const _LockedAction({
    required this.icon,
    required this.label,
    required this.onUpgrade,
  });

  final IconData icon;
  final String label;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Icon(icon, color: AppColors.textFaint(context)),
          title: Text(
            label,
            style: TextStyle(color: AppColors.textMuted(context)),
          ),
          trailing: TextButton(
            onPressed: onUpgrade,
            child: const Text('Upgrade'),
          ),
        ),
      ),
    );
  }
}
