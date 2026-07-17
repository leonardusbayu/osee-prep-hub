import 'package:flutter/material.dart';

/// Course delivery type — mirrors the Figma filter chips row.
enum CourseType { all, oneByOne, webinar, personalCoaching, workshop }

/// A course definition.
class Course {
  const Course({
    required this.title,
    required this.instructor,
    required this.type,
    this.accent = const Color(0xFF0177FB),
    this.avatarInitials = 'JC',
  });

  final String title;
  final String instructor;
  final CourseType type;
  final Color accent;
  final String avatarInitials;
}

/// A scheduled event placed on the week grid.
class ScheduleEvent {
  const ScheduleEvent({
    required this.course,
    required this.start,
    required this.end,
  });

  final Course course;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  /// 0 = Monday .. 6 = Sunday
  int get weekdayIndex => start.weekday - 1;
}

/// Upcoming event entry for the right panel.
class UpcomingEvent {
  const UpcomingEvent({
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    this.accent = const Color(0xFF0177FB),
  });

  final String title;
  final String dateLabel;
  final String timeLabel;
  final Color accent;
}

/// Top performing course entry for the right panel.
class TopCourse {
  const TopCourse({
    required this.title,
    required this.students,
    required this.progress,
    this.accent = const Color(0xFF6ED097),
  });

  final String title;
  final int students;
  final double progress; // 0..1
  final Color accent;
}