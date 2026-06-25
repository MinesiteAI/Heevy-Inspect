import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Mirrors web [`PM_SCHEDULE_SELECT`] in `minesite-io/src/lib/api/pmForms.ts`.
const String kPmScheduleSelect = '''
  id,
  name,
  area,
  frequency_type,
  form_structure,
  is_active,
  pm_master_list_id,
  pm_master_list ( id, pm_name, plant_area, frequency, discipline, duty_type )
''';

/// Normalised PM schedule row — same field sourcing as web `normalisePMScheduleRow`.
class PMScheduleTemplateRow {
  PMScheduleTemplateRow({
    required this.id,
    required this.pmName,
    required this.plantArea,
    required this.frequency,
    this.discipline,
    this.dutyType,
    this.formStructure,
    required this.isActive,
    this.pmMasterListId,
  });

  final String id;
  final String pmName;
  final String plantArea;
  final String frequency;
  final String? discipline;
  final String? dutyType;
  final Map<String, dynamic>? formStructure;
  final bool isActive;
  final String? pmMasterListId;

  /// Same rule as web `PMFormsTab` / `TemplateCard`: `!!template.form_structure`
  /// (any non-null JSON object counts; empty `{}` still counts as attached on web).
  bool get hasForm => formStructure != null;

  /// True when there is likely renderable checklist content (sections with fields).
  bool get hasRenderableChecklist {
    if (formStructure == null) return false;
    final sec = formStructure!['sections'];
    if (sec is! List) return false;
    for (final s in sec) {
      if (s is! Map) continue;
      final fields = s['fields'];
      if (fields is List && fields.isNotEmpty) return true;
    }
    return false;
  }

  bool get isDaily => frequency.toLowerCase().trim() == 'daily';

  /// Display map for list tiles / [SchedulePmFormScreen.pmTemplateShell].
  /// `id` is always `pm_schedule_templates.id` (used as `template_id` for `pm_form_submissions`).
  Map<String, dynamic> toPmTemplateShellMap() {
    final d = (discipline?.trim().isNotEmpty == true)
        ? discipline!.trim()
        : (plantArea.trim().isNotEmpty ? plantArea.trim() : 'Unassigned');
    return {
      'id': id,
      'pm_title': pmName.trim().isNotEmpty ? pmName.trim() : 'Untitled PM',
      'discipline': d,
      'pm_frequency': frequency,
      'plant_area': plantArea,
      'location_area': plantArea,
      'schedule_template_id': id,
      'duty_type': dutyType,
      'pm_master_list_id': pmMasterListId,
    };
  }

  static PMScheduleTemplateRow fromSupabaseJson(Map<String, dynamic> row) {
    final master = row['pm_master_list'];
    final masterMap = master is Map
        ? Map<String, dynamic>.from(master)
        : <String, dynamic>{};

    String pickMasterOrRow(String masterKey, String rowKey) {
      final mv = masterMap[masterKey];
      if (mv != null && mv.toString().trim().isNotEmpty) {
        return mv.toString().trim();
      }
      final rv = row[rowKey];
      return rv?.toString().trim() ?? '';
    }

    final formStructure = _parseFormStructureJson(row['form_structure']);

    return PMScheduleTemplateRow(
      id: row['id']?.toString() ?? '',
      pmName: pickMasterOrRow('pm_name', 'name'),
      plantArea: pickMasterOrRow('plant_area', 'area'),
      frequency: pickMasterOrRow('frequency', 'frequency_type'),
      discipline: masterMap['discipline']?.toString().trim().isNotEmpty == true
          ? masterMap['discipline']?.toString().trim()
          : null,
      dutyType: masterMap['duty_type']?.toString(),
      formStructure: formStructure,
      isActive: row['is_active'] == true,
      pmMasterListId: row['pm_master_list_id']?.toString(),
    );
  }
}

/// Normalises `form_structure` from PostgREST (Map or JSON string, nested maps).
Map<String, dynamic>? _parseFormStructureJson(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty || t == 'null') return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map) {
        return Map<String, dynamic>.from(
          jsonDecode(jsonEncode(decoded)) as Map<dynamic, dynamic>,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
  if (raw is Map) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(raw)) as Map<dynamic, dynamic>,
      );
    } catch (_) {
      return Map<String, dynamic>.from(raw);
    }
  }
  return null;
}

/// Use when reading raw PostgREST `form_structure` outside [PMScheduleTemplateRow.fromSupabaseJson].
Map<String, dynamic>? parsePmFormStructureJson(dynamic raw) =>
    _parseFormStructureJson(raw);

/// Same contract as web `fetchPMTemplates`.
Future<List<PMScheduleTemplateRow>> fetchPMScheduleTemplates(
  SupabaseClient client,
) async {
  final data = await client
      .from('pm_schedule_templates')
      .select(kPmScheduleSelect)
      .eq('is_active', true)
      .order('area');

  final list = data as List<dynamic>;
  return [
    for (final raw in list)
      PMScheduleTemplateRow.fromSupabaseJson(
        Map<String, dynamic>.from(raw as Map),
      ),
  ];
}

Future<PMScheduleTemplateRow?> fetchPMScheduleTemplateById(
  SupabaseClient client,
  String id,
) async {
  final row = await client
      .from('pm_schedule_templates')
      .select(kPmScheduleSelect)
      .eq('id', id)
      .maybeSingle();
  if (row == null) return null;
  return PMScheduleTemplateRow.fromSupabaseJson(
    Map<String, dynamic>.from(row),
  );
}
