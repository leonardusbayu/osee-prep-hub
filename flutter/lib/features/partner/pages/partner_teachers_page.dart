import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';

/// Partner Teachers page — Goal 2: institute manages its teachers.
class PartnerTeachersPage extends ConsumerStatefulWidget {
  const PartnerTeachersPage({super.key});

  @override
  ConsumerState<PartnerTeachersPage> createState() =>
      _PartnerTeachersPageState();
}

class _PartnerTeachersPageState extends ConsumerState<PartnerTeachersPage> {
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _error;
  final _inviteController = TextEditingController();
  bool _inviting = false;
  String? _inviteMsg;

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
      final res = await dio.get('/partner/teachers');
      setState(() {
        _teachers = (res.data['teachers'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load teachers';
        _isLoading = false;
      });
    }
  }

  Future<void> _invite() async {
    final email = _inviteController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _inviteMsg = 'Enter a valid email address');
      return;
    }
    setState(() {
      _inviting = true;
      _inviteMsg = null;
    });
    try {
      final dio = ApiClient.create();
      final res = await dio.post(
        '/partner/teachers/invite',
        data: {'email': email},
      );
      setState(() {
        _inviteMsg = (res.data['message'] as String?) ?? 'Invitation sent';
        _inviteController.clear();
      });
      _load();
    } catch (e) {
      setState(() => _inviteMsg = 'Invitation failed');
    } finally {
      setState(() => _inviting = false);
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
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Teachers',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: OseeTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage teachers in your institution',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_inviteMsg != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OseeTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _inviteMsg!,
                      style: TextStyle(color: OseeTheme.primary),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Invite section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invite a Teacher',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inviteController,
                                decoration: const InputDecoration(
                                  hintText: 'teacher@email.com',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _inviting ? null : _invite,
                              style: FilledButton.styleFrom(
                                backgroundColor: OseeTheme.primary,
                              ),
                              child: _inviting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Invite'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your Teachers (${_teachers.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...(_teachers.map(
                  (t) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        (t['name'] as String?) ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(t['email'] as String? ?? ''),
                      trailing: Text(
                        '${t['students_count'] ?? 0} students',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                )),
                if (_teachers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No teachers yet. Invite one above.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
