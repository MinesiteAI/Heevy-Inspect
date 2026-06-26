/// When to show Plant CMMS upgrade prompts in field vs supervisor flows.
class UpgradeCtaPolicy {
  const UpgradeCtaPolicy._();

  /// Field workers should not see mid-flow upgrade sales; supervisors may.
  static bool showCaptureFlowUpgrade({required bool isOrgManager}) => isOrgManager;

  /// Plant feature locks (schedule, crew, stores) — supervisors considering upgrade.
  static bool showPlantFeatureLocks({
    required bool allowsPlant,
    required bool isOrgManager,
  }) =>
      !allowsPlant && isOrgManager;

  /// Contextual upgrade on home strip when PM compliance needs scheduling.
  static bool showSupervisorSchedulingUpgrade({
    required bool allowsPlant,
    required int overduePms,
  }) =>
      !allowsPlant && overduePms > 0;

  /// Home-screen Plant CMMS upgrade tile — supervisors only.
  static bool showHomeUpgradeTile({required bool isOrgManager}) => isOrgManager;

  /// Mobile WO creation — supervisors (or full Plant entitlement).
  static bool canCreateWorkOrderOnMobile({
    required bool isOrgManager,
    required bool allowsPlant,
  }) =>
      isOrgManager || allowsPlant;
}
