import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import 'student_sidebar.dart';

/// Persistent shell for all student routes — rendered once by the router's
/// `StatefulShellRoute.indexedStack`. The sidebar stays mounted across
/// navigation; only the body (navigationShell) swaps.
class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final showSidebar =
        Responsive.isExpanded(context) || Responsive.isLarge(context);

    return Theme(
      data: StudentTheme.light(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: StudentTheme.background,
        drawer: showSidebar
            ? null
            : Drawer(
                width: 260,
                child: StudentSidebar(
                  activeIndex: widget.navigationShell.currentIndex,
                  onNavigate: () => _closeDrawer(),
                  onLogout: _logout,
                ),
              ),
        body: showSidebar
            ? Row(
                children: [
                  StudentSidebar(
                    activeIndex: widget.navigationShell.currentIndex,
                    onLogout: _logout,
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              )
            : widget.navigationShell,
      ),
    );
  }

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }
}