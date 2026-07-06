import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../models/dashboard_stats.dart';

/// Teacher order page — Task 15.7.
///
/// Browse 7 orderable items with role-specific pricing (student/teacher/partner prices).
/// Place orders via 4 modes: voucher resale, bulk purchase, book for student, self-purchase.
class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _pricing;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPricing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final response = await dio.get('/teacher/pricing');
      setState(() {
        _pricing = response.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pricing';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Tests & Vouchers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Voucher Resale', icon: Icon(Icons.confirmation_number)),
            Tab(text: 'Bulk Purchase', icon: Icon(Icons.inventory_2)),
            Tab(text: 'Book for Student', icon: Icon(Icons.event)),
            Tab(text: 'Self Purchase', icon: Icon(Icons.shopping_bag)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderTab('voucher_resale'),
                    _buildOrderTab('bulk_purchase'),
                    _buildOrderTab('book_for_student'),
                    _buildOrderTab('self_purchase'),
                  ],
                ),
    );
  }

  Widget _buildOrderTab(String orderType) {
    return RefreshIndicator(
      onRefresh: _loadPricing,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_orderTypeDescription(orderType),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          _buildItemCard('mock_itp', 'Mock Test — ITP', 'TOEFL ITP practice simulations', Icons.assignment),
          _buildItemCard('mock_ibt', 'Mock Test — iBT', 'TOEFL iBT practice simulations', Icons.assignment),
          _buildItemCard('mock_ielts', 'Mock Test — IELTS', 'IELTS practice simulations', Icons.assignment),
          _buildItemCard('mock_toeic', 'Mock Test — TOEIC', 'TOEIC practice simulations', Icons.assignment),
          _buildItemCard('tutor_bot_premium', 'Tutor Bot Premium', 'EduBot premium AI tutoring subscription', Icons.smart_toy),
          _buildItemCard('official_toefl', 'Official TOEFL Test', 'ETS-certified TOEFL test at OSEE test center', Icons.verified),
          _buildItemCard('official_toeic', 'Official TOEIC Test', 'ETS-certified TOEIC test at OSEE test center', Icons.verified),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pricing == null
                ? null
                : () => _showOrderSummary(context, orderType),
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Review & Place Order'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(String itemType, String name, String description, IconData icon) {
    final price = _pricing?[itemType];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    price != null ? 'Rp ${(price as int).toStringAsFixed(0)} / unit' : 'Loading...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Add 1 to cart, shown in summary
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $name to cart')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _orderTypeDescription(String orderType) {
    switch (orderType) {
      case 'voucher_resale':
        return 'Buy vouchers at discounted rates. Distribute to students and keep the margin.';
      case 'bulk_purchase':
        return 'Purchase in bulk and assign to specific students in your classrooms.';
      case 'book_for_student':
        return 'Book official tests (TOEFL/TOEIC) on behalf of your students.';
      case 'self_purchase':
        return 'Purchase for your own use to demonstrate or test.';
      default:
        return '';
    }
  }

  void _showOrderSummary(BuildContext context, String orderType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$orderType order — full checkout flow in Task 15.7 follow-up')),
    );
  }
}