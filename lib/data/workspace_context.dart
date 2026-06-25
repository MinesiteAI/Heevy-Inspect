import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolved company / site labels for the signed-in user's workspace.
class WorkspaceContext {
  const WorkspaceContext({
    this.organizationId,
    this.organizationName,
    this.mineSiteId,
    this.mineSiteName,
  });

  final String? organizationId;
  final String? organizationName;
  final String? mineSiteId;
  final String? mineSiteName;

  static const empty = WorkspaceContext();

  /// Best label for PM headlines and capture context (site name, then company).
  String get siteDisplayName {
    final site = mineSiteName?.trim();
    if (site != null && site.isNotEmpty) return site;
    final org = organizationName?.trim();
    if (org != null && org.isNotEmpty) return org;
    return '';
  }
}

Future<WorkspaceContext> fetchWorkspaceContext(SupabaseClient client) async {
  final uid = client.auth.currentUser?.id;
  if (uid == null) return WorkspaceContext.empty;

  final profile = await client
      .from('profiles')
      .select('organization_id')
      .eq('id', uid)
      .maybeSingle();
  if (profile == null) return WorkspaceContext.empty;

  final orgId = profile['organization_id']?.toString();
  if (orgId == null || orgId.isEmpty) return WorkspaceContext.empty;

  String? orgName;
  final orgRow = await client
      .from('organizations')
      .select('name')
      .eq('id', orgId)
      .maybeSingle();
  orgName = orgRow?['name']?.toString();

  String? siteId;
  String? siteName;
  final siteRow = await client
      .from('mine_sites')
      .select('id, name')
      .eq('organization_id', orgId)
      .eq('is_active', true)
      .order('created_at', ascending: true)
      .limit(1)
      .maybeSingle();
  if (siteRow != null) {
    siteId = siteRow['id']?.toString();
    siteName = siteRow['name']?.toString();
  }

  return WorkspaceContext(
    organizationId: orgId,
    organizationName: orgName,
    mineSiteId: siteId,
    mineSiteName: siteName,
  );
}

String composePmHeadline({
  String? siteDisplayName,
  required String area,
  required String title,
}) {
  final site = siteDisplayName?.trim() ?? '';
  final a = area.trim();
  final t = title.trim().isEmpty ? 'PM' : title.trim();
  if (site.isNotEmpty && a.isNotEmpty) return '$site $a - $t';
  if (site.isNotEmpty) return '$site — $t';
  if (a.isNotEmpty) return '$a — $t';
  return t;
}
