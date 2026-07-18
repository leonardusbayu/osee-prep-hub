import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Upcoming live classes page (student) — Modernized UI.
class LiveClassesPage extends ConsumerStatefulWidget {
  const LiveClassesPage({super.key});

  @override
  ConsumerState<LiveClassesPage> createState() => _LiveClassesPageState();
}

class _LiveClassesPageState extends ConsumerState<LiveClassesPage> {
  List<dynamic>? _classes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/classes/upcoming');
      setState(() {
        _classes = (r.data as Map)['classes'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  Future<void> _register(String classId) async {
    try {
      final dio = ApiClient.create();
      await dio.post('/classes/$classId/register', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.successGreen,
            content: Text('Registered! You will get a reminder before class.', style: StudentTheme.cardLabel(Colors.white)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.danger,
            content: Text('Failed: $e', style: StudentTheme.cardLabel(Colors.white)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: StudentTheme.primary))
        : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: StudentTheme.cardLabel(StudentTheme.textSecondary)),
                    const SizedBox(height: StudentSpacing.lg),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _buildContent(isDesktop);
  }

  Widget _buildContent(bool isDesktop) {
    final isEmpty = _classes?.isEmpty ?? true;

    return RefreshIndicator(
      onRefresh: _load,
      color: StudentTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(StudentSpacing.xl),
        children: [
          StudentTopBar(
            name: 'Student',
            subtitle: 'Live Classes',
            onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(height: StudentSpacing.xxl),
          
          if (isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: StudentSpacing.xl),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StudentTheme.surface,
                borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
                boxShadow: StudentTheme.cardShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded, size: 64, color: StudentTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: StudentSpacing.lg),
                  Text('No upcoming classes', style: StudentTheme.courseTitle()),
                  const SizedBox(height: 8),
                  Text('Check back soon for new live sessions.', style: StudentTheme.cardLabel(), textAlign: TextAlign.center),
                ],
              ),
            )
          else ...[
            const StudentSectionHeader(
              title: 'Schedule',
              icon: Icons.calendar_month_rounded,
            ),
            const SizedBox(height: StudentSpacing.lg),
            for (final cData in _classes!) ...[
              _buildClassCard(cData as Map<String, dynamic>),
              const SizedBox(height: StudentSpacing.md),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c) {
    final scheduled = c['scheduled_at'] as String?;
    final status = c['status'] as String? ?? 'scheduled';
    final isLive = status == 'live';
    final isCompleted = status == 'completed';
    
    final color = isLive ? StudentTheme.danger : isCompleted ? StudentTheme.textSecondary : StudentTheme.primary;
    final bg = isLive ? StudentTheme.danger.withValues(alpha: 0.1) : isCompleted ? StudentTheme.background : StudentTheme.primarySurface;

    String dateStr = '';
    if (scheduled != null) {
      final dt = DateTime.tryParse(scheduled)?.toLocal();
      if (dt != null) {
        dateStr = DateFormat('MMM d, y · h:mm a').format(dt);
      }
    }

    return Container(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      decoration: BoxDecoration(
        color: StudentTheme.surface,
        borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
        boxShadow: StudentTheme.cardShadow,
        border: Border.all(color: isLive ? StudentTheme.danger.withValues(alpha: 0.3) : StudentTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.videocam_rounded, color: color, size: 28),
          ),
          const SizedBox(width: StudentSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c['title'] as String? ?? 'Untitled Class',
                        style: StudentTheme.courseTitle().copyWith(fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (c['description'] != null) ...[
                  Text(
                    c['description'] as String,
                    style: StudentTheme.noticeBody(),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: StudentTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(dateStr, style: StudentTheme.cardLabel()),
                  ],
                ),
                if (status == 'scheduled') ...[
                  const SizedBox(height: StudentSpacing.lg),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => _register(c['id'] as String),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StudentTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudentTheme.radiusButton)),
                      ),
                      child: const Text('Register for Class'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
