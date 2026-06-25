import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../features/capture/capture_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'work_order_detail_screen.dart';
import 'work_order_service.dart';

class _Photo {
  final Uint8List bytes;
  final String ext;
  final String mime;
  const _Photo({required this.bytes, required this.ext, required this.mime});
}

class CreateWorkOrderScreen extends StatefulWidget {
  const CreateWorkOrderScreen({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialLocation,
    this.initialAssetTag,
    this.initialPriority,
    this.sourceType,
    this.sourceId,
  });

  final String? initialTitle;
  final String? initialDescription;
  final String? initialLocation;
  final String? initialAssetTag;
  final String? initialPriority;
  final String? sourceType;
  final String? sourceId;

  @override
  State<CreateWorkOrderScreen> createState() => _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState extends State<CreateWorkOrderScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _assetTag = TextEditingController();
  final _picker = ImagePicker();
  final _photos = <_Photo>[];
  String _priority = 'medium';
  bool _submitting = false;
  String? _error;

  WorkOrderService get _svc => WorkOrderService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle ?? '';
    _description.text = widget.initialDescription ?? '';
    _location.text = widget.initialLocation ?? '';
    _assetTag.text = widget.initialAssetTag ?? '';
    if (widget.initialPriority != null) {
      _priority = widget.initialPriority!;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _assetTag.dispose();
    super.dispose();
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
      setState(() => _error = 'Enter a title for the work order.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _svc.createWorkOrder(
        title: _title.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
        assetTag: _assetTag.text.trim().isEmpty ? null : _assetTag.text.trim(),
        priority: _priority,
        sourceType: widget.sourceType,
        sourceId: widget.sourceId,
        photos: [
          for (final p in _photos)
            CapturePhoto(bytes: p.bytes, mime: p.mime, ext: p.ext),
        ],
      );
      await InspectAnalytics.track('first_wo_created');
      if (!mounted) return;
      final id = result['id']?.toString();
      if (id != null && id.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailScreen(workOrderId: id),
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
      appBar: const HeevyBrandedAppBar(title: 'Create work order'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          HeevyField(
            controller: _title,
            hint: 'Title',
            icon: Icons.title,
          ),
          const SizedBox(height: 10),
          HeevyField(
            controller: _description,
            hint: 'Description',
            icon: Icons.notes_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          HeevyField(
            controller: _location,
            hint: 'Location / area',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          HeevyField(
            controller: _assetTag,
            hint: 'Asset tag (optional)',
            icon: Icons.precision_manufacturing_outlined,
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
                items: const [
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'low', child: Text('Low')),
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
            label: _submitting ? 'Creating…' : 'Create work order',
            loading: _submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
