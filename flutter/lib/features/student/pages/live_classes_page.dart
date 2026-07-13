import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

/// Upcoming live classes page (student) — Task 14.2.
class LiveClassesPage extends StatefulWidget {
  const LiveClassesPage({super.key});

  @override
  State<LiveClassesPage> createState() => _LiveClassesPageState();
}

class _LiveClassesPageState extends State<LiveClassesPage> {
  List<dynamic>? _classes;
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
      final r = await dio.get('/classes/upcoming');
      setState(() {
        _classes = (r.data as Map)['classes'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  Future<void> _register(String classId) async {
    try {
      final dio = ApiClient.create();
      await dio.post('/classes/$classId/register', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered! You will get a reminder before class.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Classes'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_classes?.isEmpty ?? true)
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('No upcoming classes. Check back soon!'),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classes!.length,
                          itemBuilder: (ctx, i) {
                            final c = _classes![i] as Map<String, dynamic>;
                            final scheduled = c['scheduled_at'] as String?;
                            final status = c['status'] as String? ?? 'scheduled';
                            final color = status == 'live' ? Colors.red : status == 'completed' ? Colors.grey : Colors.blue;
                            return Card(
                              child: ListTile(
                                leading: Icon(Icons.videocam, color: color),
                                title: Text(c['title'] as String? ?? ''),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (c['description'] != null) Text(c['description'] as String),
                                    Text(scheduled != null
                                        ? DateTime.parse(scheduled).toLocal().toString()
                                        : ''),
                                    Text('Status: $status'),
                                  ],
                                ),
                                trailing: status == 'scheduled'
                                    ? FilledButton(
                                        onPressed: () => _register(c['id'] as String),
                                        child: const Text('Register'),
                                      )
                                    : null,
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}