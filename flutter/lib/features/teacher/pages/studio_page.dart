import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// OSEE Studio page — T9 (Wave 2) skeleton.
///
/// Magazine-styled real-time collaborative canvas. The full implementation
/// syncs via Yjs + Supabase Realtime. This skeleton renders the chrome:
/// masthead, presence bar (mock), invite button, and item cards.
class StudioPage extends ConsumerStatefulWidget {
  const StudioPage({super.key, required this.syllabusId});
  final String syllabusId;

  @override
  ConsumerState<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends ConsumerState<StudioPage> {
  // TODO: connect to Yjs + Supabase Realtime.
  // Mock presence data.
  final List<_Collaborator> _present = [
    _Collaborator('Andi W.', 'AW', MagazineColors.mastheadGold),
    _Collaborator('Citra L.', 'CL', MagazineColors.dropCapBlue),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        backgroundColor: MagazineColors.paperCream,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: MagazineColors.mastheadGold),
            tooltip: 'Curator Suggest',
            onPressed: () {
              // TODO(T9): call Curator agent for syllabus suggestions.
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: MagazineColors.mastheadGold),
            tooltip: 'Share',
            onPressed: () {},
          ),
        ],
      ),
      backgroundColor: MagazineColors.paperCream,
      body: Column(
        children: [
          _PresenceBar(present: _present),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(MagazineSpacing.base),
              children: [
                const MagazineMasthead(
                  kicker: 'OSEE STUDIO',
                  title: 'IELTS 6-week plan',
                  subtitle: 'Real-time collaborative syllabus builder',
                  date: 'Last edited 2 min ago',
                ),
                const SizedBox(height: MagazineSpacing.lg),
                for (var week = 1; week <= 6; week++) ...[
                  _WeekSection(week: week),
                  const SizedBox(height: MagazineSpacing.base),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Collaborator {
  _Collaborator(this.name, this.initials, this.color);
  final String name;
  final String initials;
  final Color color;
}

class _PresenceBar extends StatelessWidget {
  const _PresenceBar({required this.present});
  final List<_Collaborator> present;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MagazineSpacing.base, vertical: MagazineSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MagazineColors.mastheadGold, width: 1.5)),
      ),
      child: Row(
        children: [
          Text('${present.length} online', style: magazineCaption()),
          const SizedBox(width: MagazineSpacing.sm),
          for (final c in present) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.color),
              alignment: Alignment.center,
              child: Text(c.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Georgia')),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add, size: 14, color: MagazineColors.mastheadGold),
            label: const Text('Invite', style: TextStyle(color: MagazineColors.mastheadGold, fontFamily: 'Georgia')),
            onPressed: () {},
            style: OutlinedButton.styleFrom(side: const BorderSide(color: MagazineColors.mastheadGold)),
          ),
        ],
      ),
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.week});
  final int week;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MagazineSectionRule(label: 'WEEK'),
        const SizedBox(height: MagazineSpacing.sm),
        Text('Week $week', style: magazineHeadline()),
        const SizedBox(height: MagazineSpacing.sm),
        for (var i = 0; i < 3; i++) ...[
          _ItemCard(week: week, itemIndex: i),
          const SizedBox(height: MagazineSpacing.sm),
        ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.week, required this.itemIndex});
  final int week;
  final int itemIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MagazineSpacing.base),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MagazineColors.mastheadGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: MagazineColors.mastheadGold, width: 1.5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('${(week - 1) * 3 + itemIndex + 1}', style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: MagazineSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IELTS Reading Practice $week.${itemIndex + 1}', style: magazineTitle()),
                Text('platform_ielts · 45 min', style: magazineCaption()),
              ],
            ),
          ),
          const Icon(Icons.drag_indicator, color: MagazineColors.inkGray),
        ],
      ),
    );
  }
}