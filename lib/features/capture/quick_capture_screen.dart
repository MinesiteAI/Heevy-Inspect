import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/assets/asset_picker_sheet.dart';
import '../../theme/app_colors.dart';
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
    if (_notes.text.trim().isEmpty && _photos.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final urls = <String>[];
      for (final p in _photos) {
        urls.add(await _svc.uploadPhoto(p.bytes, p.mime, p.ext));
      }
      await _svc.submitFieldCapture(
        plantArea: _area.text.trim(),
        assetId: _assetId,
        assetTag: _assetTag,
        severity: _severity,
        notes: _notes.text.trim(),
        photoUrls: urls,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Quick capture'),
        backgroundColor: AppColors.bg(context),
        foregroundColor: AppColors.text(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _area,
            decoration: const InputDecoration(labelText: 'Area / location'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickAsset,
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: Text(_assetTag ?? 'Pick asset (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: [
              for (final s in _severities)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _severity = v ?? _severity),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Describe the defect or anomaly',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _addPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _addPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo),
                label: const Text('Gallery'),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_photos[i].bytes, width: 88, height: 88, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _photos.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Submitting…' : 'Submit capture'),
          ),
        ],
      ),
    );
  }
}
