import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../teacher_theme.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}

const _navItems = <_NavItem>[
  _NavItem(Icons.dashboard_outlined, 'Dashboard', '/teacher'),
  _NavItem(Icons.calendar_today_outlined, 'My Schedule', '/teacher/schedule'),
  _NavItem(Icons.groups_2_outlined, 'Students', '/teacher/reports'),
  _NavItem(Icons.menu_book_outlined, 'Courses', '/teacher/syllabi'),
  _NavItem(Icons.folder_outlined, 'Resources', '/teacher/generator'),
  _NavItem(Icons.class_outlined, 'Classrooms', '/teacher/classrooms'),
  _NavItem(Icons.shopping_cart_outlined, 'Orders', '/teacher/orders'),
  _NavItem(Icons.payments_outlined, 'Earnings', '/teacher/commission'),
  _NavItem(Icons.edit_note_rounded, 'AI Grader', '/teacher/ai-grader'),
  _NavItem(Icons.mic_rounded, 'Speaking', '/teacher/speaking-grader'),
  _NavItem(Icons.star_rounded, 'Upgrade', '/teacher/upgrade'),
  _NavItem(Icons.settings_outlined, 'Settings', '/teacher/settings'),
];

const _logoutItem = _NavItem(Icons.logout_rounded, 'Log Out', '/login');

/// Teacher sidebar — mirrors the Figma "Dashboard" sidebar (white, 260w, right
/// border, drop shadow offset -16,0 blur 34).
class TeacherSidebar extends ConsumerWidget {
  const TeacherSidebar({super.key, this.onNavigate, this.activeIndex});

  final VoidCallback? onNavigate;
  final int? activeIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final activeIdx = activeIndex ?? _resolveActiveFromLocation(location);
    return Container(
      width: TeacherSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: TeacherTheme.surface,
        border: const Border(right: BorderSide(color: TeacherTheme.divider)),
        boxShadow: TeacherTheme.sidebarShadow,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo area: 24px top padding
            const SizedBox(height: 24),
            const _Logo(),
            // Logo area: 32px bottom padding
            const SizedBox(height: 32),
            // Profile card
            const _ProfileCard(),
            // Profile card: 24px bottom, then divider
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1),
            ),
            // 12px gap before nav list
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                // Fix: nav items + 1 spacer + 1 logout (was +2+1 causing duplicate logout)
                itemCount: _navItems.length + 1 + 1,
                itemBuilder: (context, i) {
                  if (i < _navItems.length) {
                    final item = _navItems[i];
                    return _NavTile(
                      item: item,
                      active: i == activeIdx,
                      onTap: () {
                        if (location != item.route) {
                          context.go(item.route);
                        }
                        onNavigate?.call();
                      },
                    );
                  }
                  if (i == _navItems.length) {
                    return const SizedBox(height: TeacherSpacing.xxl);
                  }
                  // Single logout item
                  return _NavTile(
                    item: _logoutItem,
                    active: false,
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                      onNavigate?.call();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _resolveActiveFromLocation(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      final route = _navItems[i].route;
      if (route == '/teacher') {
        if (location == '/teacher') return i;
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [TeacherTheme.primaryBlue, TeacherTheme.successGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.color_lens_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('Teach.', style: TeacherTheme.logo()),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = user?.displayName ?? 'Teacher';
    final role = user?.role.label ?? 'teacher';
    final initials = _initialsFor(name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Avatar with online status indicator
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              children: [
                _Avatar(initials: initials, size: 38),
                // Online status green dot
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: TeacherTheme.successGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: TeacherTheme.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TeacherTheme.userName()),
                const SizedBox(height: 2),
                Text(role, style: TeacherTheme.userRole()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.size = 32});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TeacherTheme.primaryBlueSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TeacherTheme.userName(
          TeacherTheme.primaryBlue,
        ).copyWith(fontSize: size * 0.4),
      ),
    );
  }
}

/// Nav tile as StatefulWidget to track hover state.
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
    final color = active
        ? TeacherTheme.primaryBlue
        : TeacherTheme.textSecondary;

    // Determine background: active > hover > transparent
    Color bgColor;
    if (active) {
      bgColor = TeacherTheme.activeNavBg;
    } else if (_hovered) {
      bgColor = TeacherTheme.hoverBg;
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          child: AnimatedContainer(
            duration: TeacherTheme.animFast,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(TeacherTheme.radiusNav),
            ),
            child: Row(
              children: [
                // Active left accent bar
                AnimatedContainer(
                  duration: TeacherTheme.animFast,
                  width: 3,
                  height: active ? 24 : 0,
                  decoration: BoxDecoration(
                    color: active
                        ? TeacherTheme.primaryBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Padding between accent bar and icon
                const SizedBox(width: 7),
                Icon(widget.item.icon, size: 22, color: color),
                const SizedBox(width: 14),
                Text(
                  widget.item.label,
                  style: TeacherTheme.navLabel(color, active: active),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
