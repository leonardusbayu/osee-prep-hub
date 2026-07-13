import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// Upgrade to Pro / Institution tier page — Task 15.2, 15.3.
class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _upgrade(String tier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Upgrade to $tier?'),
        content: Text(
          tier == 'pro'
              ? 'Rp 50,000/month — Unlimited AI grading, generation, classroom reports, hide OSEE branding.'
              : 'Rp 350,000/month — Everything in Pro + custom subdomain + multi-teacher + admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      await dio.post(
        '/branding/upgrade',
        data: {'tier': tier, 'payment_reference': 'manual'},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upgraded to $tier! 🎉')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = 'Upgrade failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: _isLoading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ),
                _TierCard(
                  title: 'Pro',
                  price: 'Rp 50,000 / month',
                  features: const [
                    'Unlimited AI grading',
                    'Unlimited AI generation',
                    'Classroom reports + PDF',
                    'Hide OSEE branding',
                    'Priority support',
                  ],
                  color: Colors.blue,
                  onTap: () => _upgrade('pro'),
                ),
                const SizedBox(height: 16),
                _TierCard(
                  title: 'Institution',
                  price: 'Rp 350,000 / month',
                  features: const [
                    'Everything in Pro',
                    'Custom subdomain',
                    'Multi-teacher accounts',
                    'School admin dashboard',
                    'Full white-label',
                  ],
                  color: Colors.purple,
                  onTap: () => _upgrade('institution'),
                ),
              ],
            ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.price,
    required this.features,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String price;
  final List<String> features;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              for (final f in features)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.upgrade),
                  label: Text('Upgrade to $title'),
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
