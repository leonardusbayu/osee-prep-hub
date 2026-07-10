import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// Employer verification portal — T11 (Wave 2).
///
/// Public route /verify/:credentialId. Shows whether a credential is valid.
class VerifyCredentialPage extends ConsumerStatefulWidget {
  const VerifyCredentialPage({super.key, required this.credentialId});
  final String credentialId;

  @override
  ConsumerState<VerifyCredentialPage> createState() => _VerifyCredentialPageState();
}

class _VerifyCredentialPageState extends ConsumerState<VerifyCredentialPage> {
  bool _loading = true;
  bool? _valid;
  String? _reason;
  String? _credentialType;
  String? _subjectName;
  DateTime? _issuedAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    // TODO: call GET /api/passport/:id
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _loading = false;
      // Mock: assume valid if id starts with 'cred-', invalid otherwise.
      if (widget.credentialId.startsWith('cred-')) {
        _valid = true;
        _credentialType = 'IELTS Overall Band 7.0';
        _subjectName = 'Andi Wijaya';
        _issuedAt = DateTime.parse('2026-01-15');
      } else {
        _valid = false;
        _reason = 'not_found';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Credential', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        backgroundColor: MagazineColors.paperCream,
        elevation: 0,
      ),
      backgroundColor: MagazineColors.paperCream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MagazineColors.mastheadGold))
          : _valid == null
              ? Center(child: Text('Error: ${_errorMessage ?? "unknown"}', style: magazineBody()))
              : _valid!
                  ? _ValidCredentialView(
                      credentialId: widget.credentialId,
                      type: _credentialType ?? 'Credential',
                      subject: _subjectName ?? 'Unknown',
                      issuedAt: _issuedAt ?? DateTime.now(),
                    )
                  : _InvalidCredentialView(reason: _reason ?? 'unknown'),
    );
  }
}

class _ValidCredentialView extends StatelessWidget {
  const _ValidCredentialView({
    required this.credentialId,
    required this.type,
    required this.subject,
    required this.issuedAt,
  });

  final String credentialId;
  final String type;
  final String subject;
  final DateTime issuedAt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(MagazineSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(MagazineSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MagazineColors.successGreen, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: MagazineColors.successGreen, size: 64),
                const SizedBox(height: MagazineSpacing.base),
                const Text('VALID CREDENTIAL', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  color: MagazineColors.successGreen,
                )),
                const SizedBox(height: MagazineSpacing.base),
                Text(type, textAlign: TextAlign.center, style: const TextStyle(
                  fontSize: 24, fontFamily: 'Georgia', fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: MagazineSpacing.md),
                Text('Issued to: $subject', style: magazineBody()),
                Text('Issued on: ${issuedAt.toIso8601String().split('T')[0]}', style: magazineBody()),
                const SizedBox(height: MagazineSpacing.base),
                const Divider(),
                const SizedBox(height: MagazineSpacing.sm),
                SelectableText('Credential ID: $credentialId', style: magazineCaption()),
                const SizedBox(height: MagazineSpacing.base),
                Container(
                  padding: const EdgeInsets.all(MagazineSpacing.sm),
                  color: MagazineColors.surfaceMuted,
                  child: Text(
                    'This credential is signed with an Ed25519 key. '
                    'See /.well-known/passport-public-key.pem for verification.',
                    style: magazineCaption(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidCredentialView extends StatelessWidget {
  const _InvalidCredentialView({required this.reason});
  final String reason;

  String _reasonText() {
    switch (reason) {
      case 'not_found': return 'No credential exists with this ID.';
      case 'revoked': return 'This credential has been revoked.';
      case 'signature_mismatch': return 'The credential signature does not match. It may have been tampered with.';
      case 'verification_key_unavailable': return 'Cannot verify — Passport signing key not configured on this server.';
      default: return 'Reason: $reason';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(MagazineSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(MagazineSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MagazineColors.errorRed, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cancel, color: MagazineColors.errorRed, size: 64),
                const SizedBox(height: MagazineSpacing.base),
                const Text('INVALID CREDENTIAL', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  color: MagazineColors.errorRed,
                )),
                const SizedBox(height: MagazineSpacing.base),
                Text(_reasonText(), textAlign: TextAlign.center, style: magazineBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}