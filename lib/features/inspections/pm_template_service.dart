import 'package:supabase_flutter/supabase_flutter.dart';

class PmTemplateService {
  PmTemplateService(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createTemplate({
    required String pmName,
    required String discipline,
    required String plantArea,
    required String frequency,
    required List<String> taskLines,
  }) async {
    final res = await _client.functions.invoke(
      'mobile-create-pm-template',
      body: {
        'template': {
          'pm_name': pmName,
          'discipline': discipline,
          'plant_area': plantArea,
          'frequency': frequency,
        },
        'task_lines': taskLines,
      },
    );
    if (res.status >= 400) {
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw PmTemplateQuotaException(
          data['error'].toString(),
          limit: (data['limit'] as num?)?.toInt(),
          used: (data['used'] as num?)?.toInt(),
          discipline: data['discipline']?.toString(),
        );
      }
      throw Exception('Create failed (${res.status})');
    }
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response');
  }
}

class PmTemplateQuotaException implements Exception {
  PmTemplateQuotaException(
    this.message, {
    this.limit,
    this.used,
    this.discipline,
  });

  final String message;
  final int? limit;
  final int? used;
  final String? discipline;

  @override
  String toString() => message;
}

const kPmDisciplines = [
  'Mechanical',
  'Electrical',
  'Instrumentation',
  'Mobile & LVs',
  'Civil',
  'Structural',
  'Process',
  'HVAC',
  'Unassigned',
];

const kPmFrequencies = [
  'Daily',
  'Weekly',
  'Monthly',
  'Quarterly',
  '6 Monthly',
  'Annual',
];
