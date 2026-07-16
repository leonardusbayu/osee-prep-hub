import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../student_theme.dart';

/// Sidebar item model.
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}

const _navItems = <_NavItem>[
  _NavItem(Icons.dashboard_rounded, 'Dashboard', '/student'),
  _NavItem(Icons.bar_chart_rounded, 'Progress', '/student/progress'),
  _NavItem(Icons.menu_book_rounded, 'Syllabus', '/student/syllabus'),
  _NavItem(Icons.verified_rounded, 'Readiness', '/student/readiness'),
  _NavItem(Icons.video_library_rounded, 'Videos', '/student/videos'),
  _NavItem(Icons.videocam_rounded, 'Live', '/student/classes'),
  _NavItem(Icons.compare_arrows_rounded, 'Cross-Exam', '/student/cross-exam'),
  _NavItem(Icons.event_rounded, 'Book Test', '/student/book-test'),
];

/// Student sidebar — dark navy premium styling.
class StudentSidebar extends StatelessWidget {
  const StudentSidebar({super.key, this.onNavigate, this.onLogout, this.activeIndex});

  final VoidCallback? onNavigate;
  final VoidCallback? onLogout;
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final activeIdx = activeIndex ?? _resolveActiveFromLocation(location);
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: StudentTheme.sidebarGradient,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(StudentTheme.radiusCard),
          bottomRight: Radius.circular(StudentTheme.radiusCard),
        ),
        boxShadow: StudentTheme.rootShadow,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: StudentSpacing.lg),
            const _Logo(),
            const SizedBox(height: StudentSpacing.xxl),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: StudentSpacing.lg),
              child: Divider(color: Colors.white12, height: 1),
            ),
            const SizedBox(height: StudentSpacing.md),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StudentSpacing.md,
                    ),
                    child: _NavTile(
                      item: _navItems[i],
                      active: i == activeIdx,
                      onTap: () {
                        context.go(_navItems[i].route);
                        onNavigate?.call();
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  StudentSpacing.md, 0, StudentSpacing.md, StudentSpacing.xxl),
              child: _LogoutTile(onTap: () {
                onNavigate?.call();
                onLogout?.call();
              }),
            ),
          ],
        ),
      ),
    );
  }

  int _resolveActiveFromLocation(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      final route = _navItems[i].route;
      if (route == '/student') {
        if (location == '/student') return i;
      } else if (location.startsWith(route)) {
        return i;
      }
    }
    return 0;
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudentSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: StudentTheme.logoGradient,
              borderRadius: BorderRadius.circular(StudentTheme.radiusLogo),
              boxShadow: StudentTheme.glowShadow(StudentTheme.primary),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 20,
              color: StudentTheme.textOnPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'OSEE Prep',
            style: StudentTheme.pageTitle(Colors.white).copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final color = active ? Colors.white : Colors.white70;

    Color bgColor;
    if (active) {
      bgColor = Colors.white.withValues(alpha: 0.1);
    } else if (_hovered) {
      bgColor = Colors.white.withValues(alpha: 0.05);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AnimatedContainer(
            duration: StudentTheme.animFast,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(StudentTheme.radiusNav),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: StudentTheme.animFast,
                  width: 3,
                  height: active ? 24 : 0,
                  decoration: BoxDecoration(
                    color: active ? StudentTheme.primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(widget.item.icon, size: 22, color: color),
                const SizedBox(width: 14),
                Text(
                  widget.item.label,
                  style: active
                      ? StudentTheme.navActive().copyWith(color: color)
                      : StudentTheme.navInactive().copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatefulWidget {
  const _LogoutTile({this.onTap});
  final VoidCallback? onTap;

  @override
  State<_LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<_LogoutTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? Colors.white : Colors.white70;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: StudentTheme.animFast,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(StudentTheme.radiusNav),
          ),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 22,
                color: color,
              ),
              const SizedBox(width: 14),
              Text(
                'Logout',
                style: StudentTheme.navInactive().copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}