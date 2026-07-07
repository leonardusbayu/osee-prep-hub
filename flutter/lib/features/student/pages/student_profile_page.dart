import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Student profile — magazine editorial style.
/// Shows student info, exam target, current level, and account settings.
class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({super.key});

  @override
  ConsumerState<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/auth/verify');
      setState(() {
        _profile = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: BorderSide(color: OseeTheme.cloud)),
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: OseeTheme.stone))),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); context.go('/login'); },
            style: FilledButton.styleFrom(backgroundColor: OseeTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = _profile?['user'] as Map<String, dynamic>?;
    final name = student?['display_name'] as String? ?? 'Student';
    final email = student?['email'] as String? ?? '—';
    final level = student?['current_level'] as String? ?? '—';
    final target = student?['target_exam'] as String? ?? '—';
    final initials = _extractInitials(name);

    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        title: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PROFILE', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.ink)),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
          ]),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                // Avatar card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: OseeTheme.ink, border: Border(top: BorderSide(color: OseeTheme.gold, width: 2))),
                  child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.gold, width: 3)),
                      child: Center(child: Text(initials, style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w700, color: OseeTheme.ink))),
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(height: 24),

                // Exam target
                const _SectionLabel('EXAM TARGET'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: OseeTheme.accent, width: 3), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud))),
                  child: Row(children: [
                    Icon(Icons.flag_outlined, size: 20, color: OseeTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Target Exam', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
                    Text(target.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                  ]),
                ),
                const SizedBox(height: 16),

                // CEFR Level
                const _SectionLabel('CEFR LEVEL'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: OseeTheme.gold, width: 3), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud))),
                  child: Row(children: [
                    Icon(Icons.bar_chart, size: 20, color: OseeTheme.gold),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Current Level', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
                    Text(level, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.gold)),
                  ]),
                ),
                const SizedBox(height: 24),

                // Settings
                const _SectionLabel('SETTINGS'),
                const SizedBox(height: 10),
                _SettingsRow(icon: Icons.language, label: 'Language', value: 'Bahasa Indonesia', onTap: () {}),
                const SizedBox(height: 6),
                _SettingsRow(icon: Icons.notifications_outlined, label: 'Notifications', value: 'On', onTap: () {}),
                const SizedBox(height: 24),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('SIGN OUT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    style: FilledButton.styleFrom(backgroundColor: OseeTheme.accent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(2),
    );
  }

  String _extractInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'S';
  }

  Widget _buildBottomNav(int selected) {
    final items = [
      {'label': 'Dashboard', 'icon': Icons.home_outlined, 'route': '/student', 'index': 0},
      {'label': 'Workbook', 'icon': Icons.menu_book_outlined, 'route': '/student/syllabus', 'index': 1},
      {'label': 'Profile', 'icon': Icons.person_outline, 'route': '/student/profile', 'index': 2},
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OseeTheme.ink, width: 2))),
      child: Row(
        children: items.map((item) {
          final isActive = item['index'] == selected;
          return Expanded(
            child: InkWell(
              onTap: () => context.go(item['route'] as String),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: isActive ? OseeTheme.accent : OseeTheme.stone),
                    const SizedBox(height: 2),
                    Text((item['label'] as String).toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: isActive ? OseeTheme.accent : OseeTheme.stone)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 1, color: OseeTheme.ink),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
    ]);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: OseeTheme.cloud), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud))),
        child: Row(children: [
          Icon(icon, size: 18, color: OseeTheme.ink),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
          Text(value, style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: OseeTheme.stone),
        ]),
      ),
    );
  }
}