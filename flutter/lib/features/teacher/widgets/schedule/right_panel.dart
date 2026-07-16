import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teacher_theme.dart';
import '../../models/schedule_models.dart';
import '../../providers/schedule_provider.dart';

/// Right panel — "Upcoming Events" + "Top Performing Courses" cards.
/// Scrollable to prevent overflow on small screens.
class RightPanel extends ConsumerWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingEventsProvider);
    final top = ref.watch(topCoursesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelCard(
          title: 'Upcoming Events',
          child: Column(
            children: upcoming.map((e) => _UpcomingTile(event: e)).toList(),
          ),
        ),
        const SizedBox(height: TeacherSpacing.md),
        _PanelCard(
          title: 'Top Performing Courses',
          child: Column(
            children: top.map((c) => _TopCourseTile(course: c)).toList(),
          ),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TeacherTheme.surface,
        borderRadius: BorderRadius.circular(TeacherTheme.radiusPanel),
        border: Border.all(color: TeacherTheme.divider),
        boxShadow: TeacherTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TeacherTheme.panelTitle(),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatefulWidget {
  const _UpcomingTile({required this.event});
  final UpcomingEvent event;

  @override
  State<_UpcomingTile> createState() => _UpcomingTileState();
}

class _UpcomingTileState extends State<_UpcomingTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: TeacherTheme.animFast,
        color: _hovered ? TeacherTheme.hoverBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: widget.event.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: TeacherTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.event.dateLabel} · ${widget.event.timeLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: TeacherTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCourseTile extends StatefulWidget {
  const _TopCourseTile({required this.course});
  final TopCourse course;

  @override
  State<_TopCourseTile> createState() => _TopCourseTileState();
}

class _TopCourseTileState extends State<_TopCourseTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: TeacherTheme.animFast,
        color: _hovered ? TeacherTheme.hoverBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.course.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: TeacherTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.course.students}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TeacherTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: widget.course.progress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: TeacherTheme.dividerSubtle,
                    valueColor: AlwaysStoppedAnimation(widget.course.accent),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}