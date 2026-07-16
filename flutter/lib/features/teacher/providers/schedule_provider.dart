import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_models.dart';

/// Current week shown on the calendar. Mocked to the Figma week: 02-08 March.
final selectedWeekProvider = StateProvider<DateTime>((ref) {
  // Monday 2 March 2026 — the Figma sample week.
  return DateTime(2026, 3, 2);
});

/// Active course-type filter.
final selectedCourseFilterProvider =
    StateProvider<CourseType>((ref) => CourseType.all);

/// Mock schedule events matching the Figma frame content.
final scheduleEventsProvider = Provider<List<ScheduleEvent>>((ref) {
  final week = ref.watch(selectedWeekProvider);
  final portrait = const Course(
    title: 'Portrait Photography\nMasterclass',
    instructor: 'Jone Copper',
    type: CourseType.webinar,
    accent: Color(0xFF0177FB),
  );
  final uiDesign = const Course(
    title: 'User Interface\nDesign Masterclass',
    instructor: 'Jone Copper',
    type: CourseType.personalCoaching,
    accent: Color(0xFF6ED097),
  );
  return [
    ScheduleEvent(
      course: portrait,
      start: week.copyWith(hour: 9, minute: 0),
      end: week.copyWith(hour: 11, minute: 0),
    ),
    ScheduleEvent(
      course: uiDesign,
      start: week.copyWith(hour: 14, minute: 0),
      end: week.copyWith(hour: 16, minute: 0),
    ),
    ScheduleEvent(
      course: portrait,
      start: week.add(const Duration(days: 2)).copyWith(hour: 10, minute: 0),
      end: week.add(const Duration(days: 2)).copyWith(hour: 12, minute: 0),
    ),
    ScheduleEvent(
      course: uiDesign,
      start: week.add(const Duration(days: 3)).copyWith(hour: 13, minute: 0),
      end: week.add(const Duration(days: 3)).copyWith(hour: 15, minute: 0),
    ),
    ScheduleEvent(
      course: portrait,
      start: week.add(const Duration(days: 4)).copyWith(hour: 9, minute: 30),
      end: week.add(const Duration(days: 4)).copyWith(hour: 11, minute: 30),
    ),
  ];
});

/// Filtered events based on the selected course-type chip.
final filteredScheduleEventsProvider = Provider<List<ScheduleEvent>>((ref) {
  final events = ref.watch(scheduleEventsProvider);
  final filter = ref.watch(selectedCourseFilterProvider);
  if (filter == CourseType.all) return events;
  return events.where((e) => e.course.type == filter).toList();
});

/// Mock upcoming events for the right panel.
final upcomingEventsProvider = Provider<List<UpcomingEvent>>((ref) {
  return const [
    UpcomingEvent(
      title: 'Portrait Photography Masterclass',
      dateLabel: 'Today',
      timeLabel: '09:00 — 11:00',
      accent: Color(0xFF0177FB),
    ),
    UpcomingEvent(
      title: 'User Interface Design Masterclass',
      dateLabel: 'Tomorrow',
      timeLabel: '14:00 — 16:00',
      accent: Color(0xFF6ED097),
    ),
    UpcomingEvent(
      title: 'Webinar: Lighting Basics',
      dateLabel: 'Fri, 06 Mar',
      timeLabel: '10:00 — 12:00',
      accent: Color(0xFF0177FB),
    ),
  ];
});

/// Mock top performing courses for the right panel.
final topCoursesProvider = Provider<List<TopCourse>>((ref) {
  return const [
    TopCourse(
      title: 'Portrait Photography Masterclass',
      students: 248,
      progress: 0.82,
      accent: Color(0xFF6ED097),
    ),
    TopCourse(
      title: 'User Interface Design Masterclass',
      students: 186,
      progress: 0.64,
      accent: Color(0xFF0177FB),
    ),
    TopCourse(
      title: 'Webinar: Lighting Basics',
      students: 142,
      progress: 0.48,
      accent: Color(0xFF6ED097),
    ),
  ];
});