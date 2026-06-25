import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';
import '../billing/entitlement_refresh.dart';
import '../billing/entitlement_service.dart';
import '../features/home/inspect_home_screen.dart';
import '../onboarding/setup_home_screen.dart';
import '../theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _connectionError = false;
    });
    try {
      final result =
          await EntitlementService(Supabase.instance.client).check();
      if (!mounted) return;
      setState(() {
        _entitlement = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectionError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_connectionError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not verify access'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final ent = _entitlement ?? EntitlementResult.denied;

    if (!ent.access) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Account setup required',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Complete your company application on the web or ask your manager for an invite.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
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
