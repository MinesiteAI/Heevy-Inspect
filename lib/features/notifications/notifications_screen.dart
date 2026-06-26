import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notifications/notification_router.dart';
import '../../notifications/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service =
      NotificationService(Supabase.instance.client);
  List<AppNotification> _items = const [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.list(limit: 100);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _unreadCount = page.unreadCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;
    for (final n in _items.where((n) => !n.read)) {
      try {
        await _service.update(n.id, 'mark_read');
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _openNotification(AppNotification n) async {
    if (!n.read) {
      try {
        await _service.update(n.id, 'mark_read');
      } catch (_) {}
    }
    if (!mounted) return;
    await NotificationRouter.open(context, n);
    await _load();
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: 'Notifications',
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: TextStyle(color: AppColors.textMuted(context)),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.text(context),
        backgroundColor: AppColors.surface(context),
        child: _loading
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textMuted(context),
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                ],
              )
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load notifications',
                    subtitle: _error!,
                  ),
                ],
              )
            : _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.notifications_none_outlined,
                    title: 'No notifications',
                    subtitle:
                        'Alerts for work requests, PMs, and work orders appear here.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = _items[i];
                  return Material(
                    color: n.read
                        ? AppColors.surface(context)
                        : AppColors.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openNotification(n),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(
                                color: AppColors.text(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(n.time),
                              style: TextStyle(
                                color: AppColors.textFaint(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
