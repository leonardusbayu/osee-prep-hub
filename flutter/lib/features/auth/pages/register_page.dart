import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/auth_widgets.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Registration page — premium design with role‑specific fields & illustrations.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.referralCode});

  final String? referralCode;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  final _institutionNameController = TextEditingController();
  UserRole _role = UserRole.teacher;
  bool _obscure = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.referralCode != null) {
      _referralController.text = widget.referralCode!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _referralController.dispose();
    _institutionNameController.dispose();
    super.dispose();
  }

  // Password strength (0-4)
  int get _passwordStrength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[a-zA-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p)) score++;
    return score;
  }

  String get _strengthLabel => switch (_passwordStrength) {
    0 => '',
    1 => 'Weak',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Strong',
    _ => '',
  };

  Color get _strengthColor => switch (_passwordStrength) {
    1 => OseeTheme.danger,
    2 => OseeTheme.warning,
    3 => const Color(0xFF6B8E7F),
    4 => const Color(0xFF2E8B57),
    _ => OseeTheme.border,
  };

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final ok = await ref
          .read(authProvider.notifier)
          .register(
            email: email,
            password: password,
            name: name,
            role: _role.name,
            referralCode: _referralController.text.trim().isEmpty
                ? null
                : _referralController.text.trim(),
            institutionName: _role == UserRole.partner
                ? _institutionNameController.text.trim()
                : null,
          );

      if (!mounted) return;

      if (ok) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          final dest = switch (user.role) {
            UserRole.teacher => '/teacher',
            UserRole.student => '/student',
            UserRole.partner => '/partner',
            UserRole.admin => '/admin',
          };
          context.go(dest);
        } else {
          setState(() {
            _errorMsg = 'Registration succeeded but no user returned';
            _isLoading = false;
          });
        }
      } else {
        final err = ref.read(authProvider).error ?? 'Unknown error';
        setState(() {
          _errorMsg = err;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _isLoading = false;
      });
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? helperText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      prefixIcon: Icon(icon, size: 20, color: OseeTheme.textMuted),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OseeTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OseeTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OseeTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OseeTheme.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          final form = Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? Spacing.xxl : Spacing.lg,
                vertical: Spacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo & brand
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                OseeTheme.primary,
                                OseeTheme.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          'OSEE Prep Hub',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OseeTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Heading
                    Text(
                      'Create account',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: OseeTheme.textPrimary,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.referralCode == null
                          ? 'Start with a teacher, student, or institution workspace.'
                          : 'Joining with referral code: ${widget.referralCode}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: OseeTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role selector — mini cards
                    Text(
                      'I want to join as',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OseeTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AuthRoleChip(
                            icon: Icons.school_outlined,
                            label: 'Student',
                            description: 'Learn & practice',
                            selected: _role == UserRole.student,
                            onTap: () =>
                                setState(() => _role = UserRole.student),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: AuthRoleChip(
                            icon: Icons.co_present_outlined,
                            label: 'Teacher',
                            description: 'Manage classes',
                            selected: _role == UserRole.teacher,
                            onTap: () =>
                                setState(() => _role = UserRole.teacher),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: AuthRoleChip(
                            icon: Icons.business_outlined,
                            label: 'Institution',
                            description: 'Admin & analytics',
                            selected: _role == UserRole.partner,
                            onTap: () =>
                                setState(() => _role = UserRole.partner),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Full name
                    Text(
                      'Full name',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OseeTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration(
                        hint: 'Enter your full name',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Institution name (only for partner role)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: _role == UserRole.partner
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Institution name',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: OseeTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _institutionNameController,
                                  decoration: _inputDecoration(
                                    hint: 'e.g. OSEE Language Center',
                                    icon: Icons.apartment_outlined,
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Email
                    Text(
                      'Email address',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OseeTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      decoration: _inputDecoration(
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),

                    // Password
                    Text(
                      'Password',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OseeTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      decoration: _inputDecoration(
                        hint: 'Min 8 chars, 1 letter, 1 number',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: OseeTheme.textMuted,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      onChanged: (_) => setState(() {}),
                    ),

                    // Password strength indicator
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ...List.generate(4, (i) {
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 3,
                                margin: EdgeInsets.only(
                                  right: i < 3 ? 4 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: i < _passwordStrength
                                      ? _strengthColor
                                      : OseeTheme.border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 10),
                          Text(
                            _strengthLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _strengthColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Referral code
                    Text(
                      'Referral code (optional)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OseeTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _referralController,
                      decoration: _inputDecoration(
                        hint: 'Enter code if you have one',
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Terms agreement
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (v) =>
                                setState(() => _agreedToTerms = v ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor: OseeTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _agreedToTerms = !_agreedToTerms,
                            ),
                            child: Text(
                              'I agree to the Terms of Service and Privacy Policy',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: OseeTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Error message
                    if (_errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OseeTheme.danger.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: OseeTheme.danger.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: OseeTheme.danger,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: OseeTheme.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Submit button
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: OseeTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Create Account',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login link
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: OseeTheme.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign in',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: OseeTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final brandPanel = AuthBrandPanel(role: _role);

          if (!wide) {
            return form;
          }

          return Row(
            children: [
              Expanded(flex: 5, child: brandPanel),
              Expanded(flex: 6, child: form),
            ],
          );
        },
      ),
    );
  }
}
