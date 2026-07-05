import 'package:flutter/material.dart';

/// Register page — placeholder for Task 1.6.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key, this.referralCode});

  final String? referralCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: Text('Register page — Task 1.6 (referral: $referralCode)'),
      ),
    );
  }
}