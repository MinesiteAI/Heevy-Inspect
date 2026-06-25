import 'dart:convert';

/// Flattened checklist line from [pm_master_list.tasks] (mirrors web
/// `flattenPMTasks` / `canFlattenPMTasks` in minesite-io `pm-tasks-utils.ts`).
class PmFlatTask {
  PmFlatTask({this.section, required this.description});
  final String? section;
  final String description;
}

String _describe(dynamic entry) {
  if (entry is String) return entry;
  if (entry is! Map) return '';
  final obj = Map<String, dynamic>.from(entry);
  return (obj['task'] ?? obj['description'] ?? obj['item'] ?? obj['name'] ?? obj['label'] ?? '')
      .toString();
}

bool canFlattenPmTasks(dynamic tasks) {
  if (tasks == null) return false;
  if (tasks is List) return tasks.isNotEmpty;
  if (tasks is! Map) return false;
  final data = Map<String, dynamic>.from(tasks);
  if (data['sections'] is List && (data['sections'] as List).isNotEmpty) return true;
  if (data['assetSections'] is List && (data['assetSections'] as List).isNotEmpty) return true;
  if (data['inspectionSteps'] is List && (data['inspectionSteps'] as List).isNotEmpty) return true;
  if (data['testItems'] is List && (data['testItems'] as List).isNotEmpty) return true;
  if (data['locations'] is List &&
      data['inspectionItems'] is List &&
      (data['locations'] as List).isNotEmpty &&
      (data['inspectionItems'] as List).isNotEmpty) {
    return true;
  }
  if (data['generatorLocations'] is List && (data['generatorLocations'] as List).isNotEmpty) {
    return true;
  }
  if (data['area'] is String && data['circuits'] is List && (data['circuits'] as List).isNotEmpty) {
    return true;
  }
  for (final v in data.values) {
    if (v is List && v.isNotEmpty) return true;
  }
  return false;
}

List<PmFlatTask> flattenPmTasks(dynamic tasks) {
  final out = <PmFlatTask>[];

  void pushTask(String description, String? section) {
    final d = description.trim();
    if (d.isEmpty) return;
    out.add(PmFlatTask(section: section, description: d));
  }

  if (tasks == null) return out;

  if (tasks is List) {
    final list = tasks;
    if (list.isEmpty) return out;
    final first = list.first;
    var isArrayOfSections = false;
    if (first is Map) {
      final fm = Map<String, dynamic>.from(first);
      isArrayOfSections =
          fm['tasks'] is List || fm['items'] is List || fm['checks'] is List;
    }

    if (isArrayOfSections) {
      for (final sec in list) {
        if (sec is! Map) continue;
        final m = Map<String, dynamic>.from(sec);
        final sectionName = (m['equipmentName'] ?? m['sectionName'] ?? m['name'])?.toString();
        final items = (m['tasks'] ?? m['items'] ?? m['checks']) as List? ?? const [];
        for (final entry in items) {
          pushTask(_describe(entry), sectionName);
        }
      }
      return out;
    }

    for (final entry in list) {
      pushTask(_describe(entry), null);
    }
    return out;
  }

  if (tasks is! Map) return out;
  final data = Map<String, dynamic>.from(tasks);

  if (data['sections'] is List) {
    for (final sec in data['sections'] as List) {
      if (sec is! Map) continue;
      final m = Map<String, dynamic>.from(sec);
      final sectionName = (m['equipmentName'] ?? m['sectionName'] ?? m['name'])?.toString();
      final items = (m['tasks'] ?? m['items']) as List? ?? const [];
      for (final entry in items) {
        pushTask(_describe(entry), sectionName);
      }
    }
    return out;
  }

  if (data['assetSections'] is List) {
    for (final sec in data['assetSections'] as List) {
      if (sec is! Map) continue;
      final m = Map<String, dynamic>.from(sec);
      final sectionName = (m['assetName'] ?? m['sectionName'])?.toString();
      final items = (m['checks'] ?? m['tasks']) as List? ?? const [];
      for (final entry in items) {
        pushTask(_describe(entry), sectionName);
      }
    }
    return out;
  }

  if (data['locations'] is List && data['inspectionItems'] is List) {
    for (final loc in data['locations'] as List) {
      final sectionName = _describe(loc);
      for (final entry in data['inspectionItems'] as List) {
        pushTask(_describe(entry), sectionName.isEmpty ? null : sectionName);
      }
    }
    return out;
  }

  if (data['inspectionSteps'] is List) {
    for (final entry in data['inspectionSteps'] as List) {
      pushTask(_describe(entry), 'Inspection Procedure');
    }
    return out;
  }

  if (data['testItems'] is List) {
    for (final entry in data['testItems'] as List) {
      pushTask(_describe(entry), null);
    }
    return out;
  }

  if (data['generatorLocations'] is List) {
    for (final gen in data['generatorLocations'] as List) {
      if (gen is! Map) continue;
      final gm = Map<String, dynamic>.from(gen);
      final sectionName = (gm['area'] ?? gm['name'])?.toString();
      final circuits = gm['circuits'] as List? ?? const [];
      for (final circuit in circuits) {
        if (circuit is! Map) continue;
        final cm = Map<String, dynamic>.from(circuit);
        final desc = (cm['description'] ?? '').toString();
        final rating = (cm['rating'] ?? '').toString();
        final line = desc.isEmpty
            ? rating
            : (rating.isEmpty ? desc : '$desc — Rating: $rating');
        pushTask(line, sectionName);
      }
    }
    return out;
  }

  if (data['area'] is String && data['circuits'] is List) {
    final sectionName = data['area']!.toString();
    for (final circuit in data['circuits'] as List) {
      if (circuit is! Map) continue;
      final cm = Map<String, dynamic>.from(circuit);
      final desc = (cm['description'] ?? '').toString();
      final rating = (cm['rating'] ?? '').toString();
      final line = desc.isEmpty
          ? rating
          : (rating.isEmpty ? desc : '$desc — Rating: $rating');
      pushTask(line, sectionName);
    }
    return out;
  }

  String toTitleCase(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  var used = false;
  for (final e in data.entries) {
    final value = e.value;
    if (value is! List || value.isEmpty) continue;
    used = true;
    final sectionName = toTitleCase(e.key);
    for (final entry in value) {
      pushTask(_describe(entry), sectionName);
    }
  }
  if (used) return out;

  return out;
}

/// Builds a web-style `form_structure` map for [SchedulePmFormScreen].
Map<String, dynamic>? formStructureFromPmTasks(dynamic tasks) {
  if (!canFlattenPmTasks(tasks)) return null;
  final flat = flattenPmTasks(tasks);
  if (flat.isEmpty) return null;

  final bySection = <String?, List<PmFlatTask>>{};
  for (final t in flat) {
    bySection.putIfAbsent(t.section, () => []).add(t);
  }

  final sections = <Map<String, dynamic>>[];
  var si = 0;
  for (final e in bySection.entries) {
    si++;
    final title = (e.key == null || e.key!.isEmpty) ? 'INSPECTIONS' : e.key!;
    final fields = <Map<String, dynamic>>[];
    var fi = 0;
    for (final task in e.value) {
      fi++;
      fields.add({
        'id': 'pm_task_${si}_$fi',
        'type': 'checkbox',
        'label': task.description,
      });
    }
    sections.add({
      'id': 'sec_$si',
      'title': title,
      'fields': fields,
    });
  }

  return {'sections': sections};
}

Map<String, dynamic>? mergeFormStructures(
  Map<String, dynamic>? scheduleJson,
  Map<String, dynamic>? fromTasks,
) {
  if (scheduleJson != null && scheduleJson.isNotEmpty) {
    final sec = scheduleJson['sections'];
    if (sec is List && sec.isNotEmpty) {
      return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(scheduleJson)) as Map<dynamic, dynamic>,
      );
    }
  }
  return fromTasks;
}
