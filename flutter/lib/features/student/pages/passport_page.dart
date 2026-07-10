import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// Student Passport page — T11 (Wave 2).
///
/// Magazine-styled certificates. Lists credentials issued to the student.
/// (QR code for physical sharing + employer verification portal come in T25.)
class PassportPage extends ConsumerStatefulWidget {
  const PassportPage({super.key});

  @override
  ConsumerState<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends ConsumerState<PassportPage> {
  // TODO: fetch from API. Mock data for skeleton.
  final List<_Credential> _credentials = [
    _Credential(
      id: 'cred-1',
      type: 'IELTS Overall Band 7.0',
      issuer: 'OSEE Coach',
      issuedAt: '2026-01-15',
      evidenceCount: 2,
      signature: 'a3f8c92...b41e2d',
    ),
    _Credential(
      id: 'cred-2',
      type: 'Course Completion: B2 English Mastery',
      issuer: 'OSEE Materials',
      issuedAt: '2025-12-10',
      evidenceCount: 1,
      signature: '7e2b81a...9f4c3d',
    ),
    _Credential(
      id: 'cred-3',
      type: 'Badge: 100-Day Streak',
      issuer: 'OSEE Coach',
      issuedAt: '2025-11-01',
      evidenceCount: 0,
      signature: 'c81a2f3...d47e9b',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        backgroundColor: MagazineColors.paperCream,
        elevation: 0,
      ),
      backgroundColor: MagazineColors.paperCream,
      body: ListView(
        padding: const EdgeInsets.all(MagazineSpacing.base),
        children: [
          const MagazineMasthead(
            kicker: 'OSEE PASSPORT',
            title: 'Your verified achievements',
            subtitle: 'Cryptographically-signed credentials that employers and universities can verify.',
            date: 'Updated continuously as you progress',
          ),
          const SizedBox(height: MagazineSpacing.lg),
          const MagazineSectionRule(label: 'Credentials'),
          const SizedBox(height: MagazineSpacing.base),
          for (final c in _credentials) ...[
            _PassportCard(credential: c),
            const SizedBox(height: MagazineSpacing.base),
          ],
          const SizedBox(height: MagazineSpacing.lg),
          const MagazineSectionRule(label: 'How to share'),
          const SizedBox(height: MagazineSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MagazineSpacing.base),
            child: Text(
              'Tap any credential to view its QR code, copy the verification link, '
              'or share directly with employers. Every credential is signed with an '
              'Ed25519 key and can be verified at /verify/:credentialId.',
              style: magazineBody(),
            ),
          ),
          const SizedBox(height: MagazineSpacing.lg),
          const MagazineSectionRule(label: 'For employers'),
          const SizedBox(height: MagazineSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MagazineSpacing.base),
            child: Text(
              'Verify any credential at /verify/:credentialId (no login required). '
              'Our public key is available at /.well-known/passport-public-key.pem.',
              style: magazineBody(),
            ),
          ),
          const SizedBox(height: MagazineSpacing.xxl),
        ],
      ),
    );
  }
}

class _Credential {
  _Credential({
    required this.id,
    required this.type,
    required this.issuer,
    required this.issuedAt,
    required this.evidenceCount,
    required this.signature,
  });
  final String id;
  final String type;
  final String issuer;
  final String issuedAt;
  final int evidenceCount;
  final String signature;
}

class _PassportCard extends StatelessWidget {
  const _PassportCard({required this.credential});
  final _Credential credential;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MagazineSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MagazineColors.mastheadGold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold seal in the corner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(credential.type, style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w700,
                      color: MagazineColors.inkBlack,
                    )),
                    const SizedBox(height: MagazineSpacing.xs),
                    Text('Issued by ${credential.issuer}', style: magazineCaption()),
                    Text('Issued ${credential.issuedAt}', style: magazineCaption()),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MagazineColors.mastheadGold, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.verified, color: MagazineColors.mastheadGold, size: 28),
              ),
            ],
          ),
          const SizedBox(height: MagazineSpacing.base),
          const Divider(color: MagazineColors.mastheadGold, height: 1.5),
          const SizedBox(height: MagazineSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${credential.evidenceCount} evidence item${credential.evidenceCount == 1 ? '' : 's'} attached',
                  style: magazineCaption()),
              Text('Sig: ${credential.signature}', style: magazineCaption()),
            ],
          ),
          const SizedBox(height: MagazineSpacing.sm),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              TextButton.icon(
                icon: const Icon(Icons.qr_code, size: 16, color: MagazineColors.mastheadGold),
                label: const Text('Share / Verify', style: TextStyle(color: MagazineColors.mastheadGold, fontFamily: 'Georgia', fontWeight: FontWeight.w600)),
                onPressed: () {
                  // TODO(T11): show QR + share sheet.
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}