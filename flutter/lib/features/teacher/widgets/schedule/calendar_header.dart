import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teacher_theme.dart';
import '../../providers/schedule_provider.dart';

/// Calendar header — date range label + prev/today/next arrows + timezone.
class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(selectedWeekProvider);
    final range = _formatRange(week);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TeacherSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TeacherSpacing.md,
        runSpacing: TeacherSpacing.sm,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(range, style: TeacherTheme.panelTitle()),
              const SizedBox(width: TeacherSpacing.md),
              _ArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _shift(ref, week, -7),
              ),
              const SizedBox(width: TeacherSpacing.sm),
              _ArrowButton(
                icon: Icons.refresh_rounded,
                radius: 12,
                onTap: () => _shift(ref, week, 0, reset: true),
              ),
              const SizedBox(width: TeacherSpacing.sm),
              _ArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _shift(ref, week, 7),
              ),
            ],
          ),
          Text('(GMT +06:00) Public Time',
              style: TeacherTheme.caption()),
        ],
      ),
    );
  }

  void _shift(WidgetRef ref, DateTime week, int days, {bool reset = false}) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    ref.read(selectedWeekProvider.notifier).state =
        reset ? DateTime(monday.year, monday.month, monday.day) : week.add(Duration(days: days));
  }

  String _formatRange(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${_dd(monday)} - ${_dd(sunday)} ${months[sunday.month]}';
  }

  String _dd(DateTime d) => d.day.toString().padLeft(2, '0');
}

class _ArrowButton extends StatefulWidget {
  const _ArrowButton({
    required this.icon,
    required this.onTap,
    this.radius = TeacherTheme.radiusArrow,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double radius;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TeacherTheme.animFast,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered 
                ? TeacherTheme.primaryBlue.withValues(alpha: 0.12)
                : TeacherTheme.primaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: TeacherTheme.textSecondary),
        ),
      ),
    );
  }
}