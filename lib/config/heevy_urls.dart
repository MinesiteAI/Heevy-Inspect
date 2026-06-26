abstract final class HeevyUrls {
  static const String appBase = String.fromEnvironment(
    'MINESITE_APP_BASE',
    defaultValue: 'https://openminerals.ai',
  );

  static Uri apply({String? source}) {
    final q = source != null ? '?source=$source' : '';
    return Uri.parse('$appBase/apply$q');
  }

  static Uri myApplication({String? source}) {
    final q = source != null ? '?source=$source' : '';
    return Uri.parse('$appBase/my-application$q');
  }

  static Uri captureUpgrade() => Uri.parse('$appBase/capture/upgrade');

  static Uri workRequestOnWeb(String workRequestId) =>
      Uri.parse('$appBase/plant/work-requests?id=$workRequestId');

  /// Minesite companion app — web landing until a dedicated App Store ID is set.
  static Uri minesiteMobileApp() => Uri.parse('$appBase/mobile');

  static Uri auth({String? redirect, String? email}) {
    final params = <String, String>{'brand': 'heevy_inspect'};
    if (redirect != null && redirect.isNotEmpty) params['redirect'] = redirect;
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      params['email'] = trimmedEmail;
    }
    return Uri.parse(appBase).replace(path: '/auth/minesite', queryParameters: params);
  }

  static Uri authForSetupPortal({String? email}) =>
      auth(redirect: '/my-application?source=heevy_inspect', email: email);

  static Uri authForApply({String? email}) =>
      auth(redirect: '/apply?source=heevy_inspect', email: email);

  static Uri terms() => Uri.parse('$appBase/terms');
  static Uri privacy() => Uri.parse('$appBase/privacy');

  static Uri? resolveDeepLink(Uri uri, {String? email}) {
    if (uri.scheme == 'heevy-inspect') {
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      if (host == 'apply' || path == '/apply') {
        return apply(source: 'heevy_inspect');
      }
      if (host == 'upgrade' || path == '/upgrade') {
        return captureUpgrade();
      }
      if (host == 'capture' && path.startsWith('/upgrade')) {
        return captureUpgrade();
      }
      return authForSetupPortal(email: email);
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final path = uri.path.toLowerCase();
      if (path.startsWith('/capture/upgrade')) return captureUpgrade();
      if (path.startsWith('/apply')) return apply(source: 'heevy_inspect');
      if (path.startsWith('/my-application')) {
        return authForSetupPortal(email: email);
      }
    }

    return null;
  }
}
