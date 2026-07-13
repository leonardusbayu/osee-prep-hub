import 'package:flutter/material.dart';
import 'dart:js' as js;

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// Book official test page — Task 11.6.
class BookTestPage extends StatefulWidget {
  const BookTestPage({super.key});

  @override
  State<BookTestPage> createState() => _BookTestPageState();
}

class _BookTestPageState extends State<BookTestPage> {
  Map<String, dynamic>? _data;
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
      final r = await dio.get('/student/book-test');
      setState(() { _data = r.data as Map<String, dynamic>; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  void _openBooking() {
    final url = _data?['osee_booking_url'] as String? ?? 'https://osee.co.id';
    // Open in new browser tab via dart:js (no extra package needed for Flutter Web).
    try {
      js.context.callMethod('open', [url, '_blank']);
    } catch (_) {
      // Fallback for non-web platforms — just show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open $url in your browser')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _data?['ready_to_book'] as bool? ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Book Official Test'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: ready ? Colors.green.shade50 : Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              ready ? Icons.verified : Icons.hourglass_top,
                              size: 64,
                              color: ready ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              ready ? 'You are ready to book!' : 'Not yet ready',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(_data?['note'] as String? ?? ''),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (ready) ...[
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.event, size: 36),
                          title: const Text('Book Official Test'),
                          subtitle: const Text('OSEE is an official ETS test center since 2014.'),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: _openBooking,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if ((_data?['available_dates'] as List?)?.isNotEmpty ?? false)
                        const Text('Available Dates',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      for (final d in (_data?['available_dates'] as List?) ?? <dynamic>[])
                        Card(
                          child: ListTile(
                            title: Text(d.toString()),
                            trailing: FilledButton(
                              onPressed: _openBooking,
                              child: const Text('Book'),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}