import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../features/assets/asset_picker_sheet.dart';
import '../../features/capture/capture_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'work_request_detail_screen.dart';
import 'work_request_service.dart';

const _priorities = ['P1 – Critical', 'P2 – High', 'P3 – Medium', 'P4 – Low'];

class _Photo {
  final Uint8List bytes;
  final String ext;
  final String mime;
  const _Photo({required this.bytes, required this.ext, required this.mime});
}

class CreateWorkRequestScreen extends StatefulWidget {
  const CreateWorkRequestScreen({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialLocation,
    this.initialAssetTag,
    this.initialPriority,
  });

  final String? initialTitle;
  final String? initialDescription;
  final String? initialLocation;
  final String? initialAssetTag;
  final String? initialPriority;

  @override
  State<CreateWorkRequestScreen> createState() => _CreateWorkRequestScreenState();
}

class _CreateWorkRequestScreenState extends State<CreateWorkRequestScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _picker = ImagePicker();
  final _photos = <_Photo>[];
  String? _assetId;
  String? _assetTag;
  String _priority = _priorities[2];
  bool _submitting = false;
  String? _error;

  WorkRequestService get _svc => WorkRequestService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle ?? '';
    _description.text = widget.initialDescription ?? '';
    _location.text = widget.initialLocation ?? '';
    _assetTag = widget.initialAssetTag;
    if (widget.initialPriority != null &&
        _priorities.contains(widget.initialPriority)) {
      _priority = widget.initialPriority!;
    }
    InspectAnalytics.track('wr_create_open');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
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
      if (area != null && area.isNotEmpty) _location.text = area;
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
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title for the work request.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _svc.createWorkRequest(
        workTitle: _title.text.trim(),
        problemDescription: _description.text.trim(),
        functionalLocation: _location.text.trim(),
        assetId: _assetId,
        assetTag: _assetTag,
        priority: _priority,
        photos: [
          for (final p in _photos)
            CapturePhoto(bytes: p.bytes, mime: p.mime, ext: p.ext),
        ],
      );
      await InspectAnalytics.track('wr_create_success');
      if (!mounted) return;
      final id = result['id']?.toString();
      if (id != null && id.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WorkRequestDetailScreen(workRequestId: id),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'New work request'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Creates a draft work request for your site. Open the request and tap Submit to site queue to notify your supervisor.',
            style: TextStyle(color: AppColors.textMuted(context), height: 1.4),
          ),
          const SizedBox(height: 16),
          HeevyField(
            controller: _title,
            hint: 'Title',
            icon: Icons.title,
          ),
          const SizedBox(height: 10),
          HeevyField(
            controller: _description,
            hint: 'Problem description',
            icon: Icons.notes_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          HeevyField(
            controller: _location,
            hint: 'Location / plant area',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          HeevyListTile(
            icon: Icons.precision_manufacturing_outlined,
            title: _assetTag?.trim().isNotEmpty == true
                ? 'Asset: ${_assetTag!.trim()}'
                : 'Link asset (optional)',
            subtitle: _assetTag?.trim().isNotEmpty == true
                ? 'Tap to change'
                : 'Pick from your site register',
            onTap: _pickAsset,
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
                value: _priority,
                isExpanded: true,
                dropdownColor: AppColors.surface(context),
                style: TextStyle(color: AppColors.text(context), fontSize: 16),
                items: [
                  for (final p in _priorities)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
            ),
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF453A))),
          ],
          const SizedBox(height: 28),
          HeevyPrimaryButton(
            label: _submitting ? 'Creating…' : 'Create work request',
            loading: _submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
