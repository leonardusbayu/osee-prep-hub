import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';

/// Partner Students page — Goal 2: institute sees its students roster.
class PartnerStudentsPage extends ConsumerStatefulWidget {
  const PartnerStudentsPage({super.key});

  @override
  ConsumerState<PartnerStudentsPage> createState() =>
      _PartnerStudentsPageState();
}

class _PartnerStudentsPageState extends ConsumerState<PartnerStudentsPage> {
  List<dynamic> _students = [];
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
      final res = await dio.get('/partner/students');
      setState(() {
        _students = (res.data['students'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load students';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: OseeTheme.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    style: FilledButton.styleFrom(
                      backgroundColor: OseeTheme.primary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Students',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: OseeTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_students.length} students across your institution',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ...(_students.map(
                  (s) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text(
                        (s['name'] as String?) ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['email'] as String? ?? ''),
                          if (s['classroom_name'] != null ||
                              s['teacher_name'] != null)
                            Text(
                              '${s['classroom_name'] ?? ''} • ${s['teacher_name'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )),
                if (_students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No students enrolled yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
