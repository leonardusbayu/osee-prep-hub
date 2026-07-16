import 'package:flutter/material.dart';

import '../../teacher_theme.dart';
import '../../models/schedule_models.dart';

/// Compact event card for calendar grid slots. Auto-truncates content
/// based on available height to prevent overflow.
class ScheduleEventCard extends StatefulWidget {
  const ScheduleEventCard({super.key, required this.event});

  final ScheduleEvent event;

  @override
  State<ScheduleEventCard> createState() => _ScheduleEventCardState();
}

class _ScheduleEventCardState extends State<ScheduleEventCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: TeacherTheme.animFast,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.event.course.accent.withValues(alpha: 0.08)
              : widget.event.course.accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: widget.event.course.accent, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_fmt(widget.event.start)} — ${_fmt(widget.event.end)}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: widget.event.course.accent,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                widget.event.course.title.replaceAll('\n', ' '),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: TeacherTheme.textPrimary,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}