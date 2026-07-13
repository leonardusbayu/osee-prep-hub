import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Modern login page — split layout with gradient panel + clean form.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
              padding: EdgeInsets.all(wide ? Spacing.xxl : Spacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: OseeTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: OseeTheme.primary,
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'OSEE Prep Hub',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xl),
                        Text(
                          'Sign in',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: OseeTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back to OSEE Prep Hub.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: OseeTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Email
                        Text(
                          'Email',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: OseeTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),

                        // Password
                        Text(
                          'Password',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: OseeTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 20,
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
                          ),
                          obscureText: _obscure,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 28),

                        // Submit
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: ref.watch(authProvider).isLoading
                                ? null
                                : _submit,
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
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/register'),
                            child: Text(
                              "Don't have an account? Create one",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          final brandPanel = Container(
            margin: const EdgeInsets.all(Spacing.lg),
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: OseeTheme.textPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OSEE',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teaching operations, unified.',
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'AI grading, classrooms, syllabus planning, orders, and student readiness in one professional workspace.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
                Text(
                  'Official ETS Test Center since 2014',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          );

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
