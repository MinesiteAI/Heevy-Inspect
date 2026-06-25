import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingStatus {
  const OnboardingStatus({
    required this.stage,
    required this.stageLabel,
    required this.uploadsCount,
    required this.uploadsTarget,
    required this.provisioned,
  });

  final String stage;
  final String stageLabel;
  final int uploadsCount;
  final int uploadsTarget;
  final bool provisioned;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      stage: (json['stage'] as String?) ?? 'pending_gate',
      stageLabel: (json['stage_label'] as String?) ?? 'Site setup',
      uploadsCount: (json['uploads_count'] as num?)?.toInt() ?? 0,
      uploadsTarget: (json['uploads_target'] as num?)?.toInt() ?? 6,
      provisioned: json['provisioned'] == true,
    );
  }
}

class EntitlementResult {
  const EntitlementResult({
    required this.access,
    required this.source,
    required this.setupRequired,
    this.isApplicant = false,
    this.trialEndsAt,
    this.applicationId,
    this.onboardingStage,
    this.onboarding,
    this.requiresSubscription = false,
    this.companyManagesBilling = false,
    this.isOrgManager = false,
    this.organizationId,
    this.organizationName,
    this.orgPack,
    this.allowsFieldCapture = true,
    this.allowsPlant = false,
  });

  final bool access;
  final String source;
  final bool setupRequired;
  final bool isApplicant;
  final DateTime? trialEndsAt;
  final String? applicationId;
  final String? onboardingStage;
  final OnboardingStatus? onboarding;
  final bool requiresSubscription;
  final bool companyManagesBilling;
  final bool isOrgManager;
  final String? organizationId;
  final String? organizationName;
  final List<String>? orgPack;
  final bool allowsFieldCapture;
  final bool allowsPlant;

  bool get isOrganizationMember =>
      source == 'organization' || companyManagesBilling;

  bool get showPmTemplates => allowsPlant;

  factory EntitlementResult.fromJson(Map<String, dynamic> json) {
    DateTime? trial;
    final rawTrial = json['trial_ends_at'];
    if (rawTrial is String && rawTrial.isNotEmpty) {
      trial = DateTime.tryParse(rawTrial);
    }
    OnboardingStatus? onboarding;
    final rawOnboarding = json['onboarding'];
    if (rawOnboarding is Map<String, dynamic>) {
      onboarding = OnboardingStatus.fromJson(rawOnboarding);
    }
    List<String>? pack;
    final rawPack = json['org_pack'];
    if (rawPack is List) {
      pack = rawPack.map((e) => e.toString()).toList();
    }
    return EntitlementResult(
      access: json['access'] == true,
      source: (json['source'] as String?) ?? 'none',
      setupRequired: json['setup_required'] == true,
      isApplicant: json['is_applicant'] == true,
      trialEndsAt: trial,
      applicationId: json['application_id'] as String?,
      onboardingStage: json['onboarding_stage'] as String?,
      onboarding: onboarding,
      requiresSubscription: json['requires_subscription'] == true,
      companyManagesBilling: json['company_manages_billing'] == true,
      isOrgManager: json['is_org_manager'] == true,
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      orgPack: pack,
      allowsFieldCapture: json['allows_field_capture'] != false,
      allowsPlant: json['allows_plant'] == true,
    );
  }

  static const EntitlementResult denied = EntitlementResult(
    access: false,
    source: 'none',
    setupRequired: false,
    requiresSubscription: true,
  );
}

class EntitlementService {
  EntitlementService(this._client);

  final SupabaseClient _client;

  Future<EntitlementResult> check() async {
    final FunctionResponse res;
    try {
      res = await _client.functions.invoke('check-entitlement', body: {});
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
    if (res.status == 401 || res.status == 403) {
      throw Exception('Unauthorized (${res.status})');
    }
    if (res.status != 200) return EntitlementResult.denied;
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return EntitlementResult.fromJson(data);
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return EntitlementResult.fromJson(decoded);
      }
    }
    return EntitlementResult.denied;
  }

  Future<void> registerApplicant({
    required String fullName,
    required String companyName,
    String? phone,
    String? siteLocation,
    Map<String, dynamic>? acquisitionExtra,
  }) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Authentication session missing. Please sign in again.');
    }
    final res = await _client.functions.invoke(
      'mobile-register-applicant',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'full_name': fullName,
        'company_name': companyName,
        'product': 'heevy_inspect',
        'modules_of_interest': ['field_capture', 'mobile_app'],
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (siteLocation != null && siteLocation.isNotEmpty)
          'site_location': siteLocation,
        if (acquisitionExtra != null) ...acquisitionExtra,
      },
    );
    if (res.status != 200) {
      final err = res.data;
      final msg =
          err is Map ? (err['error'] ?? err).toString() : 'Registration failed';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> acceptInvite(String token) async {
    final res = await _client.functions.invoke(
      'accept-workspace-invite',
      body: {'token': token.trim()},
    );
    final data = res.data;
    Map<String, dynamic> map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is String) {
      map = Map<String, dynamic>.from(jsonDecode(data) as Map);
    } else {
      map = {};
    }
    if (res.status != 200) {
      throw Exception(map['error']?.toString() ?? 'Could not accept invitation');
    }
    return map;
  }
}
