import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import 'capture_service.dart';

class CaptureHistoryScreen extends StatefulWidget {
  const CaptureHistoryScreen({super.key});

  @override
  State<CaptureHistoryScreen> createState() => _CaptureHistoryScreenState();
}

class _CaptureHistoryScreenState extends State<CaptureHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = CaptureService(Supabase.instance.client).listMyCaptures();
  }

  Future<void> _refresh() async {
    final f = CaptureService(Supabase.instance.client).listMyCaptures();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('My captures'),
        backgroundColor: AppColors.bg(context),
        foregroundColor: AppColors.text(context),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No captures yet')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final row = items[i];
                final area = row['plant_area']?.toString() ?? '—';
                final sev = row['severity']?.toString() ?? '';
                final notes = row['notes']?.toString() ?? '';
                final created = row['created_at']?.toString() ?? '';
                return Card(
                  color: AppColors.card(context),
                  child: ListTile(
                    title: Text(area),
                    subtitle: Text(
                      [sev, notes, created].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: const Icon(Icons.camera_alt_outlined),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
