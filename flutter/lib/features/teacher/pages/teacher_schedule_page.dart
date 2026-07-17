import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../teacher_theme.dart';
import '../widgets/schedule/calendar_header.dart';
import '../widgets/schedule/filter_chips.dart';
import '../widgets/schedule/week_calendar_grid.dart';
import '../widgets/schedule/right_panel.dart';

/// Teacher "My Schedule" page — mirrors the Figma Dashboard frame 383:107.
class TeacherSchedulePage extends ConsumerWidget {
  const TeacherSchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    return Padding(
      padding: const EdgeInsets.only(
        top: TeacherSpacing.sm,
        bottom: TeacherSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TeacherSpacing.md),
            child: const CalendarHeader(),
          ),
          const SizedBox(height: TeacherSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TeacherSpacing.md),
            child: const FilterChipsRow(),
          ),
          const SizedBox(height: TeacherSpacing.sm),
          Expanded(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(child: WeekCalendarGrid()),
                      SizedBox(width: TeacherSpacing.md),
                      Padding(
                        padding: EdgeInsets.only(right: TeacherSpacing.md),
                        child: SizedBox(width: 280, child: RightPanel()),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: const [
                        SizedBox(
                          height: 400,
                          child: WeekCalendarGrid(),
                        ),
                        SizedBox(height: TeacherSpacing.md),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: TeacherSpacing.md),
                          child: RightPanel(),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}