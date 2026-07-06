import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';

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
      final ok = await ref.read(authProvider.notifier).register(
            email: email,
            password: password,
            name: name,
            role: _role.name,
            referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
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
      backgroundColor: const Color(0xFFF7F5F0),
      body: Row(
        children: [
          // Left — editorial panel
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.all(64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('OSEE', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 24, letterSpacing: 4)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: const Color(0xFFE63946),
                        child: const Text('PREP HUB', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A96E))),
                        child: const Text('JOIN US', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC9A96E), letterSpacing: 3)),
                      ),
                      const SizedBox(height: 20),
                      Text('Become a\nsmarter\nteacher.', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 52, height: 1.1)),
                    ],
                  ),
                  Text('Your students are waiting.', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
          ),
          // Right — form (NO Form widget, NO validators — just direct submission)
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Create Account', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text('No credit card needed.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9B9B9B))),
                  const SizedBox(height: 32),

                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'FULL NAME'),
                  ),
                  const SizedBox(height: 20),

                  // Email
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'EMAIL ADDRESS'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  // Password
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'PASSWORD',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9B9B9B)),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      helperText: 'Min 8 chars, 1 letter, 1 number',
                    ),
                    obscureText: _obscure,
                  ),
                  const SizedBox(height: 20),

                  // Role selector
                  Text('I AM A...', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _RoleChip(label: 'Student', selected: _role == UserRole.student, onTap: () => setState(() => _role = UserRole.student)),
                      const SizedBox(width: 8),
                      _RoleChip(label: 'Teacher', selected: _role == UserRole.teacher, onTap: () => setState(() => _role = UserRole.teacher)),
                      const SizedBox(width: 8),
                      _RoleChip(label: 'Institution', selected: _role == UserRole.partner, onTap: () => setState(() => _role = UserRole.partner)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Referral code
                  TextField(
                    controller: _referralController,
                    decoration: const InputDecoration(labelText: 'REFERRAL CODE (OPTIONAL)'),
                  ),
                  const SizedBox(height: 24),

                  // ERROR MESSAGE — always visible if set
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFFFEE),
                      child: Text(_errorMsg!, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 13, color: Color(0xFFE63946))),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E) : Colors.transparent,
          border: Border.all(color: selected ? const Color(0xFF1A1A2E) : const Color(0xFFE8E6E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF1A1A2E),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}