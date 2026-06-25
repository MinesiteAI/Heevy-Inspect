import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/heevy_urls.dart';

/// Handles `heevy-inspect://` and HTTPS app links for onboarding and upgrade.
class DeepLinkHandler {
  DeepLinkHandler._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;

  static Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _openResolved(initial);
      }
      await _subscription?.cancel();
      _subscription = _appLinks.uriLinkStream.listen((uri) {
        unawaited(_openResolved(uri));
      });
    } catch (e) {
      debugPrint('DeepLinkHandler init: $e');
    }
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static String? _currentUserEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (e) {
      debugPrint('DeepLinkHandler: no auth session ($e)');
      return null;
    }
  }

  static Future<void> openSetupPortal() async {
    await launchUrl(
      HeevyUrls.authForSetupPortal(email: _currentUserEmail()),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> openApplyOnWeb() async {
    await launchUrl(
      HeevyUrls.authForApply(email: _currentUserEmail()),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> openCaptureUpgrade() async {
    await launchUrl(
      HeevyUrls.captureUpgrade(),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> _openResolved(Uri uri) async {
    final target = HeevyUrls.resolveDeepLink(uri, email: _currentUserEmail());
    if (target == null) return;
    final ok = await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!ok) {
      debugPrint('DeepLinkHandler: could not open $target');
    }
  }
}
