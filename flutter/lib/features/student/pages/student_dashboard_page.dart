import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/responsive.dart';
import '../../auth/providers/auth_provider.dart';

/// Student dashboard page — Task 11.1.
class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/student/dashboard');
      setState(() { _dashboard = r.data as Map<String, dynamic>?; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Learning'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(onRefresh: _load, child: _buildContent(_dashboard ?? {})),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final progress = d['progress'] as Map<String, dynamic>? ?? {};
    final classrooms = d['classrooms'] as List? ?? [];
    final readiness = d['readiness'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReadinessCard(readiness: readiness),
        const SizedBox(height: 16),
        Text('Recent Progress', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
          _ProgressCard(progress: progress),
          const SizedBox(height: 16),
          // Quick navigation grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: Responsive.statGridColumns(context),
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _NavTile(Icons.trending_up, 'Progress', '/student/progress'),
              _NavTile(Icons.verified, 'Readiness', '/student/readiness'),
              _NavTile(Icons.video_library, 'Videos', '/student/videos'),
              _NavTile(Icons.videocam, 'Live Class', '/student/classes'),
              _NavTile(Icons.compare_arrows, 'Cross-Exam', '/student/cross-exam'),
              _NavTile(Icons.event, 'Book Test', '/student/book-test'),
            ],
          ),
          const SizedBox(height: 16),
          Text('My Classes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (classrooms.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No classes yet — join one with a code from your teacher',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
        else
          ...classrooms.map((c) => Card(
                child: ListTile(
                  leading: const Icon(Icons.class_),
                  title: Text((c as Map<String, dynamic>)['name'] as String? ?? ''),
                  subtitle: Text('Teacher: ${c['teacher_name'] as String? ?? ''}'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              )),
        if (readiness > 80) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade100,
            child: ListTile(
              leading: const Icon(Icons.verified, color: Colors.green, size: 32),
              title: const Text('Ready for the official test?'),
              subtitle: const Text('Book your TOEFL or TOEIC at OSEE test center'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/student/book-test'),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness});
  final int readiness;

  @override
  Widget build(BuildContext context) {
    final color = readiness > 80
        ? Colors.green
        : readiness > 50
            ? Colors.orange
            : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Readiness', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('$readiness%',
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: readiness / 100,
              minHeight: 12,
              color: color,
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final Map<String, dynamic> progress;

  @override
  Widget build(BuildContext context) {
    final ibt = progress['ibt_latest_score'] as int?;
    final itp = progress['itp_latest_score'] as int?;
    final ielts = progress['ielts_latest_band'] as num?;
    final toeic = progress['toeic_latest_score'] as int?;
    final count = progress['total_practice_count'] as int? ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count total practice sessions', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            _row('TOEFL iBT', ibt?.toString() ?? '—'),
            _row('TOEFL ITP', itp?.toString() ?? '—'),
            _row('IELTS band', ielts?.toString() ?? '—'),
            _row('TOEIC', toeic?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}