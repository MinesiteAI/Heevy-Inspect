// Unified PM inspection driven by web PM Forms `form_structure` (pm_schedule_templates).
//
// Submissions are stored in `pm_form_submissions` with flat `form_values` (web-compatible)
// plus `__mobile_v1` for evidence (photos, checkbox status map, header fields).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/workspace_context.dart';
import '../../sync/offline_queue.dart';
import 'pm_generate_work_order_ui.dart';

const _kFormBg = Color(0xFFFDFBF6);
const _kFormInk = Color(0xFF1A1A1A);
const _kFormMuted = Color(0xFF6B6B6B);

/// Typed text must not inherit a washed-out theme color on [_kFormBg].
const TextStyle _kPmFieldTextStyle = TextStyle(
  fontSize: 15,
  height: 1.35,
  color: _kFormInk,
);
const TextStyle _kPmDenseFieldTextStyle = TextStyle(
  fontSize: 13,
  height: 1.35,
  color: _kFormInk,
);
const TextStyle _kPmFieldHintStyle = TextStyle(
  fontSize: 14,
  color: _kFormMuted,
);
const TextStyle _kPmFieldLabelStyle = TextStyle(
  fontSize: 14,
  color: _kFormInk,
  fontWeight: FontWeight.w500,
);

class _TaskPhoto {
  final Uint8List? bytes;
  final String? url;
  final String ext;
  final String mime;
  const _TaskPhoto({this.bytes, this.url, required this.ext, required this.mime});
}

typedef _FieldMap = Map<String, dynamic>;

List<dynamic> _dynamicListOrEmpty(dynamic v) => v is List ? v : const [];

class _PmPayloadResult {
  final Map<String, dynamic> formValuesOut;
  final String? notesOut;
  final String nameTrim;

  _PmPayloadResult({
    required this.formValuesOut,
    this.notesOut,
    required this.nameTrim,
  });
}

/// Renders [formStructure] from `pm_schedule_templates` with per-line evidence
/// (comment + photos) for checkbox-style tasks.
class SchedulePmFormScreen extends StatefulWidget {
  final Map<String, dynamic> pmTemplateShell;
  final String scheduleTemplateId;
  final String? scheduleName;
  final Map<String, dynamic> formStructure;
  final Map<String, dynamic>? initialSubmission;
  final bool readOnly;
  /// Daily Works / My Jobs linkage for server-backed drafts.
  final String? mobileLineItemId;
  final String? mobileAssignmentId;
  final String? mobileWorkOrderId;
  /// Existing `pm_form_submissions.id` when continuing or updating a draft.
  final String? draftSubmissionId;
  /// Scheduled PM instance from calendar (`scheduled_pm_instances.id`).
  final String? scheduledInstanceId;
  /// Company or mine site label from the user's provisioned workspace.
  final String? siteDisplayName;

  const SchedulePmFormScreen({
    super.key,
    required this.pmTemplateShell,
    required this.scheduleTemplateId,
    this.scheduleName,
    required this.formStructure,
    this.initialSubmission,
    this.readOnly = false,
    this.siteDisplayName,
    this.mobileLineItemId,
    this.mobileAssignmentId,
    this.mobileWorkOrderId,
    this.draftSubmissionId,
    this.scheduledInstanceId,
  });

  @override
  State<SchedulePmFormScreen> createState() => _SchedulePmFormScreenState();
}

class _SchedulePmFormScreenState extends State<SchedulePmFormScreen> {
  /// Checkbox fields: status string only (photos/comments use side maps).
  final Map<String, String> _checkStatus = {};
  final Map<String, TextEditingController> _checkCommentCtrls = {};
  final Map<String, List<_TaskPhoto>> _checkPhotos = {};
  final Map<String, TextEditingController> _textCtrls = {};
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _commentsCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _supervisorCtrl = TextEditingController();
  final TextEditingController _woCtrl = TextEditingController();
  late final TextEditingController _plantAreaCtrl;
  late final TextEditingController _pmTitleCtrl;
  bool? _followUpRequired;
  bool? _documentUpdateRequired;
  DateTime? _signDate;
  DateTime? _approvalDate;
  DateTime? _inspectionDate;
  bool _submitting = false;
  bool _savingDraft = false;
  String? _persistedDraftId;

  List<_FieldMap> get _sections {
    final raw = widget.formStructure['sections'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _plantAreaCtrl = TextEditingController();
    _pmTitleCtrl = TextEditingController();
    _plantAreaCtrl.addListener(_onContextEdited);
    _pmTitleCtrl.addListener(_onContextEdited);
    final t = widget.pmTemplateShell;
    final wo = (t['wo_number'] as String?)?.trim();
    if (wo != null && wo.isNotEmpty) _woCtrl.text = wo;
    _hydrateFromSubmission();
    if (_plantAreaCtrl.text.trim().isEmpty) {
      _plantAreaCtrl.text = (t['plant_area'] as String?)?.trim() ?? '';
    }
    if (_pmTitleCtrl.text.trim().isEmpty) {
      _pmTitleCtrl.text = (t['pm_title'] as String?)?.trim() ?? '';
    }
    _initFieldControllers();
    _persistedDraftId = widget.draftSubmissionId?.trim();
    final initSub = widget.initialSubmission;
    if ((_persistedDraftId == null || _persistedDraftId!.isEmpty) &&
        initSub != null &&
        initSub['status']?.toString() == 'draft') {
      _persistedDraftId = initSub['id']?.toString().trim();
    }
  }

  void _onContextEdited() {
    if (mounted) setState(() {});
  }

  String _composeHeadlinePreview() {
    return composePmHeadline(
      siteDisplayName: widget.siteDisplayName,
      area: _plantAreaCtrl.text,
      title: _pmTitleCtrl.text,
    );
  }

  String _readOnlyHeadline() {
    final h = (widget.pmTemplateShell['display_headline'] as String?)?.trim();
    if (h != null && h.isNotEmpty) return h;
    return composePmHeadline(
      siteDisplayName: widget.siteDisplayName,
      area: (widget.pmTemplateShell['plant_area'] as String?) ?? '',
      title: (widget.pmTemplateShell['pm_title'] as String?) ?? 'PM',
    );
  }

  String _fieldLabel(String fieldId) {
    for (final sec in _sections) {
      final fields = sec['fields'];
      if (fields is! List) continue;
      for (final f in fields) {
        if (f is! Map) continue;
        final id = f['id']?.toString() ?? '';
        if (id == fieldId) {
          final label = f['label']?.toString().trim();
          if (label != null && label.isNotEmpty) return label;
        }
      }
    }
    return fieldId;
  }

  List<String> _collectDefectNotes() {
    final notes = <String>[];
    for (final e in _checkStatus.entries) {
      if (e.value != 'defective') continue;
      final label = _fieldLabel(e.key);
      final comment = _checkCommentCtrls[e.key]?.text.trim() ?? '';
      notes.add(comment.isNotEmpty ? '$label: $comment' : label);
    }
    return notes;
  }

  List<Map<String, String>> _collectDefectRecords() {
    final rows = <Map<String, String>>[];
    for (final e in _checkStatus.entries) {
      if (e.value != 'defective') continue;
      rows.add({
        'task_id': e.key,
        'task': _fieldLabel(e.key),
        'comment': _checkCommentCtrls[e.key]?.text.trim() ?? '',
      });
    }
    return rows;
  }

  void _hydrateFromSubmission() {
    final s = widget.initialSubmission;
    if (s == null) return;
    Map<String, dynamic> formMap = <String, dynamic>{};
    final form = s['form_data'];
    if (form is Map) {
      formMap = Map<String, dynamic>.from(form);
    } else {
      final fv = s['form_values'];
      if (fv is Map) {
        final fvm = Map<String, dynamic>.from(fv);
        final mv = fvm['__mobile_v1'];
        if (mv is Map) {
          final snap = mv['form_data'];
          if (snap is Map) {
            formMap = Map<String, dynamic>.from(snap);
          }
        }
      }
    }
    final sv = formMap['schedule_form_values'];
    if (sv is Map) {
      for (final e in sv.entries) {
        final id = e.key.toString();
        final v = e.value;
        if (v is Map) {
          final m = Map<String, dynamic>.from(v);
          _checkStatus[id] = (m['status'] as String?) ?? 'not_checked';
          final c = (m['comment'] as String?) ?? '';
          _checkCommentCtrls[id] = TextEditingController(text: c);
          final photos = (m['photos'] as List?) ?? const [];
          _checkPhotos[id] = [
            for (final u in photos)
              if (u is String && u.isNotEmpty) _TaskPhoto(url: u, ext: 'jpg', mime: 'image/jpeg'),
          ];
        } else if (v == true) {
          _checkStatus[id] = 'serviceable';
          _checkCommentCtrls[id] = TextEditingController();
        } else if (v == false) {
          _checkStatus[id] = 'not_checked';
          _checkCommentCtrls[id] = TextEditingController();
        } else if (v == 'defective') {
          _checkStatus[id] = 'defective';
          _checkCommentCtrls[id] = TextEditingController();
        }
      }
    }
    _commentsCtrl.text =
        (formMap['general_comments'] as String?) ?? (s['general_comments'] as String?) ?? '';
    _nameCtrl.text = (formMap['sign_name'] as String?) ??
        (s['sign_name'] as String?) ??
        (s['submitter_name'] as String?) ??
        '';
    _durationCtrl.text = (formMap['pm_duration'] as String?) ?? (s['pm_duration'] as String?) ?? '';
    _supervisorCtrl.text =
        (formMap['supervisor_name'] as String?) ?? (s['supervisor_name'] as String?) ?? '';
    if (_woCtrl.text.isEmpty) {
      _woCtrl.text = (formMap['wo_number'] as String?) ?? (s['wo_number'] as String?) ?? '';
    }
    final mca = formMap['mobile_context_plant_area'];
    if (mca is String && mca.trim().isNotEmpty) {
      _plantAreaCtrl.text = mca.trim();
    }
    final mct = formMap['mobile_context_pm_title'];
    if (mct is String && mct.trim().isNotEmpty) {
      _pmTitleCtrl.text = mct.trim();
    }
    _followUpRequired = formMap['follow_up_required'] is bool
        ? formMap['follow_up_required'] as bool
        : (s['follow_up_required'] is bool ? s['follow_up_required'] as bool : null);
    _documentUpdateRequired = formMap['document_update_required'] is bool
        ? formMap['document_update_required'] as bool
        : (s['document_update_required'] is bool ? s['document_update_required'] as bool : null);
    DateTime? parseDate(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    _signDate = parseDate(formMap['sign_date']) ?? parseDate(s['sign_date']);
    _approvalDate = parseDate(formMap['approval_date']) ?? parseDate(s['approval_date']);
    _inspectionDate = parseDate(formMap['inspection_date']) ?? parseDate(s['inspection_date']);

    if (sv is Map) {
      for (final sec in _sections) {
        final fields = sec['fields'];
        if (fields is! List) continue;
        for (final f in fields) {
          if (f is! Map) continue;
          final m = Map<String, dynamic>.from(f);
          final id = (m['id'] as String?) ?? '';
          final type = (m['type'] as String?) ?? '';
          if (id.isEmpty || type == 'checkbox' || type == 'sectionHeader') continue;
          final val = sv[id];
          _textCtrls[id] ??= TextEditingController(text: val?.toString() ?? '');
        }
      }
    }
  }

  void _initFieldControllers() {
    for (final sec in _sections) {
      final fields = sec['fields'];
      if (fields is! List) continue;
      for (final f in fields) {
        if (f is! Map) continue;
        final m = Map<String, dynamic>.from(f);
        final id = (m['id'] as String?) ?? '';
        final type = (m['type'] as String?) ?? 'text';
        if (id.isEmpty) continue;
        if (type == 'checkbox') {
          _checkStatus.putIfAbsent(id, () => 'not_checked');
          _checkCommentCtrls.putIfAbsent(id, () => TextEditingController());
          _checkPhotos.putIfAbsent(id, () => []);
        } else if (type != 'sectionHeader') {
          _textCtrls.putIfAbsent(id, () => TextEditingController());
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    for (final c in _checkCommentCtrls.values) {
      c.dispose();
    }
    _commentsCtrl.dispose();
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _supervisorCtrl.dispose();
    _woCtrl.dispose();
    _plantAreaCtrl.removeListener(_onContextEdited);
    _pmTitleCtrl.removeListener(_onContextEdited);
    _plantAreaCtrl.dispose();
    _pmTitleCtrl.dispose();
    super.dispose();
  }

  String _statusFor(String fieldId) => _checkStatus[fieldId] ?? 'not_checked';

  void _setStatus(String fieldId, String status) {
    if (widget.readOnly) return;
    setState(() => _checkStatus[fieldId] = status);
  }

  Future<void> _addCheckPhoto(String fieldId) async {
    if (widget.readOnly) return;
    final src = await _picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    if (src == null) return;
    final bytes = await src.readAsBytes();
    setState(() {
      _checkPhotos.putIfAbsent(fieldId, () => []).add(
            _TaskPhoto(bytes: bytes, ext: 'jpg', mime: 'image/jpeg'),
          );
    });
  }

  Widget _buildCheckboxRow(_FieldMap field) {
    final id = field['id'] as String? ?? '';
    final label = field['label'] as String? ?? id;
    final status = _statusFor(id);
    final cCtrl = _checkCommentCtrls[id] ??= TextEditingController();
    final photos = _checkPhotos[id] ?? const <_TaskPhoto>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kFormInk)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(id, 'not_checked', 'Not checked', status),
              _statusChip(id, 'serviceable', 'OK', status),
              _statusChip(id, 'defective', 'Defect', status),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: !widget.readOnly,
            controller: cCtrl,
            maxLines: 2,
            style: _kPmDenseFieldTextStyle,
            cursorColor: _kFormInk,
            decoration: const InputDecoration(
              hintText: 'Comment (optional)',
              hintStyle: _kPmFieldHintStyle,
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < photos.length; i++)
                _photoTile(photos[i]),
              if (!widget.readOnly)
                IconButton.filledTonal(
                  onPressed: () => _addCheckPhoto(id),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoTile(_TaskPhoto p) {
    if (p.url != null && p.url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(p.url!, width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    if (p.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(p.bytes!, width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statusChip(String fieldId, String value, String text, String current) {
    final sel = current == value;
    return ChoiceChip(
      label: Text(text, style: TextStyle(fontSize: 12, color: sel ? Colors.white : _kFormInk)),
      selected: sel,
      onSelected: widget.readOnly ? null : (_) => _setStatus(fieldId, value),
      selectedColor: value == 'defective' ? const Color(0xFFB91C1C) : _kFormInk,
      backgroundColor: Colors.white,
    );
  }

  Widget _buildGenericField(_FieldMap field) {
    final id = field['id'] as String? ?? '';
    final type = field['type'] as String? ?? 'text';
    final label = field['label'] as String? ?? id;
    if (type == 'sectionHeader') {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kFormInk),
        ),
      );
    }
    if (type == 'checkbox') return _buildCheckboxRow(field);

    final ctrl = _textCtrls[id];
    if (ctrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kFormInk)),
          const SizedBox(height: 4),
          TextField(
            enabled: !widget.readOnly,
            controller: ctrl,
            maxLines: type == 'longText' ? 4 : 1,
            keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
            style: _kPmFieldTextStyle,
            cursorColor: _kFormInk,
            decoration: InputDecoration(
              hintText: (field['placeholder'] as String?) ?? '',
              hintStyle: _kPmFieldHintStyle,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<_PmPayloadResult> _buildPayload() async {
    final t = widget.pmTemplateShell;
    final user = Supabase.instance.client.auth.currentUser;
    final storage = Supabase.instance.client.storage.from('inspection-uploads');
    final submissionId = DateTime.now().millisecondsSinceEpoch.toString();
    final rand = math.Random();

    final scheduleFormValues = <String, dynamic>{};
    for (final sec in _sections) {
      final fields = sec['fields'];
      if (fields is! List) continue;
      for (final f in fields) {
        if (f is! Map) continue;
        final m = Map<String, dynamic>.from(f);
        final id = m['id'] as String? ?? '';
        final type = m['type'] as String? ?? '';
        if (id.isEmpty) continue;
        if (type == 'checkbox') {
          final urls = <String>[];
          final plist = _checkPhotos[id] ?? const <_TaskPhoto>[];
          for (var pi = 0; pi < plist.length; pi++) {
            final p = plist[pi];
            if (p.url != null && p.url!.isNotEmpty) {
              urls.add(p.url!);
              continue;
            }
            if (p.bytes != null) {
              final salt = rand.nextInt(0x7fffffff).toRadixString(36);
              final path = '${user?.id ?? 'anon'}/$submissionId/${id}_${pi}_$salt.jpg';
              await storage.uploadBinary(
                path,
                p.bytes!,
                fileOptions: FileOptions(contentType: p.mime, upsert: false),
              );
              urls.add(storage.getPublicUrl(path));
            }
          }
          scheduleFormValues[id] = {
            'status': _statusFor(id),
            'comment': _checkCommentCtrls[id]?.text.trim() ?? '',
            'photos': urls,
          };
        } else if (type != 'sectionHeader') {
          scheduleFormValues[id] = _textCtrls[id]?.text ?? '';
        }
      }
    }

    final effectiveAssetNumber = (t['asset_number'] as String?)?.trim();
    final areaTrim = _plantAreaCtrl.text.trim();
    final effectivePlantArea =
        areaTrim.isNotEmpty ? areaTrim : (t['plant_area'] as String?)?.trim();
    final pmTitleForShell = _pmTitleCtrl.text.trim().isNotEmpty
        ? _pmTitleCtrl.text.trim()
        : ((t['pm_title'] as String?)?.trim() ?? '');
    final headline = _composeHeadlinePreview();
    final formData = <String, dynamic>{
      'schedule_template_id': widget.scheduleTemplateId,
      'schedule_form_values': scheduleFormValues,
      'form_structure_version': widget.formStructure['version'],
      'general_comments': _commentsCtrl.text.trim(),
      'sign_name': _nameCtrl.text.trim(),
      'pm_duration': _durationCtrl.text.trim(),
      'supervisor_name': _supervisorCtrl.text.trim(),
      'follow_up_required': _followUpRequired,
      'document_update_required': _documentUpdateRequired,
      'sign_date': _signDate?.toIso8601String(),
      'approval_date': _approvalDate?.toIso8601String(),
      'wo_number': _woCtrl.text.trim(),
      'inspection_date': _inspectionDate?.toIso8601String(),
      'asset_number': effectiveAssetNumber,
      'plant_area': effectivePlantArea,
      'mobile_context_plant_area': areaTrim,
      'mobile_context_pm_title': _pmTitleCtrl.text.trim(),
      'display_headline': headline,
      'tasks': <dynamic>[],
    };

    final webFlat = <String, dynamic>{};
    for (final sec in _sections) {
      final fields = sec['fields'];
      if (fields is! List) continue;
      for (final f in fields) {
        if (f is! Map) continue;
        final m = Map<String, dynamic>.from(f);
        final id = m['id'] as String? ?? '';
        final type = m['type'] as String? ?? '';
        if (id.isEmpty || type == 'sectionHeader') continue;
        if (type == 'checkbox') {
          final st = _statusFor(id);
          if (st == 'serviceable') {
            webFlat[id] = true;
          } else if (st == 'defective') {
            webFlat[id] = 'defective';
          } else {
            webFlat[id] = false;
          }
        } else if (type == 'number') {
          final tx = _textCtrls[id]?.text.trim() ?? '';
          if (tx.isNotEmpty) {
            final n = num.tryParse(tx);
            webFlat[id] = n ?? tx;
          }
        } else {
          final tx = _textCtrls[id]?.text.trim() ?? '';
          if (tx.isNotEmpty) webFlat[id] = tx;
        }
      }
    }

    final notesOut = _commentsCtrl.text.trim().isEmpty ? null : _commentsCtrl.text.trim();

    final jobMap = <String, dynamic>{};
    final li = widget.mobileLineItemId?.trim();
    if (li != null && li.isNotEmpty) jobMap['line_item_id'] = li;
    final asg = widget.mobileAssignmentId?.trim();
    if (asg != null && asg.isNotEmpty) jobMap['assignment_id'] = asg;
    final woid = widget.mobileWorkOrderId?.trim();
    if (woid != null && woid.isNotEmpty) jobMap['work_order_id'] = woid;

    final formValuesOut = <String, dynamic>{
      ...webFlat,
      '__mobile_v1': <String, dynamic>{
        'form_data': formData,
        'defects': _collectDefectRecords(),
        'shell': <String, dynamic>{
          'pm_title': pmTitleForShell,
          'discipline': t['discipline'],
          'pm_frequency': t['pm_frequency'],
          'plant_area': effectivePlantArea,
          'display_headline': headline,
        },
        if (jobMap.isNotEmpty) 'job': jobMap,
      },
    };

    return _PmPayloadResult(
      formValuesOut: formValuesOut,
      notesOut: notesOut,
      nameTrim: _nameCtrl.text.trim(),
    );
  }

  Future<void> _saveDraft() async {
    if (widget.readOnly) return;
    final li = widget.mobileLineItemId?.trim();
    if (li == null || li.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save draft is only available from My Jobs (a line item is required).',
          ),
        ),
      );
      return;
    }
    setState(() => _savingDraft = true);
    try {
      final p = await _buildPayload();
      final user = Supabase.instance.client.auth.currentUser;
      final workspace = await fetchWorkspaceContext(Supabase.instance.client);
      final draftName = p.nameTrim.isEmpty ? 'Draft' : p.nameTrim;
      final row = <String, dynamic>{
        'template_id': widget.scheduleTemplateId,
        'submitter_name': draftName,
        'submitter_email': user?.email,
        'form_values': p.formValuesOut,
        'notes': p.notesOut,
        'status': 'draft',
        'mobile_line_item_id': li,
        if (user?.id != null) 'created_by': user!.id,
        if (workspace.mineSiteId != null) 'mine_site_id': workspace.mineSiteId,
      };
      final id = _persistedDraftId?.trim();
      if (id != null && id.isNotEmpty) {
        await Supabase.instance.client.from('pm_form_submissions').update(row).eq('id', id);
      } else {
        final ins = await Supabase.instance.client
            .from('pm_form_submissions')
            .insert(row)
            .select('id')
            .single();
        final nid = ins['id']?.toString().trim();
        if (nid != null && nid.isNotEmpty) {
          _persistedDraftId = nid;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved — you can close and tap Continue PM on My Jobs.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save draft: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _submit() async {
    final nameTrim = _nameCtrl.text.trim();
    if (nameTrim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name before submitting.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final p = await _buildPayload();
      final user = Supabase.instance.client.auth.currentUser;
      final workspace = await fetchWorkspaceContext(Supabase.instance.client);
      final updateId = (_persistedDraftId ?? widget.draftSubmissionId)?.trim();
      if (updateId != null && updateId.isNotEmpty) {
        final upd = <String, dynamic>{
          'template_id': widget.scheduleTemplateId,
          'submitter_name': nameTrim,
          'submitter_email': user?.email,
          'form_values': p.formValuesOut,
          'notes': p.notesOut,
          'status': 'submitted',
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        };
        final li = widget.mobileLineItemId?.trim();
        if (li != null && li.isNotEmpty) upd['mobile_line_item_id'] = li;
        if (user?.id != null) upd['created_by'] = user!.id;
        if (workspace.mineSiteId != null) upd['mine_site_id'] = workspace.mineSiteId;
        await Supabase.instance.client.from('pm_form_submissions').update(upd).eq('id', updateId);
      } else {
        String? submissionId;
        final fn = await Supabase.instance.client.functions.invoke(
          'mobile-submit-pm-inspection',
          body: <String, dynamic>{
            'pm_form': <String, dynamic>{
              'template_id': widget.scheduleTemplateId,
              'submitter_name': nameTrim,
              'submitter_email': user?.email,
              'form_values': p.formValuesOut,
              'notes': p.notesOut,
              if (widget.scheduledInstanceId != null &&
                  widget.scheduledInstanceId!.trim().isNotEmpty)
                'scheduled_instance_id': widget.scheduledInstanceId!.trim(),
            },
          },
        );
        if (fn.status >= 400) {
          final data = fn.data;
          final msg = data is Map
              ? (data['error']?.toString() ?? 'Submit failed (${fn.status})')
              : 'Submit failed (${fn.status})';
          throw Exception(msg);
        }
        final data = fn.data;
        if (data is Map) {
          submissionId = data['pm_submission_id']?.toString();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection submitted')),
        );

        final defectNotes = _collectDefectNotes();
        if (defectNotes.isNotEmpty) {
          await showPmGenerateWorkOrderDialog(
            context,
            widget.pmTemplateShell,
            defectSummary: defectNotes.join('; '),
            location: _plantAreaCtrl.text.trim(),
            sourceSubmissionId: submissionId,
          );
        }

        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection submitted')),
      );

      final defectNotes = _collectDefectNotes();
      if (defectNotes.isNotEmpty) {
        await showPmGenerateWorkOrderDialog(
          context,
          widget.pmTemplateShell,
          defectSummary: defectNotes.join('; '),
          location: _plantAreaCtrl.text.trim(),
          sourceSubmissionId: updateId,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (isLikelyOfflineError(e)) {
        try {
          final p = await _buildPayload();
          final user = Supabase.instance.client.auth.currentUser;
          await OfflineQueue().enqueue(
            OfflineQueueItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: OfflineQueueItemType.pmInspection,
              createdAt: DateTime.now(),
              label: widget.scheduleName ?? widget.scheduleTemplateId,
              payload: {
                'pm_form': {
                  'template_id': widget.scheduleTemplateId,
                  'submitter_name': nameTrim,
                  'submitter_email': user?.email,
                  'form_values': p.formValuesOut,
                  'notes': p.notesOut,
                  if (widget.scheduledInstanceId != null &&
                      widget.scheduledInstanceId!.trim().isNotEmpty)
                    'scheduled_instance_id': widget.scheduledInstanceId!.trim(),
                },
              },
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Saved offline — PM will sync when you are back online.',
              ),
            ),
          );
          Navigator.of(context).pop();
          return;
        } catch (_) {
          // Fall through.
        }
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.scheduleName?.trim().isNotEmpty == true ? widget.scheduleName! : '';

    return Scaffold(
      backgroundColor: _kFormBg,
      appBar: AppBar(
        backgroundColor: _kFormBg,
        foregroundColor: _kFormInk,
        elevation: 0,
        title: Text(widget.readOnly ? 'Submitted PM' : 'PM Inspection', style: const TextStyle(fontSize: 16)),
        actions: [
          if (!widget.readOnly &&
              widget.mobileLineItemId?.trim().isNotEmpty == true)
            TextButton(
              onPressed: (_savingDraft || _submitting) ? null : _saveDraft,
              child: Text(
                _savingDraft ? 'Saving…' : 'Save draft',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          if (!widget.readOnly &&
              (widget.pmTemplateShell['pm_master_list_id']?.toString().trim().isNotEmpty == true))
            IconButton(
              tooltip: 'Generate work order',
              onPressed: () => showPmGenerateWorkOrderDialog(context, widget.pmTemplateShell),
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.readOnly) ...[
            Text(
              _readOnlyHeadline(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kFormInk),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: _kFormMuted)),
            ],
          ] else ...[
            TextField(
              controller: _plantAreaCtrl,
              maxLines: 2,
              style: _kPmFieldTextStyle,
              cursorColor: _kFormInk,
              decoration: const InputDecoration(
                labelText: 'Plant / area (on this report)',
                labelStyle: _kPmFieldLabelStyle,
                floatingLabelStyle: _kPmFieldLabelStyle,
                hintText: 'e.g. Filtration Area',
                hintStyle: _kPmFieldHintStyle,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pmTitleCtrl,
              maxLines: 2,
              style: _kPmFieldTextStyle,
              cursorColor: _kFormInk,
              decoration: const InputDecoration(
                labelText: 'PM template name (on this report)',
                labelStyle: _kPmFieldLabelStyle,
                floatingLabelStyle: _kPmFieldLabelStyle,
                hintText: 'e.g. Filter Press',
                hintStyle: _kPmFieldHintStyle,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _composeHeadlinePreview(),
              style: const TextStyle(fontSize: 12, color: _kFormMuted, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            enabled: !widget.readOnly,
            controller: _woCtrl,
            style: _kPmFieldTextStyle,
            cursorColor: _kFormInk,
            decoration: const InputDecoration(
              labelText: 'Work order #',
              labelStyle: _kPmFieldLabelStyle,
              floatingLabelStyle: _kPmFieldLabelStyle,
              hintStyle: _kPmFieldHintStyle,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          for (final sec in _sections) ...[
            Text(
              (sec['title'] as String?) ?? 'Section',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _kFormInk),
            ),
            const SizedBox(height: 8),
            for (final f in _dynamicListOrEmpty(sec['fields']))
              if (f is Map) _buildGenericField(Map<String, dynamic>.from(f)),
            const SizedBox(height: 12),
          ],
          TextField(
            enabled: !widget.readOnly,
            controller: _commentsCtrl,
            maxLines: 3,
            style: _kPmFieldTextStyle,
            cursorColor: _kFormInk,
            decoration: const InputDecoration(
              labelText: 'General comments',
              labelStyle: _kPmFieldLabelStyle,
              floatingLabelStyle: _kPmFieldLabelStyle,
              hintStyle: _kPmFieldHintStyle,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: !widget.readOnly,
            controller: _nameCtrl,
            style: _kPmFieldTextStyle,
            cursorColor: _kFormInk,
            decoration: const InputDecoration(
              labelText: 'Sign name',
              labelStyle: _kPmFieldLabelStyle,
              floatingLabelStyle: _kPmFieldLabelStyle,
              hintStyle: _kPmFieldHintStyle,
              border: OutlineInputBorder(),
            ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(height: 20),
            if (widget.mobileLineItemId?.trim().isNotEmpty == true)
              OutlinedButton.icon(
                onPressed: (_savingDraft || _submitting) ? null : _saveDraft,
                icon: _savingDraft
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _savingDraft ? 'Saving draft…' : 'Save draft & exit later',
                ),
              ),
            if (widget.mobileLineItemId?.trim().isNotEmpty == true)
              const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: (_submitting || _savingDraft) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_submitting ? 'Submitting…' : 'Submit inspection'),
            ),
          ],
        ],
      ),
    );
  }
}
