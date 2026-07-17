import 'package:flutter/material.dart';

import '../../../core/responsive.dart';
import '../teacher_theme.dart';
import 'teacher_sidebar.dart';
import 'teacher_topbar.dart';

/// Shell for the teacher module — sidebar + topbar + body.
///
/// Does NOT override the ambient [Theme] — the sidebar and topbar use
/// [TeacherTheme] styles explicitly, while the body keeps the parent theme so
/// legacy widgets (PageHeader, StatCard, etc.) render correctly.
class TeacherScaffold extends StatelessWidget {
  const TeacherScaffold({
    super.key,
    required this.body,
    this.title = 'My Schedule',
    this.actions,
    this.bottom,
    this.floatingActionButton,
  });

  final Widget body;
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final showSidebar =
        Responsive.isExpanded(context) || Responsive.isLarge(context);

    return Scaffold(
      backgroundColor: TeacherTheme.background,
      drawer: showSidebar
          ? null
          : Drawer(
              width: TeacherSpacing.sidebarWidth,
              child: const TeacherSidebar(),
            ),
      body: showSidebar
          ? Row(
              children: [
                const TeacherSidebar(),
                Expanded(
                  child: Container(
                    color: TeacherTheme.background,
                    child: Column(
                      children: [
                        TeacherTopbar(
                          title: title,
                          actions: actions,
                          bottom: bottom,
                        ),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Builder(
                  builder: (innerContext) => TeacherTopbar(
                    title: title,
                    actions: actions,
                    bottom: bottom,
                    onMenuTap: () => Scaffold.of(innerContext).openDrawer(),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}