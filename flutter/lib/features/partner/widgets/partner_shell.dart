import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../auth/providers/auth_provider.dart';

const _navItems = <_NavItem>[
  _NavItem(Icons.dashboard_rounded, 'Dashboard', '/partner'),
  _NavItem(Icons.groups_2_outlined, 'Teachers', '/partner/teachers'),
  _NavItem(Icons.people_alt_outlined, 'Students', '/partner/students'),
  _NavItem(Icons.shopping_cart_outlined, 'Orders', '/partner/orders'),
  _NavItem(Icons.payments_outlined, 'Commission', '/partner/commission'),
];

/// Persistent shell for all partner routes — rendered once by the router's
/// `StatefulShellRoute.indexedStack`. The sidebar stays mounted across
/// navigation; only the body (navigationShell) swaps.
class PartnerShell extends ConsumerStatefulWidget {
  const PartnerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends ConsumerState<PartnerShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final showSidebar = MediaQuery.sizeOf(context).width >= 900;
    final shellIndex = widget.navigationShell.currentIndex;
    final activeIdx = _navIndexFromShellIndex(shellIndex);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: showSidebar
          ? null
          : Drawer(
              width: 260,
              child: _Sidebar(
                activeIndex: activeIdx,
                onNavigate: () => _scaffoldKey.currentState?.closeDrawer(),
              ),
            ),
      body: showSidebar
          ? Row(
              children: [
                _Sidebar(activeIndex: activeIdx, onNavigate: () {}),
                Expanded(child: widget.navigationShell),
              ],
            )
          : widget.navigationShell,
    );
  }

  int _navIndexFromShellIndex(int shellIndex) {
    // The branch order in the router matches _navItems order (0..4).
    if (shellIndex < _navItems.length) return shellIndex;
    // Sub-routes (e.g. /partner/teachers/:id) fall back to the nearest parent nav.
    final location = GoRouterState.of(context).uri.path;
    for (var i = _navItems.length - 1; i >= 0; i--) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.activeIndex, required this.onNavigate});
  final int activeIndex;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Container(
      width: 260,
      color: const Color(0xFF0A0A0A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OSEE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.teacherInstitution ?? 'Institution',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final active = i == activeIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: Material(
                  color: active
                      ? OseeTheme.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.go(item.route);
                      onNavigate();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: active
                                ? OseeTheme.primary
                                : const Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Text(
                user?.displayName ?? '—',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}
