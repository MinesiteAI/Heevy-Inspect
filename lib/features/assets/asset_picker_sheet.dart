import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

/// Simplified asset picker over plant_areas and plant_equipment.
class AssetPickerSheet extends StatefulWidget {
  const AssetPickerSheet({super.key});

  @override
  State<AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<AssetPickerSheet> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final equipment = await client
        .from('plant_equipment')
        .select('id, tag_number, name, area_id')
        .eq('is_active', true)
        .order('tag_number')
        .limit(500);
    final areas = await client
        .from('plant_areas')
        .select('id, name')
        .eq('is_active', true);
    final areaById = {
      for (final a in areas as List)
        a['id'] as String: a['name']?.toString() ?? '',
    };
    return [
      for (final e in equipment as List)
        {
          'id': e['id'],
          'tag_number': e['tag_number'],
          'name': e['name'],
          'area_name': areaById[e['area_id']] ?? '',
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search asset tag or name',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final q = _search.text.trim().toLowerCase();
                  final items = snapshot.data!.where((e) {
                    if (q.isEmpty) return true;
                    final tag = (e['tag_number'] ?? '').toString().toLowerCase();
                    final name = (e['name'] ?? '').toString().toLowerCase();
                    return tag.contains(q) || name.contains(q);
                  }).toList();
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final row = items[i];
                      final tag = row['tag_number']?.toString() ?? '';
                      final name = row['name']?.toString() ?? '';
                      return ListTile(
                        title: Text(tag.isNotEmpty ? tag : name),
                        subtitle: Text(name),
                        onTap: () => Navigator.pop(context, row),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
