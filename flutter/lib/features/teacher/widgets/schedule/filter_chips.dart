import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teacher_theme.dart';
import '../../models/schedule_models.dart';
import '../../providers/schedule_provider.dart';

const _filterChips = <_ChipDef>[
  _ChipDef(label: 'All Course', type: CourseType.all),
  _ChipDef(label: 'One by One', type: CourseType.oneByOne),
  _ChipDef(label: 'Webinar', type: CourseType.webinar),
  _ChipDef(label: 'Personal Coaching', type: CourseType.personalCoaching),
  _ChipDef(label: 'Workshop', type: CourseType.workshop),
];

class _ChipDef {
  const _ChipDef({required this.label, required this.type});
  final String label;
  final CourseType type;
}

/// Filter chips row — mirrors the Figma row (active chip: #141736 + green dot).
class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCourseFilterProvider);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterChips.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: TeacherSpacing.sm),
        itemBuilder: (context, i) {
          final chip = _filterChips[i];
          final active = chip.type == selected;
          return _Chip(chip: chip, active: active);
        },
      ),
    );
  }
}

class _Chip extends ConsumerStatefulWidget {
  const _Chip({required this.chip, required this.active});
  final _ChipDef chip;
  final bool active;

  @override
  ConsumerState<_Chip> createState() => _ChipState();
}

class _ChipState extends ConsumerState<_Chip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final color =
        active ? TeacherTheme.textActive : TeacherTheme.textSecondary;
        
    Color bgColor;
    if (active) {
      bgColor = TeacherTheme.primaryBlueSoft;
    } else if (_hovered) {
      bgColor = TeacherTheme.primaryBlue.withValues(alpha: 0.06);
    } else {
      bgColor = TeacherTheme.primaryBlue.withValues(alpha: 0.03);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ref.read(selectedCourseFilterProvider.notifier).state =
            widget.chip.type,
        child: AnimatedContainer(
          duration: TeacherTheme.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(TeacherTheme.radiusButton),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: TeacherTheme.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(widget.chip.label,
                  style: active
                      ? TeacherTheme.chipActive(color)
                      : TeacherTheme.chipInactive(color)),
            ],
          ),
        ),
      ),
    );
  }
}