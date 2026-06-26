import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../analytics/inspect_analytics.dart';
import '../../config/heevy_urls.dart';
import '../../data/storage_url_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../capture/capture_detail_screen.dart';
import '../chat/field_guide_screen.dart';
import '../work_orders/create_work_order_screen.dart';
import 'work_request_service.dart';

class WorkRequestDetailScreen extends StatefulWidget {
  const WorkRequestDetailScreen({super.key, required this.workRequestId});

  final String workRequestId;

  @override
  State<WorkRequestDetailScreen> createState() => _WorkRequestDetailScreenState();
}

class _WorkRequestDetailScreenState extends State<WorkRequestDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<List<String>> _photosFuture;

  @override
  void initState() {
    super.initState();
    _load();
    InspectAnalytics.track('wr_detail_view');
  }

  void _load() {
    _future = WorkRequestService(Supabase.instance.client)
        .getWorkRequest(widget.workRequestId);
    _photosFuture = _future.then((payload) {
      final wr = payload['work_request'] as Map<String, dynamic>? ?? {};
      final raw = wr['photo_urls'];
      final list = raw is List ? raw : const [];
      return StorageUrlService(Supabase.instance.client).resolvePhotoUrls(list);
    });
  }

  String _statusMessage(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'draft') {
      return 'Saved — upgrade to Plant CMMS to route for approval.';
    }
    if (s == 'open') {
      return 'Submitted to your org.';
    }
    return status ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Work request'),
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
              title: 'Could not load work request',
              subtitle: snapshot.error?.toString() ?? '',
            );
          }
          final payload = snapshot.data!;
          final wr = Map<String, dynamic>.from(
            payload['work_request'] as Map? ?? {},
          );
          final capture = payload['field_capture'] as Map?;
          final linkedWo = payload['linked_work_order'] as Map?;

          final title = wr['work_title']?.toString() ?? 'Work request';
          final num = wr['wr_number']?.toString() ?? '';
          final status = wr['status']?.toString() ?? '';
          final priority = wr['priority']?.toString() ?? '';
          final location = wr['functional_location']?.toString() ?? '';
          final description = wr['problem_description']?.toString() ?? '';

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
                [status, priority, location].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(color: AppColors.textFaint(context)),
              ),
              if (_statusMessage(status).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    _statusMessage(status),
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
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
                        child: Image.network(urls[i], width: 120, height: 120, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
              if (linkedWo != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Linked work order: ${linkedWo['work_order_number'] ?? linkedWo['title'] ?? ''}',
                  style: TextStyle(color: AppColors.textMuted(context)),
                ),
              ],
              const SizedBox(height: 28),
              if (capture != null)
                HeevyListTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'View field capture',
                  subtitle: capture['plant_area']?.toString() ?? '',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaptureDetailScreen(
                          capture: Map<String, dynamic>.from(capture),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              HeevyListTile(
                icon: Icons.build_outlined,
                title: 'Create work order',
                subtitle: 'Turn this request into a trackable WO',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateWorkOrderScreen(
                        initialTitle: title,
                        initialDescription: description,
                        initialLocation: location,
                        sourceType: 'work_request',
                        sourceId: widget.workRequestId,
                      ),
                    ),
                  );
                  await InspectAnalytics.track('wr_to_wo');
                },
              ),
              const SizedBox(height: 10),
              HeevyListTile(
                icon: Icons.chat_bubble_outline,
                title: 'Ask Field guide',
                subtitle: 'Questions about this request',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FieldGuideScreen(
                        sourceType: 'work_request',
                        sourceId: widget.workRequestId,
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
                icon: Icons.send_outlined,
                label: 'Submit for approval',
                onUpgrade: () => launchUrl(HeevyUrls.captureUpgrade()),
              ),
              _LockedAction(
                icon: Icons.groups_outlined,
                label: 'Assign crew',
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
          title: Text(label, style: TextStyle(color: AppColors.textMuted(context))),
          trailing: TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
        ),
      ),
    );
  }
}
