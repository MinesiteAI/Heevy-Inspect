import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/entitlement_service.dart';
import '../config/heevy_brand.dart';
import '../config/heevy_urls.dart';
import '../onboarding/acquisition_storage.dart';
import '../onboarding/onboarding_user_prefs.dart';
import '../theme/app_colors.dart';
import '../widgets/heevy_brand_title.dart';
import 'apple_sign_in.dart';

enum _LoginMode { signIn, joinCompany, createAccount }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginMode _mode = _LoginMode.createAccount;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _invite = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  EntitlementService get _entitlement =>
      EntitlementService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    OnboardingUserPrefs.hasSeenLoginScreenBefore().then((seen) {
      if (mounted && seen) setState(() => _mode = _LoginMode.signIn);
    });
    OnboardingUserPrefs.markLoginScreenSeen();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _company.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAccount() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _fullName.text.trim()},
      );
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() => _error = 'Check your email to confirm, then sign in.');
        return;
      }
      final acq = await AcquisitionStorage.payloadForRegister();
      await _entitlement.registerApplicant(
        fullName: _fullName.text.trim(),
        companyName: _company.text.trim(),
        acquisitionExtra: acq,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinCompany() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _entitlement.acceptInvite(_invite.text.trim());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apple() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await signInWithApple();
      if (_mode == _LoginMode.createAccount) {
        final acq = await AcquisitionStorage.payloadForRegister();
        await _entitlement.registerApplicant(
          fullName: _fullName.text.trim().isNotEmpty
              ? _fullName.text.trim()
              : 'Field user',
          companyName: _company.text.trim().isNotEmpty
              ? _company.text.trim()
              : 'My site',
          acquisitionExtra: acq,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Image.asset(
              AppColors.isDark(context) ? 'assets/dark.png' : 'assets/light.png',
              width: 72,
              height: 72,
            ),
            const SizedBox(height: 16),
            const HeevyBrandTitle(),
            const SizedBox(height: 8),
            Text(
              HeevyBrand.loginSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            SegmentedButton<_LoginMode>(
              segments: const [
                ButtonSegment(value: _LoginMode.createAccount, label: Text('Sign up')),
                ButtonSegment(value: _LoginMode.signIn, label: Text('Sign in')),
                ButtonSegment(value: _LoginMode.joinCompany, label: Text('Join')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 20),
            if (_mode == _LoginMode.createAccount) ...[
              _field(_fullName, 'Full name'),
              const SizedBox(height: 12),
              _field(_company, 'Company / site name'),
              const SizedBox(height: 12),
            ],
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_password, 'Password', obscure: _obscure, suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            )),
            if (_mode == _LoginMode.joinCompany) ...[
              const SizedBox(height: 12),
              _field(_invite, 'Invite code'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : () {
                switch (_mode) {
                  case _LoginMode.signIn:
                    _signIn();
                  case _LoginMode.createAccount:
                    _createAccount();
                  case _LoginMode.joinCompany:
                    _joinCompany();
                }
              },
              child: Text(_loading ? 'Please wait…' : 'Continue'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _apple,
              icon: const Icon(Icons.apple),
              label: const Text('Continue with Apple'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => launchUrl(HeevyUrls.terms()),
              child: const Text('Terms & Privacy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceAlt(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: suffix,
      ),
    );
  }
}
