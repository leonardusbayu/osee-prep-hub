import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';

/// Magazine-style login page — matching the register page split layout.
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
    final ok = await ref.read(authProvider.notifier).login(
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
                        child: const Text('WELCOME BACK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC9A96E), letterSpacing: 3)),
                      ),
                      const SizedBox(height: 20),
                      Text('Continue\nteaching\nsmarter.', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 52, height: 1.1)),
                    ],
                  ),
                  Text('Your students are waiting.', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
          ),
          // Right — form
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
                    Text('Sign In', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text('Welcome back to OSEE Prep Hub.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9B9B9B))),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'EMAIL ADDRESS'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'PASSWORD',
                        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9B9B9B)), onPressed: () => setState(() => _obscure = !_obscure)),
                      ),
                      obscureText: _obscure,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: ref.watch(authProvider).isLoading ? null : _submit,
                        child: ref.watch(authProvider).isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('SIGN IN'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text("Don't have an account? Create one"),
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