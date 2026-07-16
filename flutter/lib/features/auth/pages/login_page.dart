import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Modern login page — premium split layout with dynamic illustrations.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.teacher;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go(_dashboardFor(ref.read(authProvider).user!.role));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'Login failed'),
          backgroundColor: OseeTheme.danger,
        ),
      );
    }
  }

  String _dashboardFor(UserRole r) => switch (r) {
    UserRole.teacher => '/teacher',
    UserRole.student => '/student',
    UserRole.partner => '/partner',
    UserRole.admin => '/admin',
  };

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
                child: Form(
                  key: _formKey,
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

                      // Welcome text
                      Text(
                        'Welcome back',
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
                        'Sign in to continue to your workspace.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: OseeTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role selector — mini cards
                      Text(
                        'I am a',
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
                      const SizedBox(height: 28),

                      // Email field
                      Text(
                        'Email',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: OseeTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            size: 20,
                            color: OseeTheme.textMuted,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: OseeTheme.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: OseeTheme.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: OseeTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Password field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Password',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: OseeTheme.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot password?',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: OseeTheme.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: OseeTheme.textMuted,
                          ),
                          suffixIcon: IconButton(
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: OseeTheme.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: OseeTheme.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: OseeTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        obscureText: _obscure,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: ref.watch(authProvider).isLoading
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: OseeTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: ref.watch(authProvider).isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Register link
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/register'),
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: OseeTheme.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Create one',
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
