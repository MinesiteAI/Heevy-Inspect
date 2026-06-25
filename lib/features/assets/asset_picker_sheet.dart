import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';

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
    _search.addListener(() => setState(() {}));
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
    return ColoredBox(
      color: AppColors.sheet(context),
      child: Padding(
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Pick asset',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HeevyField(
                  controller: _search,
                  hint: 'Search asset tag or name',
                  icon: Icons.search,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.textMuted(context),
                          strokeWidth: 2.2,
                        ),
                      );
                    }
                    final q = _search.text.trim().toLowerCase();
                    final items = snapshot.data!.where((e) {
                      if (q.isEmpty) return true;
                      final tag =
                          (e['tag_number'] ?? '').toString().toLowerCase();
                      final name = (e['name'] ?? '').toString().toLowerCase();
                      return tag.contains(q) || name.contains(q);
                    }).toList();
                    if (items.isEmpty) {
                      return const HeevyEmptyState(
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'No assets found',
                        subtitle: 'Try a different search term.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final row = items[i];
                        final tag = row['tag_number']?.toString() ?? '';
                        final name = row['name']?.toString() ?? '';
                        final area = row['area_name']?.toString() ?? '';
                        return Material(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context, row),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.precision_manufacturing_outlined,
                                    color: AppColors.textMuted(context),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tag.isNotEmpty ? tag : name,
                                          style: TextStyle(
                                            color: AppColors.text(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (name.isNotEmpty && tag.isNotEmpty)
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        if (area.isNotEmpty)
                                          Text(
                                            area,
                                            style: TextStyle(
                                              color: AppColors.textFaint(
                                                context,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textFaint(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
