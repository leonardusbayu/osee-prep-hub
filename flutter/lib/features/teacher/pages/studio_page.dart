import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:osee_prep_hub/core/api_client.dart';
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

  /// Invite a collaborator by email. Calls POST /api/syllabi/:id/collaborators (T2).
  Future<void> _showInviteDialog(BuildContext context, String syllabusId) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MagazineColors.paperCream,
        title: const Text('Invite collaborator', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MagazineColors.mastheadGold),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('INVITE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty) return;

    try {
      final dio = ApiClient.create();
      await dio.post('/syllabi/$syllabusId/collaborators', data: {'email': email.trim()});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: MagazineColors.successGreen,
        content: Text('Invited $email to collaborate'),
      ));
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: MagazineColors.errorRed,
        content: Text('Invite failed: ${e.response?.data['error']?['message'] ?? e.message}'),
      ));
    }
  }

  /// Show a modal sheet that calls the real Curator agent (POST /api/agents/curator/invoke).
  Future<void> _showCuratorSuggest(BuildContext context) async {
    final controller = TextEditingController(text: 'Suggest 3-5 items for this syllabus based on student progress.');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MagazineColors.paperCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: MagazineSpacing.base,
          right: MagazineSpacing.base,
          top: MagazineSpacing.base,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + MagazineSpacing.base,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MagazineSectionRule(label: 'CURATOR AGENT'),
            const SizedBox(height: MagazineSpacing.sm),
            Text('Curator will suggest syllabus items.', style: magazineTitle()),
            const SizedBox(height: MagazineSpacing.sm),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'What do you want the curator to consider?',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: MagazineSpacing.base),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: MagazineSpacing.sm),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: MagazineColors.mastheadGold),
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: const Text('ASK CURATOR', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null || result.trim().isEmpty || !context.mounted) return;

    // Show loading.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: MagazineColors.mastheadGold)),
    );

    try {
      final dio = ApiClient.create();
      final resp = await dio.post('/agents/curator/invoke', data: {
        'input': result,
        // Note: in production the server reads syllabus from the agent context.
        // For this wire-up we pass the input directly.
      });
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      final response = resp.data['response'] as String? ?? '(no response)';
      // Show the curator's suggestions as a result sheet.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: MagazineColors.paperCream,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(MagazineSpacing.base),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MagazineSectionRule(label: 'CURATOR SUGGESTIONS'),
                const SizedBox(height: MagazineSpacing.sm),
                Text('Curator\'s response', style: magazineTitle()),
                const SizedBox(height: MagazineSpacing.base),
                Container(
                  padding: const EdgeInsets.all(MagazineSpacing.base),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: MagazineColors.mastheadGold.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(response, style: magazineBody()),
                ),
                const SizedBox(height: MagazineSpacing.base),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: MagazineColors.mastheadGold),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CLOSE', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    } on DioException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: MagazineColors.errorRed,
        content: Text('Curator failed: ${e.message ?? e.toString()}'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: MagazineColors.errorRed,
        content: Text('Curator failed: $e'),
      ));
    }
  }

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
            onPressed: () => _showCuratorSuggest(context),
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
          _PresenceBar(
            present: _present,
            onInvite: () => _showInviteDialog(context, widget.syllabusId),
          ),
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
  const _PresenceBar({required this.present, required this.onInvite});
  final List<_Collaborator> present;
  final VoidCallback onInvite;

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
            onPressed: onInvite,
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