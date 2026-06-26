import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../analytics/inspect_analytics.dart';
import '../../billing/entitlement_service.dart';
import '../../billing/upgrade_cta_policy.dart';
import '../../config/heevy_urls.dart';
import '../../data/storage_url_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ask_field_guide_tile.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/signed_photo_strip.dart';
import '../../widgets/view_on_web_button.dart';
import '../../widgets/wr_status_timeline.dart';
import '../capture/capture_detail_screen.dart';
import '../work_orders/create_work_order_screen.dart';
import '../work_orders/work_order_detail_screen.dart';
import '../work_orders/work_order_service.dart';
import 'work_request_service.dart';

class WorkRequestDetailScreen extends StatefulWidget {
  const WorkRequestDetailScreen({
    super.key,
    required this.workRequestId,
    this.entitlement,
  });

  final String workRequestId;
  final EntitlementResult? entitlement;

  @override
  State<WorkRequestDetailScreen> createState() => _WorkRequestDetailScreenState();
}

class _WorkRequestDetailScreenState extends State<WorkRequestDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<List<String>> _photosFuture;
  bool _submitting = false;
  bool _acknowledging = false;

  WorkRequestService get _svc => WorkRequestService(Supabase.instance.client);

  bool get _isOrgManager => widget.entitlement?.isOrgManager == true;
  bool get _allowsPlant => widget.entitlement?.allowsPlant ?? true;

  @override
  void initState() {
    super.initState();
    _load();
    InspectAnalytics.track('wr_detail_view');
  }

  void _load() {
    _future = _svc.getWorkRequest(widget.workRequestId);
    _photosFuture = _future.then((payload) {
      final wr = payload['work_request'] as Map<String, dynamic>? ?? {};
      final raw = wr['photo_urls'];
      final list = raw is List ? raw : const [];
      return StorageUrlService(Supabase.instance.client).resolvePhotoUrls(list);
    });
  }

  Future<void> _submitDraft() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _svc.submitWorkRequest(widget.workRequestId);
      if (!mounted) return;
      final msg = result['message']?.toString() ??
          'Submitted to your site queue.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 6),
        ),
      );
      setState(_load);
      await InspectAnalytics.track('wr_submit');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _svc.acknowledgeWorkRequest(widget.workRequestId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Acknowledged for crew.',
          ),
        ),
      );
      setState(_load);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  String _statusMessage(String? status, {required bool readOnly}) {
    final s = (status ?? '').toLowerCase();
    if (s == 'draft') {
      if (readOnly) {
        return 'Draft — waiting for the requester to submit to the site queue.';
      }
      return 'Draft — submit to notify your supervisor and add to the web queue.';
    }
    if (s == 'open') {
      return 'Submitted to your org. Visible on web for review and action.';
    }
    if (s == 'pending approval') {
      return 'In the approval queue on web.';
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
          final supervisorAck = payload['supervisor_ack'] as Map?;
          final readOnly = payload['read_only'] == true;

          final title = wr['work_title']?.toString() ?? 'Work request';
          final num = wr['wr_number']?.toString() ?? '';
          final status = wr['status']?.toString() ?? '';
          final priority = wr['priority']?.toString() ?? '';
          final location = wr['functional_location']?.toString() ?? '';
          final description = wr['problem_description']?.toString() ?? '';
          final creator = wr['created_by_name']?.toString() ?? '';
          final isDraft = status.toLowerCase() == 'draft';
          final hasAck = supervisorAck != null;
          final linkedWoId = linkedWo?['id']?.toString();
          final linkedWoNum = linkedWo?['work_order_number']?.toString() ?? '';
          final hasLinkedWo = linkedWoId != null && linkedWoId.isNotEmpty;
          final linkedWoAccessible =
              payload['linked_work_order_accessible'] == true;

          final timelineSteps = buildWrTimelineSteps(
            wr: wr,
            linkedWo: linkedWo != null ? Map<String, dynamic>.from(linkedWo) : null,
            supervisorAck: supervisorAck != null
                ? Map<String, dynamic>.from(supervisorAck)
                : null,
          );

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
              if (readOnly && creator.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Logged by $creator',
                  style: TextStyle(color: AppColors.textFaint(context)),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [status, priority, location].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(color: AppColors.textFaint(context)),
              ),
              const SizedBox(height: 14),
              WrStatusTimeline(steps: timelineSteps),
              if (_statusMessage(status, readOnly: readOnly).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    _statusMessage(status, readOnly: readOnly),
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
              SignedPhotoStrip(urlsFuture: _photosFuture),
              if (isDraft && !readOnly) ...[
                const SizedBox(height: 24),
                HeevyPrimaryButton(
                  label: _submitting ? 'Submitting…' : 'Submit to site queue',
                  loading: _submitting,
                  onTap: _submitting ? null : _submitDraft,
                ),
                const SizedBox(height: 8),
                Text(
                  'Notifies your supervisor. Full approval workflow on web Plant CMMS.',
                  style: TextStyle(
                    color: AppColors.textFaint(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              if (readOnly && !isDraft && !hasAck) ...[
                const SizedBox(height: 24),
                HeevyPrimaryButton(
                  label: _acknowledging ? 'Acknowledging…' : 'Acknowledge for crew',
                  loading: _acknowledging,
                  onTap: _acknowledging ? null : _acknowledge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Lets the crew know you have seen this — approve and schedule on web.',
                  style: TextStyle(
                    color: AppColors.textFaint(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              if (!isDraft) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ViewOnWebButton(
                    uri: HeevyUrls.workRequestOnWeb(widget.workRequestId),
                    label: 'View on web',
                  ),
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
                          entitlement: widget.entitlement,
                        ),
                      ),
                    );
                  },
                ),
              if (hasLinkedWo && linkedWoAccessible) ...[
                const SizedBox(height: 10),
                HeevyListTile(
                  icon: Icons.build_outlined,
                  title: linkedWoNum.isNotEmpty
                      ? 'Open work order $linkedWoNum'
                      : 'Open work order',
                  subtitle: linkedWo?['status']?.toString() ?? 'View WO details',
                  onTap: () async {
                    try {
                      await WorkOrderService(Supabase.instance.client)
                          .getWorkOrder(linkedWoId);
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkOrderDetailScreen(
                            workOrderId: linkedWoId,
                            entitlement: widget.entitlement,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                          backgroundColor: const Color(0xFFFF453A),
                        ),
                      );
                    }
                  },
                ),
              ] else if (hasLinkedWo) ...[
                const SizedBox(height: 10),
                HeevyListTile(
                  icon: Icons.open_in_new,
                  title: linkedWoNum.isNotEmpty
                      ? 'View work order $linkedWoNum on web'
                      : 'View work order on web',
                  subtitle: 'Created on web — open in Plant CMMS',
                  onTap: () => launchUrl(
                    HeevyUrls.workOrderOnWeb(linkedWoId),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ] else if (!readOnly) ...[
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
                    if (mounted) setState(_load);
                  },
                ),
              ],
              const SizedBox(height: 10),
              AskFieldGuideTile(
                subtitle: 'Questions about this request',
                sourceType: 'work_request',
                sourceId: widget.workRequestId,
              ),
              if (UpgradeCtaPolicy.showPlantFeatureLocks(
                allowsPlant: _allowsPlant,
                isOrgManager: _isOrgManager,
              ) &&
                  !isDraft) ...[
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
                  icon: Icons.groups_outlined,
                  label: 'Assign crew',
                  onUpgrade: () => launchUrl(HeevyUrls.captureUpgrade()),
                ),
              ],
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
