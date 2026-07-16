import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teacher_theme.dart';
import '../../models/schedule_models.dart';
import '../../providers/schedule_provider.dart';
import 'event_card.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _hourStart = 8;
const _hourEnd = 20;
const _hourHeight = 56.0;
const _hourAxisWidth = 44.0;

/// Week calendar grid — 7 day columns over an hourly vertical axis.
/// Header + body share one horizontal scroll so they stay aligned.
class WeekCalendarGrid extends ConsumerWidget {
  const WeekCalendarGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(selectedWeekProvider);
    final events = ref.watch(filteredScheduleEventsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isDesktop = screenWidth >= 1200;
        final isTablet = screenWidth >= 840 && screenWidth < 1200;
        
        final minDayColWidth = isDesktop ? 120.0 : (isTablet ? 100.0 : 80.0);
        final minTotalWidth = minDayColWidth * 7 + _hourAxisWidth;

        // Determine available width (accounting for margins)
        // Margin is TeacherSpacing.md (16) on both sides = 32
        final availableWidth = constraints.maxWidth - (TeacherSpacing.md * 2);
        
        double dayColWidth;
        if (availableWidth > minTotalWidth) {
          dayColWidth = (availableWidth - _hourAxisWidth) / 7;
        } else {
          dayColWidth = minDayColWidth;
        }
        
        final totalWidth = dayColWidth * 7 + _hourAxisWidth;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: TeacherSpacing.md,
            vertical: TeacherSpacing.sm,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          decoration: BoxDecoration(
            color: TeacherTheme.surface,
            borderRadius: BorderRadius.circular(TeacherTheme.radiusCard),
            border: Border.all(color: TeacherTheme.dividerSubtle),
            boxShadow: TeacherTheme.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TeacherTheme.radiusCard),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    _DayHeaderRow(week: week, dayColWidth: dayColWidth),
                    const Divider(height: 1, color: TeacherTheme.dividerSubtle),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          height: (_hourEnd - _hourStart) * _hourHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HourAxis(),
                              ...List.generate(7, (i) {
                                final day = week.add(Duration(days: i));
                                final dayEvents = events
                                    .where((e) => e.weekdayIndex == i)
                                    .toList();
                                return _DayColumn(
                                  date: day,
                                  events: dayEvents,
                                  isToday: _isToday(day),
                                  colWidth: dayColWidth,
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({required this.week, required this.dayColWidth});
  final DateTime week;
  final double dayColWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: _hourAxisWidth),
          ...List.generate(7, (i) {
            final day = week.add(Duration(days: i));
            final isToday = _isToday(day);
            return SizedBox(
              width: dayColWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayLabels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: TeacherTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? TeacherTheme.primaryBlue : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? Colors.white
                            : TeacherTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _HourAxis extends StatelessWidget {
  const _HourAxis();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _hourAxisWidth,
      child: Column(
        children: List.generate(_hourEnd - _hourStart, (i) {
          final hour = _hourStart + i;
          return SizedBox(
            height: _hourHeight,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: TeacherTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.events,
    required this.isToday,
    required this.colWidth,
  });

  final DateTime date;
  final List<ScheduleEvent> events;
  final bool isToday;
  final double colWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: colWidth,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: TeacherTheme.dividerSubtle)),
      ),
      child: Stack(
        children: [
          if (isToday)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(color: Color(0x080177FB)),
              ),
            ),
          ...List.generate(_hourEnd - _hourStart + 1, (i) {
            return Positioned(
              top: i * _hourHeight,
              left: 0,
              right: 0,
              child: const Divider(height: 1, color: TeacherTheme.dividerSubtle),
            );
          }),
          ...events.map((e) {
            final startMinutes =
                (e.start.hour - _hourStart) * 60 + e.start.minute;
            final durationMinutes = e.duration.inMinutes;
            final top = startMinutes * _hourHeight / 60;
            final cardHeight =
                (durationMinutes * _hourHeight / 60).clamp(28.0, 120.0);
            return Positioned(
              top: top + 1,
              left: 3,
              right: 3,
              height: cardHeight - 2,
              child: ScheduleEventCard(event: e),
            );
          }),
        ],
      ),
    );
  }
}