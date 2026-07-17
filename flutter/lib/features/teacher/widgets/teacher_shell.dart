import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive.dart';
import '../teacher_theme.dart';
import 'teacher_sidebar.dart';
import 'teacher_topbar.dart';

/// Persistent shell for all teacher routes — rendered once by the router's
/// `StatefulShellRoute.indexedStack`. The sidebar + topbar stay mounted across
/// navigation; only the body (navigationShell) swaps.
class TeacherShell extends ConsumerStatefulWidget {
  const TeacherShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final showSidebar =
        Responsive.isExpanded(context) || Responsive.isLarge(context);
    final shellIndex = widget.navigationShell.currentIndex;
    final meta = _routeMetaForIndex(shellIndex);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: TeacherTheme.background,
      drawer: showSidebar
          ? null
          : Drawer(
              width: TeacherSpacing.sidebarWidth,
              child: TeacherSidebar(
                activeIndex: _navIndexFromShellIndex(shellIndex),
                onNavigate: () => _closeDrawer(),
              ),
            ),
      body: showSidebar
          ? Row(
              children: [
                TeacherSidebar(
                  activeIndex: _navIndexFromShellIndex(shellIndex),
                  onNavigate: () {},
                ),
                Expanded(
                  child: Column(
                    children: [
                      TeacherTopbar(
                        title: meta.title,
                        actions: meta.actions,
                        bottom: meta.bottom,
                      ),
                      Expanded(child: widget.navigationShell),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                TeacherTopbar(
                  title: meta.title,
                  actions: meta.actions,
                  bottom: meta.bottom,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(child: widget.navigationShell),
              ],
            ),
      floatingActionButton: meta.fab,
    );
  }

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  /// Maps the shell branch index → sidebar nav item index.
  /// The sidebar nav items have a fixed order; branches have a different order.
  int _navIndexFromShellIndex(int shellIndex) {
    // Shell branch → nav item route → nav index
    const shellToRoute = <String>[
      '/teacher', // 0
      '/teacher/orders', // 1
      '/teacher/schedule', // 2
      '/teacher/ai-grader', // 3
      '/teacher/speaking-grader', // 4
      '/teacher/generator', // 5
      '/teacher/syllabi', // 6
      '/teacher/syllabi', // 7 (builder, same nav highlight)
      '/teacher/classrooms', // 8
      '/teacher/classrooms', // 9 (detail, same nav highlight)
      '/teacher/classrooms', // 10 (report, same nav highlight)
      '/teacher/commission', // 11
      '/teacher/reports', // 12
      '/teacher/settings', // 13
      '/teacher/upgrade', // 14
    ];
    if (shellIndex >= shellToRoute.length) return 0;
    final route = shellToRoute[shellIndex];
    // Find matching nav item
    const navRoutes = [
      '/teacher',
      '/teacher/schedule',
      '/teacher',
      '/teacher/reports',
      '/teacher/syllabi',
      '/teacher/generator',
      '/teacher/classrooms',
      '/teacher/orders',
      '/teacher/commission',
      '/teacher/ai-grader',
      '/teacher/speaking-grader',
      '/teacher/upgrade',
      '/teacher/settings',
    ];
    for (int i = 0; i < navRoutes.length; i++) {
      if (route == '/teacher') {
        if (navRoutes[i] == '/teacher') return i;
      } else if (navRoutes[i] == route) {
        return i;
      }
    }
    return 0;
  }

  _RouteMeta _routeMetaForIndex(int index) {
    const titles = <String>[
      'My Schedule',
      'Dashboard',
      'Orders',
      'Schedule',
      'AI Writing Grader',
      'AI Speaking Grader',
      'Material Generator',
      'Syllabi',
      'Syllabus Builder',
      'Classrooms',
      'Classroom',
      'Classroom Report',
      'Earnings',
      'Student Reports',
      'Settings',
      'Upgrade',
    ];
    final title = index < titles.length ? titles[index] : 'Teacher';
    return _RouteMeta(title: title);
  }
}

class _RouteMeta {
  const _RouteMeta({required this.title, this.actions, this.bottom, this.fab});

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? fab;
}
