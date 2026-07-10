import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// Live class landing page — T12 (Wave 2) skeleton.
///
/// Shows upcoming live classes + join button. Real impl uses
/// livekit_client package + the JWT returned from /api/live-classes/:id/join.
class LiveClassPage extends ConsumerWidget {
  const LiveClassPage({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Class', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        backgroundColor: MagazineColors.paperCream,
        elevation: 0,
      ),
      backgroundColor: MagazineColors.paperCream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(MagazineSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(MagazineSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: MagazineColors.mastheadGold, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MagazineColors.mastheadGold.withValues(alpha: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.videocam, size: 40, color: MagazineColors.mastheadGold),
                  ),
                  const SizedBox(height: MagazineSpacing.lg),
                  Text('IELTS Writing Live Q&A', textAlign: TextAlign.center, style: magazineDisplay()),
                  const SizedBox(height: MagazineSpacing.sm),
                  Text('Scheduled · 60 min · 24 attendees', style: magazineCaption()),
                  const SizedBox(height: MagazineSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(MagazineSpacing.base),
                    decoration: BoxDecoration(color: MagazineColors.surfaceMuted),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CLASSROOM LIVE', style: magazineOverline()),
                        const SizedBox(height: MagazineSpacing.xs),
                        const Text(
                          'WebRTC video via LiveKit + Yjs-synced whiteboard + real-time polls + AI summary post-class.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MagazineSpacing.lg),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: MagazineColors.mastheadGold, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    onPressed: () {
                      // TODO(T12): join via livekit_client using JWT from /api/live-classes/:id/join.
                    },
                    child: const Text('JOIN LIVE', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.w700, letterSpacing: 1.2)),
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