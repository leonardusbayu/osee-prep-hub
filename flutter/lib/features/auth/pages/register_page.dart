import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';

/// Magazine-style registration page — editorial split layout.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.referralCode});

  final String? referralCode;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  final _institutionController = TextEditingController();
  UserRole _role = UserRole.student;
  bool _obscure = true;

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
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: _role.name,
          referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
          institutionName: _role == UserRole.partner ? _institutionController.text.trim() : null,
        );
    if (!mounted) return;
    if (ok) {
      context.go(_dashboardFor(ref.read(authProvider).user!.role));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'Registration failed'),
          backgroundColor: const Color(0xFFE63946),
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
      backgroundColor: const Color(0xFFF7F5F0),
      body: Row(
        children: [
          // Left panel — editorial cover
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.all(64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 60),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A96E))),
                        child: const Text('JOIN US', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC9A96E), letterSpacing: 3)),
                      ),
                      const SizedBox(height: 20),
                      Text('Become a\nsmarter\nteacher.', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 52, height: 1.1)),
                      const SizedBox(height: 20),
                      SizedBox(width: 400, child: Text('Free AI tools, commission on student actions, and a community of English teachers across Indonesia.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.6), fontSize: 16))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Color(0xFF2A2A4E)),
                      const SizedBox(height: 16),
                      Text('50 AI grading credits / month', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: Colors.white.withOpacity(0.5))),
                      Text('10 material generations / month', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: Colors.white.withOpacity(0.5))),
                      Text('Commission on every student action', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Right panel — form
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(64),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Create Account', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text('No credit card needed. Free forever for teachers.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9B9B9B))),
                    const SizedBox(height: 32),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'FULL NAME'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'EMAIL ADDRESS'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v)) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'PASSWORD',
                        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9B9B9B)), onPressed: () => setState(() => _obscure = !_obscure)),
                        helperText: 'Min 8 chars, 1 letter, 1 number',
                      ),
                      obscureText: _obscure,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) return 'Min 8 characters';
                        if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Must contain a letter';
                        if (!RegExp(r'\d').hasMatch(v)) return 'Must contain a number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Role selector — magazine-style segmented
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
                    if (_role == UserRole.partner) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _institutionController,
                        decoration: const InputDecoration(labelText: 'INSTITUTION NAME'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required for institutions' : null,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Referral code
                    TextFormField(
                      controller: _referralController,
                      decoration: const InputDecoration(labelText: 'REFERRAL CODE (OPTIONAL)', helperText: 'If invited by a teacher'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 32),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: ref.watch(authProvider).isLoading ? null : _submit,
                        child: ref.watch(authProvider).isLoading
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