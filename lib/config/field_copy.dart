/// Plain-language labels for field and mining crews.
abstract final class FieldCopy {
  FieldCopy._();

  // ── Home — primary action ──────────────────────────────────────────────
  static const reportDefectTitle = 'Report a defect';
  static const reportDefectSubtitle = 'Photo + note → sends to supervisor';
  static const logDefectTitle = 'Log a defect';
  static const logDefectSubtitle = 'Photo + note from the field';

  // ── Home — section headers ─────────────────────────────────────────────
  static const sectionReport = 'REPORT';
  static const sectionJobs = 'JOBS';
  static const sectionSite = 'SITE';

  // ── Home — tiles ───────────────────────────────────────────────────────
  static const myReports = 'My reports';
  static const myReportsSubtitle = 'What you sent — drafts and waiting';
  static const crewReports = 'Crew reports';
  static const crewReportsSubtitle = 'Site queue — review on web';
  static const inspections = 'Inspections';
  static const inspectionsSubtitleField = 'Run PM checks';
  static const inspectionsSubtitleSupervisor = 'Crew PM checks';
  static const workOrders = 'Work orders';
  static const workOrdersSubtitleField = 'Jobs from your reports';
  static const workOrdersSubtitleSupervisor = 'Site work orders';
  static const photoLog = 'Photo log';
  static const photoLogSubtitle = 'Crew photos and notes';
  static const todaysHandover = "Today's handover";
  static const todaysHandoverSubtitle = 'Last 24h — captures and open reports';

  // ── Work request statuses ──────────────────────────────────────────────
  static String workRequestStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'draft') return 'Draft';
    if (s == 'open') return 'Open';
    if (s == 'pending approval') return 'Waiting for supervisor';
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    return status ?? '';
  }

  // ── Supervisor strip ───────────────────────────────────────────────────
  static String crewDraftsAwaiting(int count) =>
      '$count crew report${count == 1 ? '' : 's'} not sent yet';

  // ── Photo log ──────────────────────────────────────────────────────────
  static const photoLogEmptyField =
      'Tap Report a defect on home to log your first issue.';
  static const photoLogEmptyTeam = 'Crew photos appear here after they report.';

  // ── Quick capture screen ───────────────────────────────────────────────
  static const quickCaptureScreenTitle = reportDefectTitle;

  // ── Work requests list ─────────────────────────────────────────────────
  static const wrEmptyFieldSubtitle =
      'Create a draft or use Report a defect with a photo.';
  static const wrEmptyQuickCapture = 'Or report a defect';

  // ── Account menu ───────────────────────────────────────────────────────
  static const signOut = 'Sign out';
  static const signOutConfirmTitle = 'Sign out?';
  static String signOutConfirmBody(String siteName) =>
      siteName.isNotEmpty ? 'Sign out of $siteName?' : 'Sign out of Heevy Inspect?';
  static const themeLight = 'Light mode';
  static const themeDark = 'Dark mode';
}
