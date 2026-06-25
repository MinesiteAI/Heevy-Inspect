import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/entitlement_service.dart';
import '../config/heevy_brand.dart';
import '../config/heevy_urls.dart';
import '../onboarding/acquisition_storage.dart';
import '../onboarding/onboarding_user_prefs.dart';
import '../theme/app_colors.dart';
import '../widgets/heevy_brand_title.dart';
import '../widgets/heevy_ui.dart';
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
  String? _info;

  EntitlementService get _entitlement =>
      EntitlementService(Supabase.instance.client);

  Color get _cardColor => AppColors.surface(context);
  Color get _mutedText => AppColors.muted;

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

  Future<void> _openUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) setState(() => _error = 'Could not open link');
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: '${HeevyUrls.appBase}/auth',
      );
      if (mounted) {
        setState(() => _info = 'Check your email for a password reset link.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send reset email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAccount() async {
    final email = _email.text.trim();
    final password = _password.text;
    final company = _company.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }
    if (company.isEmpty) {
      setState(() => _error = 'Enter your company name');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': _fullName.text.trim()},
      );
      if (res.session == null) {
        if (mounted) {
          setState(() {
            _info =
                'Account created. Sign in with your email and password to continue.';
            _mode = _LoginMode.signIn;
          });
        }
        return;
      }
      final acq = await AcquisitionStorage.payloadForRegister();
      await _entitlement.registerApplicant(
        fullName: _fullName.text.trim().isNotEmpty
            ? _fullName.text.trim()
            : email.split('@').first,
        companyName: company,
        acquisitionExtra: acq,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message.contains('already registered')
            ? 'An account with this email already exists. Sign in instead.'
            : e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinCompany() async {
    final email = _email.text.trim();
    final password = _password.text;
    final token = _invite.text.trim();
    if (email.isEmpty || password.isEmpty || token.isEmpty) {
      setState(() => _error = 'Enter email, password, and your invite code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (_) {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      final result = await _entitlement.acceptInvite(token);
      if (mounted) {
        setState(() {
          _info = result['workspace_name'] != null
              ? 'Joined ${result['workspace_name']}. Welcome!'
              : 'Invitation accepted. Welcome!';
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apple() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final response = await signInWithApple();
      if (!mounted) return;
      if (_mode == _LoginMode.createAccount) {
        final company = _company.text.trim();
        if (company.isEmpty) {
          setState(() => _error = 'Enter your company name');
          return;
        }
        final given = response.user?.userMetadata?['full_name'] as String?;
        final acq = await AcquisitionStorage.payloadForRegister();
        await _entitlement.registerApplicant(
          fullName: given ?? _fullName.text.trim(),
          companyName: company,
          acquisitionExtra: acq,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        setState(() => _error = 'Apple Sign In was cancelled or failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    switch (_mode) {
      case _LoginMode.signIn:
        _signIn();
      case _LoginMode.createAccount:
        _createAccount();
      case _LoginMode.joinCompany:
        _joinCompany();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    _buildHero(),
                    const SizedBox(height: 24),
                    _buildModeChips(),
                    _buildModeHint(),
                    const SizedBox(height: 16),
                    _buildCard(),
                    const SizedBox(height: 12),
                    _buildSecondaryActions(),
                    const SizedBox(height: 20),
                    _buildFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        Image.asset(
          AppColors.isDark(context) ? 'assets/dark.png' : 'assets/light.png',
          width: 88,
          height: 88,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        const HeevyBrandTitle(),
        const SizedBox(height: 6),
        Text(
          HeevyBrand.loginSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedText, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(
          HeevyBrand.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textFaint(context), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildModeChips() {
    return Row(
      children: [
        HeevyModeChip(
          label: 'Sign in',
          selected: _mode == _LoginMode.signIn,
          enabled: !_loading,
          onTap: () => setState(() {
            _mode = _LoginMode.signIn;
            _error = null;
            _info = null;
          }),
        ),
        const SizedBox(width: 6),
        HeevyModeChip(
          label: 'Join company',
          selected: _mode == _LoginMode.joinCompany,
          enabled: !_loading,
          onTap: () => setState(() {
            _mode = _LoginMode.joinCompany;
            _error = null;
            _info = null;
          }),
        ),
        const SizedBox(width: 6),
        HeevyModeChip(
          label: 'Create account',
          selected: _mode == _LoginMode.createAccount,
          enabled: !_loading,
          onTap: () => setState(() {
            _mode = _LoginMode.createAccount;
            _error = null;
            _info = null;
          }),
        ),
      ],
    );
  }

  Widget _buildModeHint() {
    final String hint;
    switch (_mode) {
      case _LoginMode.createAccount:
        hint = HeevyBrand.createAccountHint;
      case _LoginMode.joinCompany:
        hint = HeevyBrand.joinCompanyHint;
      case _LoginMode.signIn:
        hint = HeevyBrand.signInHint;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: TextStyle(color: _mutedText, fontSize: 12, height: 1.35),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          if (_mode == _LoginMode.createAccount) ...[
            HeevyField(
              controller: _fullName,
              hint: 'Full name (optional)',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 8),
            HeevyField(
              controller: _company,
              hint: 'Company name',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 8),
          ],
          if (_mode == _LoginMode.joinCompany) ...[
            HeevyField(
              controller: _invite,
              hint: 'Invite code from your admin',
              icon: Icons.vpn_key_outlined,
              autocorrect: false,
            ),
            const SizedBox(height: 8),
          ],
          HeevyField(
            controller: _email,
            hint: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          HeevyField(
            controller: _password,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            trailing: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textFaint(context),
                size: 20,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF453A),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _info!,
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          HeevyPrimaryButton(
            label: _primaryLabel(),
            loading: _loading,
            onTap: _submit,
          ),
          if (_mode == _LoginMode.signIn) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : _forgotPassword,
              child: Text(
                'Forgot password?',
                style: TextStyle(color: AppColors.textMuted(context)),
              ),
            ),
          ],
          if (_appleSupported &&
              (_mode == _LoginMode.signIn ||
                  _mode == _LoginMode.createAccount)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.border(context))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: _mutedText, fontSize: 13)),
                ),
                Expanded(child: Divider(color: AppColors.border(context))),
              ],
            ),
            const SizedBox(height: 12),
            SignInWithAppleButton(
              onPressed: _loading ? () {} : _apple,
              style: SignInWithAppleButtonStyle.black,
              height: 48,
              borderRadius: BorderRadius.circular(heevyRadius),
              text: _mode == _LoginMode.createAccount
                  ? 'Sign up with Apple'
                  : 'Sign in with Apple',
            ),
          ],
        ],
      ),
    );
  }

  bool get _appleSupported => Platform.isIOS || Platform.isMacOS;

  String _primaryLabel() {
    switch (_mode) {
      case _LoginMode.signIn:
        return 'Sign in';
      case _LoginMode.createAccount:
        return 'Create account';
      case _LoginMode.joinCompany:
        return 'Join workspace';
    }
  }

  Widget _buildSecondaryActions() {
    if (_mode == _LoginMode.joinCompany) {
      return TextButton(
        onPressed: _loading
            ? null
            : () => setState(() {
                  _mode = _LoginMode.signIn;
                  _error = null;
                  _info = null;
                }),
        child: Text(
          'Already have an account? Sign in',
          style: TextStyle(color: AppColors.textMuted(context)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFooter() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(color: _mutedText, fontSize: 12, height: 1.4),
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(
            text: 'Terms',
            style: TextStyle(
              color: AppColors.text(context),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUri(HeevyUrls.terms()),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: AppColors.text(context),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUri(HeevyUrls.privacy()),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
