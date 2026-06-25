import 'package:supabase_flutter/supabase_flutter.dart';

import 'pm_schedule_templates_api.dart';
import 'pm_tasks_form_bridge.dart';

/// Same source as web Plant → PM Forms → PM Templates (`PMTemplatesHub`):
/// [pm_master_list], with checklist content from [tasks] and/or linked
/// [pm_schedule_templates.form_structure].
const String kPmMasterPlantSelect = '''
  id,
  pm_name,
  discipline,
  frequency,
  equipment_type,
  estimated_duration,
  asset_number,
  resources,
  status,
  plant_area,
  duty_type,
  plan_type,
  tasks
''';

String normalizePmDiscipline(String? d) {
  if (d == null) return 'Uncategorized';
  final lower = d.toLowerCase().trim();
  if (['mechanical', 'mech'].contains(lower)) return 'Mechanical';
  if (['electrical', 'elec'].contains(lower)) return 'Electrical';
  if ([
    'mobile & lvs',
    'mobile_lvs',
    'mobile',
    'mobile equipment',
  ].contains(lower)) {
    return 'Mobile & LVs';
  }
  return d.trim();
}

double parseEstimatedHours(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 0;
  final text = raw.toLowerCase().trim();
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  if (match == null) return 0;
  final num = double.tryParse(match.group(1) ?? '') ?? 0;
  if (text.contains('min')) return num / 60;
  return num;
}

Map<String, dynamic>? _pickScheduleRow(List<dynamic> rawList) {
  if (rawList.isEmpty) return null;
  bool active(Map<String, dynamic> m) {
    final a = m['is_active'];
    return a != false;
  }

  final rows = rawList
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where(active)
      .toList();
  if (rows.isEmpty) return null;

  Map<String, dynamic>? bestWithForm;
  DateTime? bestTs;
  for (final r in rows) {
    final fs = parsePmFormStructureJson(r['form_structure']);
    if (fs == null || fs.isEmpty) continue;
    final sec = fs['sections'];
    if (sec is! List || sec.isEmpty) continue;
    final ts = DateTime.tryParse((r['updated_at'] ?? '').toString());
    if (bestWithForm == null || (ts != null && (bestTs == null || ts.isAfter(bestTs)))) {
      bestWithForm = r;
      bestTs = ts;
    }
  }
  if (bestWithForm != null) return bestWithForm;

  rows.sort((a, b) {
    final ta = DateTime.tryParse((a['updated_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final tb = DateTime.tryParse((b['updated_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });
  return rows.first;
}

/// One row for the PM Design list: mirrors plant hub + schedule linkage.
class PlantPmInspectionRow {
  PlantPmInspectionRow({
    required this.pmMasterListId,
    this.scheduleTemplateId,
    required this.pmName,
    required this.plantArea,
    required this.frequency,
    required this.discipline,
    this.dutyType,
    this.equipmentType,
    this.estimatedDuration,
    this.assetNumber,
    this.resources,
    this.formStructure,
    required this.hasForm,
    required this.hasRenderableChecklist,
  });

  final String pmMasterListId;
  final String? scheduleTemplateId;
  final String pmName;
  final String plantArea;
  final String frequency;
  final String discipline;
  final String? dutyType;
  final String? equipmentType;
  final String? estimatedDuration;
  final String? assetNumber;
  final String? resources;
  final Map<String, dynamic>? formStructure;
  final bool hasForm;
  final bool hasRenderableChecklist;

  bool get isDaily => frequency.toLowerCase().trim() == 'daily';

  Map<String, dynamic> toInspectionListMap(String displayHeadline) {
    final sid = scheduleTemplateId?.trim();
    return <String, dynamic>{
      'id': (sid != null && sid.isNotEmpty) ? sid : pmMasterListId,
      'pm_title': pmName.trim().isNotEmpty ? pmName.trim() : 'Untitled PM',
      'discipline': discipline,
      'pm_frequency': frequency,
      'plant_area': plantArea,
      'location_area': plantArea,
      'schedule_template_id': sid ?? '',
      'pm_master_list_id': pmMasterListId,
      'duty_type': dutyType,
      'equipment_type': equipmentType,
      'estimated_duration': estimatedDuration,
      'asset_number': assetNumber,
      'resources': resources,
      'display_headline': displayHeadline,
      'has_form': hasForm,
      'has_renderable_checklist': hasRenderableChecklist,
      'is_daily': isDaily,
      if (formStructure != null) 'form_structure': formStructure,
    };
  }
}

/// Fetches PM templates the same way as web [PMTemplatesHub] (master list),
/// then attaches the best matching [pm_schedule_templates] row per master
/// for submissions + optional JSON [form_structure].
Future<List<PlantPmInspectionRow>> fetchPlantPmInspectionTemplates(
  SupabaseClient client,
) async {
  final masterData = await client
      .from('pm_master_list')
      .select(kPmMasterPlantSelect)
      .or('plan_type.eq.pm,plan_type.is.null')
      .order('discipline')
      .order('pm_name');

  final masterList = List<dynamic>.from(masterData as List);
  final masterIds = <String>[];
  for (final raw in masterList) {
    if (raw is! Map) continue;
    final id = raw['id']?.toString();
    if (id != null && id.isNotEmpty) masterIds.add(id);
  }

  final schedulesByMaster = <String, List<Map<String, dynamic>>>{};
  const chunk = 120;
  for (var i = 0; i < masterIds.length; i += chunk) {
    final end = i + chunk > masterIds.length ? masterIds.length : i + chunk;
    final slice = masterIds.sublist(i, end);
    if (slice.isEmpty) continue;
    final schedData = await client
        .from('pm_schedule_templates')
        .select('id, pm_master_list_id, form_structure, is_active, updated_at')
        .inFilter('pm_master_list_id', slice);
    final schedList = List<dynamic>.from(schedData as List);
    for (final s in schedList) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final mid = m['pm_master_list_id']?.toString();
      if (mid == null || mid.isEmpty) continue;
      schedulesByMaster.putIfAbsent(mid, () => []).add(m);
    }
  }

  final out = <PlantPmInspectionRow>[];
  for (final raw in masterList) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    final masterId = row['id']?.toString() ?? '';
    if (masterId.isEmpty) continue;

    final pmName = (row['pm_name'] ?? '').toString().trim();
    final plantArea = (row['plant_area'] ?? '').toString().trim();
    final frequency = (row['frequency'] ?? '').toString().trim();
    final disc = normalizePmDiscipline(row['discipline']?.toString());
    final dutyType = row['duty_type']?.toString();
    final equipmentType = row['equipment_type']?.toString();
    final estimatedDuration = row['estimated_duration']?.toString();
    final assetNumber = row['asset_number']?.toString();
    final resources = row['resources']?.toString();
    final tasks = row['tasks'];

    final schedPick = _pickScheduleRow(schedulesByMaster[masterId] ?? const []);
    final sid = schedPick?['id']?.toString();

    final fromSchedule = parsePmFormStructureJson(schedPick?['form_structure']);
    final fromTasks = formStructureFromPmTasks(tasks);
    final merged = mergeFormStructures(fromSchedule, fromTasks);

    var hasRenderable = false;
    if (merged != null) {
      final sec = merged['sections'];
      if (sec is List) {
        for (final s in sec) {
          if (s is! Map) continue;
          final fields = (Map<String, dynamic>.from(s))['fields'];
          if (fields is List && fields.isNotEmpty) {
            hasRenderable = true;
            break;
          }
        }
      }
    }

    final hasForm = merged != null;

    out.add(
      PlantPmInspectionRow(
        pmMasterListId: masterId,
        scheduleTemplateId: sid,
        pmName: pmName,
        plantArea: plantArea,
        frequency: frequency,
        discipline: disc,
        dutyType: dutyType,
        equipmentType: equipmentType,
        estimatedDuration: estimatedDuration,
        assetNumber: assetNumber,
        resources: resources,
        formStructure: merged,
        hasForm: hasForm,
        hasRenderableChecklist: hasRenderable,
      ),
    );
  }

  return out;
}

String plantPmDisplayHeadline(PlantPmInspectionRow r, {String siteName = 'Tennant Creek'}) {
  final area = r.plantArea.trim();
  final title = r.pmName.trim().isNotEmpty ? r.pmName.trim() : 'PM';
  if (area.isEmpty) return '$siteName — $title';
  return '$siteName $area - $title';
}
