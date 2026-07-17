import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ui_components.dart';
import '../teacher_theme.dart';

/// Teacher dashboard — modern professional redesign.
class TeacherDashboardPage extends ConsumerStatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  ConsumerState<TeacherDashboardPage> createState() =>
      _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends ConsumerState<TeacherDashboardPage> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final response = await dio.get('/teacher/dashboard');
      setState(() {
        _stats = response.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingState()
        : _error != null
        ? ErrorState(message: _error!, onRetry: _loadDashboard)
        : RefreshIndicator(
            onRefresh: _loadDashboard,
            color: TeacherTheme.primaryBlue,
            child: _buildContent(),
          );
  }

  Widget _buildContent() {
    final stats = _stats ?? {};
    final user = stats['user'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(TeacherSpacing.lg),
      children: [
        Row(
          children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadDashboard,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        const SizedBox(height: TeacherSpacing.sm),
        _GreetingHeader(name: user['name'] as String?),
        const SizedBox(height: TeacherSpacing.lg),

        // Stats
        _SectionTitle(title: 'Overview'),
        const SizedBox(height: TeacherSpacing.md),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.statGridColumns(context),
          childAspectRatio: 1.4,
          crossAxisSpacing: TeacherSpacing.md,
          mainAxisSpacing: TeacherSpacing.md,
          children: [
            _StatCard(
              icon: Icons.groups_rounded,
              label: 'Students',
              value: '${stats['total_students'] ?? 0}',
              accent: TeacherTheme.successGreen,
            ),
            _StatCard(
              icon: Icons.class_rounded,
              label: 'Classrooms',
              value: '${stats['classrooms_count'] ?? 0}',
              accent: TeacherTheme.primaryBlue,
            ),
            _StatCard(
              icon: Icons.payments_rounded,
              label: 'Commission',
              value: 'Rp ${_formatNum(stats['commission_this_month'] ?? 0)}',
              accent: const Color(0xFFF0A030),
            ),
            _StatCard(
              icon: Icons.auto_awesome_rounded,
              label: 'AI Credits',
              value: '${stats['ai_quota_remaining'] ?? 0}',
              accent: const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: TeacherSpacing.lg + 8),

        // Quick actions
        _SectionTitle(title: 'Quick Actions'),
        const SizedBox(height: TeacherSpacing.md),
        _ActionGrid(),
        const SizedBox(height: TeacherSpacing.lg + 8),

        // Recent activity
        _SectionTitle(title: 'Recent Activity'),
        const SizedBox(height: TeacherSpacing.md),
        _ActivityList(activities: stats['recent_activity'] as List? ?? []),
      ],
    );
  }

  String _formatNum(dynamic n) {
    final i = int.tryParse('$n') ?? 0;
    if (i >= 1000000) return '${(i / 1000000).toStringAsFixed(1)}M';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(0)}k';
    return '$i';
  }
}

// ─── Section Title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: TeacherTheme.panelTitle());
  }
}

// ─── Greeting Header ─────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Good morning'
        : hour < 15
        ? 'Good afternoon'
        : 'Good evening';

    return Container(
      padding: const EdgeInsets.all(TeacherSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0177FB), Color(0xFF0155C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(TeacherTheme.radiusCard),
        boxShadow: [
          BoxShadow(
            color: TeacherTheme.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting 👋',
            style: TeacherTheme.caption(Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            name ?? 'Teacher',
            style: TeacherTheme.pageTitle(Colors.white).copyWith(fontSize: 24),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: TeacherTheme.animFast,
        padding: const EdgeInsets.all(TeacherSpacing.md),
        decoration: BoxDecoration(
          color: _hovering ? TeacherTheme.backgroundSecondary : TeacherTheme.surface,
          borderRadius: BorderRadius.circular(TeacherTheme.radiusCard),
          border: Border.all(
            color: _hovering ? widget.accent.withValues(alpha: 0.2) : TeacherTheme.divider,
          ),
          boxShadow: _hovering ? TeacherTheme.cardShadow : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(TeacherTheme.radiusBadge),
              ),
              child: Icon(widget.icon, size: 20, color: widget.accent),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.value,
                  style: TeacherTheme.pageTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(widget.label, style: TeacherTheme.caption()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Grid ─────────────────────────────────────────────────────────────

class _ActionGrid extends StatelessWidget {
  final _actions = [
    _Action(Icons.view_kanban_rounded, 'Syllabi', '/teacher/syllabi'),
    _Action(Icons.class_outlined, 'Classrooms', '/teacher/classrooms'),
    _Action(Icons.edit_note_rounded, 'AI Grader', '/teacher/ai-grader'),
    _Action(Icons.mic_rounded, 'Speaking', '/teacher/speaking-grader'),
    _Action(Icons.auto_awesome_outlined, 'Generator', '/teacher/generator'),
    _Action(Icons.shopping_cart_outlined, 'Orders', '/teacher/orders'),
    _Action(Icons.payments_outlined, 'Earnings', '/teacher/commission'),
    _Action(Icons.picture_as_pdf_outlined, 'Reports', '/teacher/reports'),
    _Action(Icons.star_rounded, 'Upgrade', '/teacher/upgrade'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TeacherSpacing.sm,
      runSpacing: TeacherSpacing.sm,
      children: _actions.map((a) => _ActionButton(action: a)).toList(),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final String route;
  const _Action(this.icon, this.label, this.route);
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.action});
  final _Action action;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => context.push(widget.action.route),
        child: AnimatedContainer(
          duration: TeacherTheme.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering
                ? TeacherTheme.primaryBlue.withValues(alpha: 0.08)
                : TeacherTheme.primaryBlueSoft,
            borderRadius: BorderRadius.circular(TeacherTheme.radiusButton),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.action.icon, size: 16, color: TeacherTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                widget.action.label,
                style: TeacherTheme.chipActive(TeacherTheme.primaryBlue)
                    .copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Activity List ───────────────────────────────────────────────────────────

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});
  final List activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(TeacherSpacing.lg),
        decoration: BoxDecoration(
          color: TeacherTheme.surface,
          borderRadius: BorderRadius.circular(TeacherTheme.radiusCard),
          border: Border.all(color: TeacherTheme.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.inbox_rounded, color: TeacherTheme.textMuted, size: 20),
            const SizedBox(width: TeacherSpacing.sm),
            Text('No recent activity yet', style: TeacherTheme.caption()),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: TeacherTheme.surface,
        borderRadius: BorderRadius.circular(TeacherTheme.radiusCard),
        border: Border.all(color: TeacherTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: activities.take(5).indexed.map((indexed) {
          final (i, activity) = indexed;
          final a = activity as Map<String, dynamic>;
          final status = a['status'] as String? ?? '';
          final isPaid = status == 'paid';
          final isLast = i == (activities.length.clamp(0, 5) - 1);

          return _ActivityTile(
            activity: a,
            isPaid: isPaid,
            showDivider: !isLast,
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityTile extends StatefulWidget {
  const _ActivityTile({
    required this.activity,
    required this.isPaid,
    required this.showDivider,
  });

  final Map<String, dynamic> activity;
  final bool isPaid;
  final bool showDivider;

  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final status = a['status'] as String? ?? '';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: TeacherTheme.animFast,
        color: _hovering ? TeacherTheme.hoverBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: TeacherSpacing.md,
          vertical: 12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (widget.isPaid
                            ? TeacherTheme.successGreen
                            : const Color(0xFFF0A030))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      TeacherTheme.radiusBadge,
                    ),
                  ),
                  child: Icon(
                    widget.isPaid
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    color: widget.isPaid
                        ? TeacherTheme.successGreen
                        : const Color(0xFFF0A030),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (a['action'] as String? ?? 'Event')
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((w) => w[0].toUpperCase() + w.substring(1))
                            .join(' '),
                        style: TeacherTheme.chipActive(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rp ${a['amount_idr'] ?? 0} · $status',
                        style: TeacherTheme.caption(),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(a['created_at'] as String?),
                  style: TeacherTheme.caption(TeacherTheme.textMuted),
                ),
              ],
            ),
            if (widget.showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Divider(
                  height: 1,
                  color: TeacherTheme.dividerSubtle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}';
  }
}
