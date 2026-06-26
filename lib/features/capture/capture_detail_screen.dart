import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../analytics/inspect_analytics.dart';
import '../../config/heevy_urls.dart';
import '../../data/storage_url_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ask_field_guide_tile.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/signed_photo_strip.dart';
import '../work_orders/create_work_order_screen.dart';

class CaptureDetailScreen extends StatefulWidget {
  const CaptureDetailScreen({super.key, required this.capture});

  final Map<String, dynamic> capture;

  @override
  State<CaptureDetailScreen> createState() => _CaptureDetailScreenState();
}

class _CaptureDetailScreenState extends State<CaptureDetailScreen> {
  late Future<List<String>> _photosFuture;
  String? _wrNumber;

  @override
  void initState() {
    super.initState();
    final raw = widget.capture['photo_urls'];
    final list = raw is List ? raw : const [];
    _photosFuture = StorageUrlService(Supabase.instance.client)
        .resolvePhotoUrls(list);
    _loadWrNumber();
  }

  Future<void> _loadWrNumber() async {
    final wrId = widget.capture['work_request_id']?.toString();
    if (wrId == null || wrId.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('work_requests')
          .select('wr_number')
          .eq('id', wrId)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _wrNumber = row?['wr_number']?.toString());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.capture['plant_area']?.toString() ?? '—';
    final sev = widget.capture['severity']?.toString() ?? '';
    final notes = widget.capture['notes']?.toString() ?? '';
    final voice = widget.capture['voice_transcript']?.toString() ?? '';
    final created = widget.capture['created_at']?.toString() ?? '';
    final id = widget.capture['id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Capture detail'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            area,
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sev.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sev,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_wrNumber != null && _wrNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Work request: $_wrNumber',
              style: TextStyle(color: AppColors.textFaint(context), fontSize: 13),
            ),
          ],
          if (created.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              created,
              style: TextStyle(color: AppColors.textFaint(context), fontSize: 12),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              notes,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
          if (voice.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Voice transcript',
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              voice,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          SignedPhotoStrip(urlsFuture: _photosFuture),
          const SizedBox(height: 28),
          AskFieldGuideTile(
            subtitle: 'Get help about this capture',
            sourceType: 'field_capture',
            sourceId: id,
          ),
          const SizedBox(height: 10),
          HeevyListTile(
            icon: Icons.build_outlined,
            title: 'Create work order',
            subtitle: 'Turn this capture into a trackable WO',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateWorkOrderScreen(
                    initialTitle: notes.length > 60
                        ? '${notes.substring(0, 57)}...'
                        : (notes.isNotEmpty ? notes : 'Field capture'),
                    initialDescription: notes,
                    initialLocation: area,
                    sourceType: 'field_capture',
                    sourceId: id,
                  ),
                ),
              );
              await InspectAnalytics.track('capture_to_wo');
            },
          ),
          const SizedBox(height: 10),
          HeevySecondaryButton(
            label: 'Upgrade for scheduling',
            onTap: () => launchUrl(HeevyUrls.captureUpgrade()),
          ),
        ],
      ),
    );
  }
}
