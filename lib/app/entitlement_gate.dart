import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';
import '../billing/entitlement_refresh.dart';
import '../billing/entitlement_service.dart';
import '../features/home/inspect_home_screen.dart';
import '../onboarding/setup_home_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/heevy_brand_title.dart';
import '../widgets/heevy_ui.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (Supabase.instance.client.auth.currentSession != null) {
          return const EntitlementGate();
        }
        return const LoginScreen();
      },
    );
  }
}

class EntitlementGate extends StatefulWidget {
  const EntitlementGate({super.key});

  @override
  State<EntitlementGate> createState() => _EntitlementGateState();
}

class _EntitlementGateState extends State<EntitlementGate> {
  EntitlementResult? _entitlement;
  bool _loading = true;
  bool _skippedSetup = false;
  bool _connectionError = false;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  bool _isAuthFailure(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('unauthorized') ||
        msg.contains('invalid jwt') ||
        msg.contains('jwt expired') ||
        msg.contains('user not found');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _connectionError = false;
      _errorDetail = null;
    });
    try {
      final result =
          await EntitlementService(Supabase.instance.client).check();
      if (!mounted) return;
      setState(() {
        _entitlement = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_isAuthFailure(e)) {
        await _signOut();
        return;
      }
      setState(() {
        _connectionError = true;
        _loading = false;
        _errorDetail = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppColors.isDark(context)
                    ? 'assets/dark.png'
                    : 'assets/light.png',
                width: 56,
                height: 56,
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                color: AppColors.textMuted(context),
                strokeWidth: 2.2,
              ),
            ],
          ),
        ),
      );
    }

    if (_connectionError) {
      return _AccessBlockedScaffold(
        title: 'Could not verify access',
        message:
            'Check your connection and try again. If you deleted your account or signed in elsewhere, go back to sign in.',
        detail: _errorDetail,
        primaryLabel: 'Retry',
        onPrimary: _load,
        secondaryLabel: 'Back to sign in',
        onSecondary: _signOut,
      );
    }

    final ent = _entitlement ?? EntitlementResult.denied;

    if (!ent.access) {
      return _AccessBlockedScaffold(
        title: 'Account setup required',
        message:
            'Complete your company application on the web or ask your manager for an invite.',
        primaryLabel: 'Back to sign in',
        onPrimary: _signOut,
      );
    }

    if (ent.setupRequired && !_skippedSetup) {
      return EntitlementRefresh(
        refresh: _load,
        child: SetupHomeScreen(
          entitlement: ent,
          onContinueToApp: () => setState(() => _skippedSetup = true),
          onRefresh: _load,
        ),
      );
    }

    return EntitlementRefresh(
      refresh: _load,
      child: InspectHomeScreen(entitlement: ent),
    );
  }
}

class _AccessBlockedScaffold extends StatelessWidget {
  const _AccessBlockedScaffold({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.detail,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String? detail;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                AppColors.isDark(context)
                    ? 'assets/dark.png'
                    : 'assets/light.png',
                width: 72,
                height: 72,
              ),
              const SizedBox(height: 20),
              const HeevyBrandTitle(),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textFaint(context),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              HeevyPrimaryButton(label: primaryLabel, onTap: onPrimary),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 12),
                HeevySecondaryButton(
                  label: secondaryLabel!,
                  onTap: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
