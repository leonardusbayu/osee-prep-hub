import 'package:flutter/material.dart';

import '../student_theme.dart';

/// Top bar — search, bell, profile chip.
class StudentTopBar extends StatelessWidget {
  const StudentTopBar({
    super.key,
    required this.name,
    this.subtitle,
    this.onMenuTap,
  });

  final String name;
  final String? subtitle;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudentSpacing.xl),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onMenuTap,
            ),
            const SizedBox(width: StudentSpacing.sm),
          ],
          Expanded(child: _SearchField()),
          const SizedBox(width: StudentSpacing.lg),
          const _Bell(),
          const SizedBox(width: StudentSpacing.lg),
          _ProfileChip(name: name, subtitle: subtitle),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: StudentTheme.surface,
        borderRadius: BorderRadius.circular(StudentTheme.radiusSearch),
        boxShadow: StudentTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: StudentSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: StudentTheme.textSecondary),
          const SizedBox(width: StudentSpacing.md),
          Text('Search anything...', style: StudentTheme.searchPlaceholder()),
        ],
      ),
    );
  }
}

class _Bell extends StatefulWidget {
  const _Bell();

  @override
  State<_Bell> createState() => _BellState();
}

class _BellState extends State<_Bell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _hovered ? StudentTheme.background : StudentTheme.surface,
          shape: BoxShape.circle,
          boxShadow: StudentTheme.cardShadow,
          border: Border.all(
            color: _hovered ? StudentTheme.divider : Colors.transparent,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 24,
              color: StudentTheme.textPrimary,
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: StudentTheme.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: StudentTheme.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.name, this.subtitle});
  final String name;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: StudentTheme.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: StudentTheme.surface, width: 2),
                boxShadow: StudentTheme.avatarShadow,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: StudentTheme.primary,
                size: 24,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: StudentTheme.successGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: StudentTheme.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: StudentSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: StudentTheme.profileName()),
            if (subtitle != null)
              Text(subtitle!, style: StudentTheme.profileYear()),
          ],
        ),
      ],
    );
  }
}

/// Welcome hero banner — vibrant gradient with subtle decorations.
class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${_month(now.month)} ${now.day}, ${now.year}';
    final hour = now.hour;
    final greeting = hour < 11
        ? 'Good morning'
        : hour < 15
        ? 'Good afternoon'
        : 'Good evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudentSpacing.xxl),
      decoration: BoxDecoration(
        gradient: StudentTheme.heroGradient,
        borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
        boxShadow: StudentTheme.glowShadow(StudentTheme.primary),
      ),
      child: Stack(
        children: [
          // Background decorations could go here
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        dateStr,
                        style: StudentTheme.dateStyle(Colors.white),
                      ),
                    ),
                    const SizedBox(height: StudentSpacing.lg),
                    Text(
                      '$greeting, $name! 👋',
                      style: StudentTheme.pageTitle(
                        Colors.white,
                      ).copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to crush your goals today? Let\'s get started.',
                      style: StudentTheme.cardLabel(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StudentSpacing.xl),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _month(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];
}

/// Stat card — shows an icon, value, and label.
class StudentStatCard extends StatefulWidget {
  const StudentStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
    required this.surfaceColor,
    this.highlighted = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;
  final Color surfaceColor;
  final bool highlighted;

  @override
  State<StudentStatCard> createState() => _StudentStatCardState();
}

class _StudentStatCardState extends State<StudentStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: StudentTheme.animFast,
          height: 180,
          padding: const EdgeInsets.symmetric(
            horizontal: StudentSpacing.lg,
            vertical: StudentSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: _hovered ? StudentTheme.background : StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            border: Border.all(
              color: widget.highlighted
                  ? widget.accentColor
                  : _hovered
                  ? widget.accentColor.withValues(alpha: 0.3)
                  : StudentTheme.divider,
            ),
            boxShadow: _hovered || widget.highlighted
                ? StudentTheme.glowShadow(widget.accentColor)
                : StudentTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 24),
              ),
              const SizedBox(height: StudentSpacing.lg),
              Text(widget.value, style: StudentTheme.cardValue()),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: StudentTheme.cardLabel(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Course/class card.
class StudentCourseCard extends StatefulWidget {
  const StudentCourseCard({
    super.key,
    required this.title,
    this.progress = 0.0,
    this.onView,
  });

  final String title;
  final double progress;
  final VoidCallback? onView;

  @override
  State<StudentCourseCard> createState() => _StudentCourseCardState();
}

class _StudentCourseCardState extends State<StudentCourseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: StudentTheme.animFast,
          height: 160,
          padding: const EdgeInsets.all(StudentSpacing.lg),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            border: Border.all(
              color: _hovered ? StudentTheme.primary : StudentTheme.divider,
            ),
            boxShadow: _hovered
                ? StudentTheme.glowShadow(StudentTheme.primary)
                : StudentTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: StudentTheme.courseTitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: StudentSpacing.md),
                    if (widget.progress > 0) ...[
                      LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor: StudentTheme.divider,
                        valueColor: const AlwaysStoppedAnimation(
                          StudentTheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: widget.onView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StudentTheme.primarySurface,
                          foregroundColor: StudentTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              StudentTheme.radiusButton,
                            ),
                          ),
                        ),
                        child: Text(
                          'View Course',
                          style: StudentTheme.chipActive(
                            StudentTheme.primary,
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StudentSpacing.lg),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [StudentTheme.primary, StudentTheme.primaryDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: StudentTheme.glowShadow(StudentTheme.primary),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily notice panel.
class DailyNoticePanel extends StatelessWidget {
  const DailyNoticePanel({super.key, required this.items, this.onSeeMore});

  final List<NoticeItem> items;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudentSpacing.lg),
      decoration: BoxDecoration(
        color: StudentTheme.surface,
        borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
        boxShadow: StudentTheme.cardShadow,
        border: Border.all(color: StudentTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _NoticeBlock(item: items[i], onSeeMore: onSeeMore),
            if (i < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoticeBlock extends StatelessWidget {
  const _NoticeBlock({required this.item, this.onSeeMore});
  final NoticeItem item;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    final color = item.isImportant
        ? StudentTheme.warningOrange
        : StudentTheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(item.title, style: StudentTheme.noticeTitle()),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.body,
                style: StudentTheme.noticeBody(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onSeeMore,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See more',
                      style: StudentTheme.link(StudentTheme.primary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: StudentTheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Notice item.
class NoticeItem {
  const NoticeItem({
    required this.title,
    required this.body,
    this.isImportant = false,
    this.icon = Icons.info_outline_rounded,
  });
  final String title;
  final String body;
  final bool isImportant;
  final IconData icon;
}

/// Section header row.
class StudentSectionHeader extends StatelessWidget {
  const StudentSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.onSeeAll,
  });

  final String title;
  final IconData? icon;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: StudentTheme.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: StudentTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
            ],
            Text(title, style: StudentTheme.sectionTitle()),
          ],
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              children: [
                Text(
                  'See all',
                  style: StudentTheme.link(StudentTheme.textSecondary),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: StudentTheme.textSecondary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Instructor avatar row. Renders initials from [names] when available,
/// falling back to generic person icons when count > names.length.
class InstructorRow extends StatelessWidget {
  const InstructorRow({super.key, this.count = 3, this.names = const []});
  final int count;
  final List<String> names;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final avatars = <Widget>[];
    for (var i = 0; i < count; i++) {
      final hasName = i < names.length;
      avatars.add(
        Positioned(
          left: i * 40.0,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: StudentTheme.primarySurface,
              shape: BoxShape.circle,
              border: Border.all(color: StudentTheme.surface, width: 3),
              boxShadow: StudentTheme.avatarShadow,
            ),
            child: hasName
                ? Center(
                    child: Text(
                      _initials(names[i]),
                      style: const TextStyle(
                        color: StudentTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: StudentTheme.primary,
                    size: 24,
                  ),
          ),
        ),
      );
    }
    return SizedBox(height: 64, child: Stack(children: avatars));
  }
}
