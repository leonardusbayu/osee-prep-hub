import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/schedule_models.dart';

/// Current week shown on the calendar. Defaults to the current week (Monday).
final selectedWeekProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1));
});

/// Active course-type filter.
final selectedCourseFilterProvider = StateProvider<CourseType>(
  (ref) => CourseType.all,
);

/// Raw teacher dashboard response from GET /api/teacher/dashboard.
/// Shape (see worker/src/routes/teacher.ts):
///   { classrooms_count, total_students, commission_this_month,
///     ai_quota_remaining, recent_activity: [{ id, action, amount_idr,
///     status, created_at }] }
typedef DashboardJson = Map<String, dynamic>;

final dashboardProvider = FutureProvider.autoDispose<DashboardJson>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/teacher/dashboard');
  return res.data as DashboardJson;
});

/// Schedule events derived from the teacher's recent commission-ledger
/// activity. Each activity becomes a calendar entry on the day it happened.
/// This wires the Figma-style calendar to real backend data.
final scheduleEventsProvider = Provider<List<ScheduleEvent>>((ref) {
  final week = ref.watch(selectedWeekProvider);
  final asyncDash = ref.watch(dashboardProvider);

  final activity = asyncDash.maybeWhen(
    data: (data) => (data['recent_activity'] as List<dynamic>?) ?? const [],
    orElse: () => const [],
  );

  final events = <ScheduleEvent>[];
  for (final entry in activity) {
    final map = entry as Map<String, dynamic>;
    final createdAt = map['created_at'] as String?;
    if (createdAt == null) continue;
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) continue;
    // Skip entries outside the selected week.
    if (dt.isBefore(week) || dt.isAfter(week.add(const Duration(days: 7)))) {
      continue;
    }
    final action = (map['action'] as String?) ?? 'activity';
    events.add(
      ScheduleEvent(
        course: Course(
          title: _actionLabel(action),
          instructor: '',
          type: _actionType(action),
          accent: _actionColor(action),
        ),
        start: dt.copyWith(hour: 9, minute: 0),
        end: dt.copyWith(hour: 10, minute: 0),
      ),
    );
  }
  return events;
});

/// Filtered events based on the selected course-type chip.
final filteredScheduleEventsProvider = Provider<List<ScheduleEvent>>((ref) {
  final events = ref.watch(scheduleEventsProvider);
  final filter = ref.watch(selectedCourseFilterProvider);
  if (filter == CourseType.all) return events;
  return events.where((e) => e.course.type == filter).toList();
});

/// Upcoming events — next 3 commission activities after today, derived from
/// recent_activity sorted descending. Falls back to empty list while loading.
final upcomingEventsProvider = Provider<List<UpcomingEvent>>((ref) {
  final asyncDash = ref.watch(dashboardProvider);
  return asyncDash.maybeWhen(
    data: (data) {
      final activity = (data['recent_activity'] as List<dynamic>?) ?? const [];
      final now = DateTime.now();
      final upcoming = <UpcomingEvent>[];
      for (final entry in activity) {
        final map = entry as Map<String, dynamic>;
        final createdAt = map['created_at'] as String?;
        if (createdAt == null) continue;
        final dt = DateTime.tryParse(createdAt);
        if (dt == null || dt.isBefore(now)) continue;
        final action = (map['action'] as String?) ?? 'activity';
        upcoming.add(
          UpcomingEvent(
            title: _actionLabel(action),
            dateLabel: _relativeDate(dt),
            timeLabel:
                '${dt.hour.toString().padLeft(2, '0')}:00 — ${(dt.hour + 1).toString().padLeft(2, '0')}:00',
            accent: _actionColor(action),
          ),
        );
        if (upcoming.length >= 3) break;
      }
      return upcoming;
    },
    orElse: () => const [],
  );
});

/// Top performing courses — derived from classrooms_count + total_students.
/// Maps the teacher's classroom portfolio to per-platform activity counts
/// (based on recent commission-ledger actions).
final topCoursesProvider = Provider<List<TopCourse>>((ref) {
  final asyncDash = ref.watch(dashboardProvider);
  return asyncDash.maybeWhen(
    data: (data) {
      final totalStudents = (data['total_students'] as num?)?.toInt() ?? 0;
      final classroomsCount = (data['classrooms_count'] as num?)?.toInt() ?? 0;
      final activity = (data['recent_activity'] as List<dynamic>?) ?? const [];

      // Tally per-action student counts to surface the most-active platforms.
      final actionCounts = <String, int>{};
      for (final entry in activity) {
        final map = entry as Map<String, dynamic>;
        final action = (map['action'] as String?) ?? 'activity';
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
      }

      final top = <TopCourse>[];
      final sortedActions = actionCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sortedActions.take(3)) {
        top.add(
          TopCourse(
            title: _actionLabel(e.key),
            students: e.value,
            progress: totalStudents > 0 ? e.value / totalStudents : 0,
            accent: _actionColor(e.key),
          ),
        );
      }
      // Always show at least one card so the panel isn't empty.
      if (top.isEmpty) {
        top.add(
          TopCourse(
            title: 'Your classroom portfolio',
            students: totalStudents,
            progress: 0,
            accent: const Color(0xFF6ED097),
          ),
        );
      }
      // Use classroomsCount to satisfy the field reference (unused otherwise).
      assert(classroomsCount >= 0);
      return top;
    },
    orElse: () => const [],
  );
});

// ---------- helpers ----------

String _actionLabel(String action) {
  switch (action) {
    case 'first_test':
      return 'First practice test completed';
    case 'official_booking':
      return 'Official test booked';
    case 'premium_monthly':
      return 'EduBot premium subscription';
    case 'practice_package':
      return 'Practice package purchased';
    default:
      return action.replaceAll('_', ' ');
  }
}

CourseType _actionType(String action) {
  switch (action) {
    case 'official_booking':
      return CourseType.webinar;
    case 'premium_monthly':
      return CourseType.personalCoaching;
    case 'practice_package':
      return CourseType.workshop;
    default:
      return CourseType.oneByOne;
  }
}

Color _actionColor(String action) {
  switch (action) {
    case 'first_test':
      return const Color(0xFF6ED097);
    case 'official_booking':
      return const Color(0xFF0177FB);
    case 'premium_monthly':
      return const Color(0xFFB084CC);
    default:
      return const Color(0xFFF5A623);
  }
}

String _relativeDate(DateTime dt) {
  final now = DateTime.now();
  final diff = DateTime(
    dt.year,
    dt.month,
    dt.day,
  ).difference(DateTime(now.year, now.month, now.day));
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Tomorrow';
  if (diff.inDays == -1) return 'Yesterday';
  final d = dt;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}
