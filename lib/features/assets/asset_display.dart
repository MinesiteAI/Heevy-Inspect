/// Human-readable labels for plant equipment rows from [AssetPickerSheet].
String assetDisplayLabel(Map<String, dynamic> row) {
  final tag = row['tag_number']?.toString().trim() ?? '';
  if (tag.isNotEmpty) return tag;
  final name = row['name']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;
  final id = row['id']?.toString().trim() ?? '';
  if (id.isNotEmpty) return id;
  return 'Asset';
}

/// Tag for API payloads — prefers tag_number, falls back to name.
String? assetTagForPayload(Map<String, dynamic> row) {
  final tag = row['tag_number']?.toString().trim() ?? '';
  if (tag.isNotEmpty) return tag;
  final name = row['name']?.toString().trim() ?? '';
  return name.isNotEmpty ? name : null;
}

String? assetTagFromStored({String? tag, String? displayLabel}) {
  final t = tag?.trim() ?? '';
  if (t.isNotEmpty) return t;
  final d = displayLabel?.trim() ?? '';
  return d.isNotEmpty ? d : null;
}
