import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

/// Teacher settings + branding page — Task 15.1.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  final _logoUrlController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _customSubdomainController = TextEditingController();
  final _customCopyrightController = TextEditingController();
  bool _hideBranding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/branding');
      final d = r.data as Map<String, dynamic>;
      setState(() { _data = d; _isLoading = false; });
      final branding = d['branding'] as Map<String, dynamic>?;
      _logoUrlController.text = (branding?['logo_url'] as String?) ?? '';
      _primaryColorController.text = (branding?['primary_color'] as String?) ?? '#CCFF00';
      _customSubdomainController.text = (branding?['custom_subdomain'] as String?) ?? '';
      _customCopyrightController.text = (branding?['custom_copyright'] as String?) ?? '';
      _hideBranding = (branding?['hide_osee_branding'] as bool?) ?? false;
    } catch (e) {
      setState(() { _error = 'Failed to load settings'; _isLoading = false; });
    }
  }

  Future<void> _save() async {
    try {
      final dio = ApiClient.create();
      await dio.put('/branding', data: {
        'logo_url': _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
        'primary_color': _primaryColorController.text.trim(),
        'custom_subdomain': _customSubdomainController.text.trim().isEmpty ? null : _customSubdomainController.text.trim(),
        'custom_copyright': _customCopyrightController.text.trim().isEmpty ? null : _customCopyrightController.text.trim(),
        'hide_osee_branding': _hideBranding,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding saved')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text('You will revert to the free tier.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Sub')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ApiClient.create();
      await dio.post('/branding/cancel', data: {});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = (_data?['tier'] as Map<String, dynamic>?)?['tier'] as String? ?? 'free';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current tier: ${tier.toUpperCase()}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            if (_data?['tier'] != null)
                              ...((_data!['tier'] as Map)['features'] as List)
                                  .map((f) => ListTile(
                                        leading: const Icon(Icons.check, color: Colors.green),
                                        title: Text(f.toString()),
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      )),
                            if (tier != 'free')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancel subscription'),
                                  onPressed: _cancelSubscription,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Branding', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _logoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Logo URL',
                        helperText: 'Your custom logo (Pro/Institution tier only)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _primaryColorController,
                      decoration: const InputDecoration(
                        labelText: 'Primary color',
                        helperText: 'Hex color, e.g. #CCFF00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customSubdomainController,
                      decoration: const InputDecoration(
                        labelText: 'Custom subdomain',
                        helperText: 'Institution tier only',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customCopyrightController,
                      decoration: const InputDecoration(
                        labelText: 'Custom copyright text',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Hide OSEE branding'),
                      subtitle: const Text('Only available on Pro/Institution tier'),
                      value: _hideBranding,
                      onChanged: (v) => setState(() => _hideBranding = v),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _save, child: const Text('Save Branding')),
                  ],
                ),
    );
  }
}