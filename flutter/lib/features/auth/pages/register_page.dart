import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Registration page — simplified, with visible errors and no blocking validation.
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
  UserRole _role = UserRole.teacher;
  bool _obscure = true;
  bool _isLoading = false;
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
    super.dispose();
  }

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
            institutionName: _role == UserRole.partner ? name : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SurfaceCard(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PageHeader(
                    title: 'Create account',
                    subtitle: widget.referralCode == null
                        ? 'Start with a teacher, student, or institution workspace.'
                        : 'You are joining with referral code ${widget.referralCode}.',
                    icon: Icons.person_add_alt_1_rounded,
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  // Password
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: OseeTheme.textMuted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      helperText: 'Min 8 chars, 1 letter, 1 number',
                    ),
                    obscureText: _obscure,
                  ),
                  const SizedBox(height: 20),

                  // Role selector
                  Text(
                    'Account type',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: [
                      _RoleChip(
                        icon: Icons.school_outlined,
                        label: 'Student',
                        selected: _role == UserRole.student,
                        onTap: () => setState(() => _role = UserRole.student),
                      ),
                      _RoleChip(
                        icon: Icons.co_present_outlined,
                        label: 'Teacher',
                        selected: _role == UserRole.teacher,
                        onTap: () => setState(() => _role = UserRole.teacher),
                      ),
                      _RoleChip(
                        icon: Icons.business_outlined,
                        label: 'Institution',
                        selected: _role == UserRole.partner,
                        onTap: () => setState(() => _role = UserRole.partner),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Referral code
                  TextField(
                    controller: _referralController,
                    decoration: const InputDecoration(
                      labelText: 'Referral code (optional)',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ERROR MESSAGE — always visible if set
                  if (_errorMsg != null) ...[
                    SurfaceCard(
                      padding: const EdgeInsets.all(12),
                      color: OseeTheme.danger.withValues(alpha: 0.08),
                      borderColor: OseeTheme.danger.withValues(alpha: 0.25),
                      child: Text(
                        _errorMsg!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OseeTheme.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('CREATE ACCOUNT'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? OseeTheme.primary : OseeTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? OseeTheme.primary : OseeTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : OseeTheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : OseeTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
