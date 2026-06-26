import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../config/heevy_brand.dart';
import '../../features/assets/asset_picker_sheet.dart';
import '../../sync/offline_queue.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../work_requests/work_request_detail_screen.dart';
import 'capture_service.dart';

const _severities = ['P1 – Critical', 'P2 – High', 'P3 – Medium', 'P4 – Low'];

class _Photo {
  final Uint8List bytes;
  final String ext;
  final String mime;
  const _Photo({required this.bytes, required this.ext, required this.mime});
}

class QuickCaptureScreen extends StatefulWidget {
  const QuickCaptureScreen({super.key});

  @override
  State<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends State<QuickCaptureScreen> {
  final _notes = TextEditingController();
  final _area = TextEditingController();
  final _picker = ImagePicker();
  final _photos = <_Photo>[];
  String _severity = _severities[2];
  String? _assetId;
  String? _assetTag;
  bool _submitting = false;
  bool _createWorkOrder = false;
  String? _error;

  CaptureService get _svc => CaptureService(Supabase.instance.client);

  @override
  void dispose() {
    _notes.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _pickAsset() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const AssetPickerSheet(),
    );
    if (picked == null) return;
    setState(() {
      _assetId = picked['id']?.toString();
      _assetTag = picked['tag_number']?.toString();
      final area = picked['area_name']?.toString();
      if (area != null && area.isNotEmpty) _area.text = area;
    });
  }

  Future<void> _addPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    var ext = 'jpg';
    var mime = 'image/jpeg';
    if (name.endsWith('.png')) {
      ext = 'png';
      mime = 'image/png';
    }
    setState(() => _photos.add(_Photo(bytes: bytes, ext: ext, mime: mime)));
  }

  Future<void> _submit() async {
    if (_notes.text.trim().isEmpty && _photos.isEmpty) {
      setState(() => _error = 'Add a photo or description before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _svc.submitFieldCapture(
        plantArea: _area.text.trim(),
        assetId: _assetId,
        assetTag: _assetTag,
        severity: _severity,
        notes: _notes.text.trim(),
        photos: [
          for (final p in _photos)
            CapturePhoto(bytes: p.bytes, mime: p.mime, ext: p.ext),
        ],
        createWorkOrder: _createWorkOrder,
      );
      await InspectAnalytics.track('first_capture');
      if (_createWorkOrder) {
        await InspectAnalytics.track('capture_create_wo');
      }
      if (!mounted) return;
      final wr = result['wr_number']?.toString();
      final wrId = result['work_request_id']?.toString();
      final wo = result['work_order_number']?.toString();
      final baseMsg = wo != null && wo.isNotEmpty
          ? 'Capture saved ($wr) · WO $wo'
          : wr != null && wr.isNotEmpty
          ? 'Draft saved ($wr)'
          : 'Capture saved';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$baseMsg — submit to site queue to notify your supervisor.',
          ),
          backgroundColor: AppColors.surface(context),
          duration: const Duration(seconds: 8),
          action: wrId != null && wrId.isNotEmpty
              ? SnackBarAction(
                  label: 'Submit now',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkRequestDetailScreen(workRequestId: wrId),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (isLikelyOfflineError(e)) {
        try {
          final photoPayloads = [
            for (final p in _photos)
              {
                'mime': p.mime,
                'ext': p.ext,
                'data_base64': base64Encode(p.bytes),
              },
          ];
          await OfflineQueue().enqueue(
            OfflineQueueItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: OfflineQueueItemType.fieldCapture,
              createdAt: DateTime.now(),
              label: _area.text.trim().isEmpty ? 'Field capture' : _area.text.trim(),
              payload: {
                'plant_area': _area.text.trim(),
                if (_assetId != null) 'asset_id': _assetId,
                if (_assetTag != null) 'asset_tag': _assetTag,
                'severity': _severity,
                'notes': _notes.text.trim(),
                if (photoPayloads.isNotEmpty) 'photo_payloads': photoPayloads,
                'create_work_order': _createWorkOrder,
              },
            ),
          );
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Saved offline — will sync when you are back online.',
                style: TextStyle(color: AppColors.text(context)),
              ),
              backgroundColor: AppColors.surface(context),
            ),
          );
          Navigator.of(context).pop(true);
          return;
        } catch (_) {
          // Fall through to error display.
        }
      }
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = message);
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFFF453A),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Quick capture'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Log a defect or anomaly in the field',
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          HeevyField(
            controller: _area,
            hint: 'Area / location',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surfaceAlt(context),
            borderRadius: BorderRadius.circular(heevyRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(heevyRadius),
              onTap: _pickAsset,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.precision_manufacturing_outlined,
                      color: AppColors.textMuted(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _assetTag ?? 'Pick asset (optional)',
                        style: TextStyle(
                          color: _assetTag != null
                              ? AppColors.text(context)
                              : AppColors.textFaint(context),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textFaint(context)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt(context),
              borderRadius: BorderRadius.circular(heevyRadius),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _severity,
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: AppColors.textMuted(context)),
                dropdownColor: AppColors.surface(context),
                style: TextStyle(color: AppColors.text(context), fontSize: 16),
                items: [
                  for (final s in _severities)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _severity = v ?? _severity),
              ),
            ),
          ),
          const SizedBox(height: 10),
          HeevyField(
            controller: _notes,
            hint: HeevyBrand.askHint,
            icon: Icons.notes_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: HeevySecondaryButton(
                  label: 'Camera',
                  onTap: () => _addPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeevySecondaryButton(
                  label: 'Gallery',
                  onTap: () => _addPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _photos[i].bytes,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF453A).withValues(alpha: 0.4)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF453A), fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Create work order now',
              style: TextStyle(color: AppColors.text(context)),
            ),
            subtitle: Text(
              'Also open a basic WO (scheduling requires upgrade)',
              style: TextStyle(color: AppColors.textFaint(context), fontSize: 12),
            ),
            value: _createWorkOrder,
            onChanged: (v) => setState(() => _createWorkOrder = v),
          ),
          const SizedBox(height: 12),
          HeevyPrimaryButton(
            label: _submitting ? 'Submitting…' : 'Submit capture',
            loading: _submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
