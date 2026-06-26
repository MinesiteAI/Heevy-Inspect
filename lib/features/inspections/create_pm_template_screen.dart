import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../analytics/inspect_analytics.dart';
import '../../billing/entitlement_service.dart';
import '../../config/heevy_urls.dart';
import '../../data/pm/pm_schedule_templates_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'pm_template_service.dart';
import 'schedule_pm_form_screen.dart';

class CreatePmTemplateScreen extends StatefulWidget {
  const CreatePmTemplateScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  State<CreatePmTemplateScreen> createState() => _CreatePmTemplateScreenState();
}

class _CreatePmTemplateScreenState extends State<CreatePmTemplateScreen> {
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _taskCtrl = TextEditingController();
  final _tasks = <String>[];
  String _discipline = kPmDisciplines.first;
  String _frequency = 'Monthly';
  bool _submitting = false;
  String? _error;

  int? get _limit => widget.entitlement.pmTemplateLimitPerDiscipline;

  int _usedForDiscipline(String d) =>
      widget.entitlement.pmTemplateUsageByDiscipline[d] ?? 0;

  bool get _atCap {
    final limit = _limit;
    if (limit == null) return false;
    return _usedForDiscipline(_discipline) >= limit;
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _taskCtrl.dispose();
    super.dispose();
  }

  void _addTask() {
    final t = _taskCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _tasks.add(t);
      _taskCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a template name.');
      return;
    }
    if (_tasks.isEmpty) {
      setState(() => _error = 'Add at least one checklist task.');
      return;
    }
    if (_atCap) {
      await InspectAnalytics.track('template_create_blocked');
      await launchUrl(HeevyUrls.captureUpgrade());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await PmTemplateService(Supabase.instance.client).createTemplate(
        pmName: _name.text.trim(),
        discipline: _discipline,
        plantArea: _area.text.trim(),
        frequency: _frequency,
        taskLines: _tasks,
      );
      await InspectAnalytics.track('template_create_success');
      if (!mounted) return;
      final schedule = result['schedule_template'] as Map?;
      final templateId = schedule?['id']?.toString();
      if (templateId != null) {
        final row = await fetchPMScheduleTemplateById(
          Supabase.instance.client,
          templateId,
        );
        if (!mounted) return;
        if (row != null && row.formStructure != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SchedulePmFormScreen(
                pmTemplateShell: row.toPmTemplateShellMap(),
                scheduleTemplateId: row.id,
                scheduleName: row.pmName,
                formStructure: row.formStructure!,
              ),
            ),
          );
          return;
        }
      }
      Navigator.of(context).pop(true);
    } on PmTemplateQuotaException catch (e) {
      await InspectAnalytics.track('template_create_blocked');
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limit = _limit;
    final used = _usedForDiscipline(_discipline);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'New inspection template'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            limit != null
                ? 'Create up to $limit templates per discipline on the free tier.'
                : 'Create inspection checklists for your site.',
            style: TextStyle(color: AppColors.textMuted(context), height: 1.4),
          ),
          if (limit != null) ...[
            const SizedBox(height: 8),
            Text(
              '$used of $limit $_discipline templates used',
              style: TextStyle(
                color: _atCap ? const Color(0xFFFF453A) : AppColors.textFaint(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          HeevyField(controller: _name, hint: 'Template name', icon: Icons.title),
          const SizedBox(height: 10),
          HeevyField(controller: _area, hint: 'Plant / area', icon: Icons.place_outlined),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Discipline',
            value: _discipline,
            items: kPmDisciplines,
            onChanged: (v) => setState(() => _discipline = v ?? _discipline),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Frequency',
            value: _frequency,
            items: kPmFrequencies,
            onChanged: (v) => setState(() => _frequency = v ?? _frequency),
          ),
          const SizedBox(height: 16),
          Text(
            'Checklist tasks',
            style: TextStyle(
              color: AppColors.text(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: HeevyField(
                  controller: _taskCtrl,
                  hint: 'Task description',
                  icon: Icons.check_box_outlined,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addTask,
                icon: Icon(Icons.add_circle_outline, color: AppColors.text(context)),
              ),
            ],
          ),
          if (_tasks.isNotEmpty)
            ...[
              for (final t in _tasks)
                ListTile(
                  dense: true,
                  title: Text(t, style: TextStyle(color: AppColors.text(context))),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _tasks.remove(t)),
                  ),
                ),
            ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF453A))),
          ],
          if (_atCap) ...[
            const SizedBox(height: 16),
            HeevySecondaryButton(
              label: 'Upgrade for unlimited templates',
              onTap: () => launchUrl(HeevyUrls.captureUpgrade()),
            ),
          ],
          const SizedBox(height: 24),
          HeevyPrimaryButton(
            label: _submitting ? 'Creating…' : 'Create template',
            loading: _submitting,
            onTap: _atCap ? () => launchUrl(HeevyUrls.captureUpgrade()) : _submit,
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(heevyRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surface(context),
          style: TextStyle(color: AppColors.text(context), fontSize: 16),
          hint: Text(label, style: TextStyle(color: AppColors.textFaint(context))),
          items: [
            for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
