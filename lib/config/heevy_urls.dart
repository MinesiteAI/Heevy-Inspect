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

  static Uri terms() => Uri.parse('$appBase/terms');
  static Uri privacy() => Uri.parse('$appBase/privacy');

  static Uri? resolveDeepLink(Uri uri) {
    if (uri.scheme == 'heevy-inspect') {
      return authForSetupPortal();
    }
    return null;
  }
}
