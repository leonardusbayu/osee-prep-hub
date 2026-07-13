import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

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
  final Map<String, int> _cart = {};
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  String? _error;
  String? _assignedStudentId;
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = false;

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
      final data = response.data as Map<String, dynamic>?;
      setState(() {
        _pricing = data?['pricing'] as Map<String, dynamic>? ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pricing: $e';
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
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          PageHeader(
            title: _orderTypeTitle(orderType),
            subtitle: _orderTypeDescription(orderType),
            icon: _orderTypeIcon(orderType),
          ),
          const SizedBox(height: Spacing.lg),
          if (orderType == 'book_for_student') ...[
            SurfaceCard(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  const Icon(Icons.person, color: OseeTheme.primary),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      _assignedStudentId == null
                          ? 'No student assigned'
                          : 'Assigned: ${_students.firstWhere((s) => s['id'] == _assignedStudentId, orElse: () => {'display_name': 'Student'})['display_name']}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickStudent,
                    icon: const Icon(Icons.person_search, size: 18),
                    label: Text(
                      _assignedStudentId == null ? 'Pick' : 'Change',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],
          if (_cart.isNotEmpty) ...[
            _buildCartSummary(),
            const SizedBox(height: Spacing.lg),
          ],
          SectionHeader(title: 'Available Products'),
          _buildItemCard(
            'mock_itp',
            'Mock Test — ITP',
            'TOEFL ITP practice simulations',
            Icons.assignment,
          ),
          _buildItemCard(
            'mock_ibt',
            'Mock Test — iBT',
            'TOEFL iBT practice simulations',
            Icons.assignment,
          ),
          _buildItemCard(
            'mock_ielts',
            'Mock Test — IELTS',
            'IELTS practice simulations',
            Icons.assignment,
          ),
          _buildItemCard(
            'mock_toeic',
            'Mock Test — TOEIC',
            'TOEIC practice simulations',
            Icons.assignment,
          ),
          _buildItemCard(
            'tutor_bot_premium',
            'Tutor Bot Premium',
            'EduBot premium AI tutoring subscription',
            Icons.smart_toy,
          ),
          _buildItemCard(
            'official_toefl',
            'Official TOEFL Test',
            'ETS-certified TOEFL test at OSEE test center',
            Icons.verified,
          ),
          _buildItemCard(
            'official_toeic',
            'Official TOEIC Test',
            'ETS-certified TOEIC test at OSEE test center',
            Icons.verified,
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton.icon(
            onPressed: _pricing == null ||
                    _cart.isEmpty ||
                    _isPlacingOrder ||
                    (orderType == 'book_for_student' &&
                        _assignedStudentId == null)
                ? null
                : () => _showOrderSummary(context, orderType),
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              _isPlacingOrder ? 'Placing Order...' : 'Review & Place Order',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    String itemType,
    String name,
    String description,
    IconData icon,
  ) {
    final price = _pricing?[itemType];
    final formattedPrice = price is num
        ? 'Rp ${price.toStringAsFixed(0)} / unit'
        : 'Price not set';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: OseeTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: OseeTheme.primary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedPrice,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: OseeTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _cart[itemType] = (_cart[itemType] ?? 0) + 1;
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
    final entries = _cart.entries.toList();
    final total = entries.fold<int>(0, (sum, entry) {
      final price = _pricing?[entry.key];
      return sum + ((price is num ? price.toInt() : 0) * entry.value);
    });

    return SurfaceCard(
      color: OseeTheme.primary.withValues(alpha: 0.06),
      borderColor: OseeTheme.primary.withValues(alpha: 0.18),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_checkout),
                const SizedBox(width: 8),
                Text(
                  'Selected Items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _cart.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...entries.map((entry) {
              final price = _pricing?[entry.key];
              final subtotal = (price is num ? price.toInt() : 0) * entry.value;
              return Row(
                children: [
                  Expanded(child: Text(_itemLabel(entry.key))),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        final next = entry.value - 1;
                        if (next <= 0) {
                          _cart.remove(entry.key);
                        } else {
                          _cart[entry.key] = next;
                        }
                      });
                    },
                  ),
                  Text('${entry.value}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () =>
                        setState(() => _cart[entry.key] = entry.value + 1),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      _formatRupiah(subtotal),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _formatRupiah(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
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

  String _orderTypeTitle(String orderType) {
    switch (orderType) {
      case 'voucher_resale':
        return 'Voucher Resale';
      case 'bulk_purchase':
        return 'Bulk Purchase';
      case 'book_for_student':
        return 'Book for Student';
      case 'self_purchase':
        return 'Self Purchase';
      default:
        return 'Order';
    }
  }

  IconData _orderTypeIcon(String orderType) {
    switch (orderType) {
      case 'voucher_resale':
        return Icons.confirmation_number_rounded;
      case 'bulk_purchase':
        return Icons.inventory_2_rounded;
      case 'book_for_student':
        return Icons.event_available_rounded;
      case 'self_purchase':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.shopping_cart_rounded;
    }
  }

  static const _paymentMethods = [
    ('BCVA', 'Bank BCA'),
    ('BRIVA', 'BRI'),
    ('QRIS', 'QRIS'),
    ('OVO', 'OVO'),
    ('DANA', 'DANA'),
  ];

  Future<String?> _pickPaymentMethod() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in _paymentMethods)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(m.$2),
                  subtitle: Text(m.$1),
                  onTap: () => Navigator.pop(ctx, m.$1),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStudents() async {
    if (_isLoadingStudents || _students.isNotEmpty) return;
    setState(() => _isLoadingStudents = true);
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/teacher/classrooms');
      final classrooms = (r.data as Map)['classrooms'] as List? ?? [];
      final List<Map<String, dynamic>> all = [];
      for (final c in classrooms) {
        final students = (c as Map)['students'] as List? ?? [];
        for (final s in students) {
          final sm = s as Map<String, dynamic>;
          all.add({
            'id': sm['id'],
            'display_name': sm['display_name'] ?? '',
            'email': sm['email'] ?? '',
            'classroom_name': c['name'] ?? '',
          });
        }
      }
      setState(() {
        _students = all;
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _pickStudent() async {
    await _loadStudents();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Student'),
        content: SizedBox(
          width: 320,
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty
              ? const Text('No students found in your classrooms.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in _students)
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(s['display_name'] as String),
                        subtitle: Text(
                          '${s['email']} • ${s['classroom_name']}',
                        ),
                        onTap: () => Navigator.pop(ctx, s),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        _assignedStudentId = selected['id'] as String?;
      });
    }
  }

  Future<void> _showOrderSummary(BuildContext context, String orderType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_orderTypeDescription(orderType)),
            const SizedBox(height: 16),
            ..._cart.entries.map(
              (entry) => Text('${_itemLabel(entry.key)} x ${entry.value}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isPlacingOrder = true);
    try {
      final dio = ApiClient.create();
      final orderResponse = await dio.post(
        '/orders',
        data: {
          'order_type': orderType,
          'items': _cart.entries
              .map((entry) => {
                'item_type': entry.key,
                'quantity': entry.value,
                if (orderType == 'book_for_student' &&
                    _assignedStudentId != null)
                  'assigned_student_id': _assignedStudentId,
              })
              .toList(),
        },
      );
      final orderId = orderResponse.data['id'] as String;

      final paymentMethod = await _pickPaymentMethod();
      if (paymentMethod == null) {
        if (!mounted) return;
        setState(() => _isPlacingOrder = false);
        return;
      }

      final paymentResponse = await dio.post(
        '/orders/$orderId/pay',
        data: {'payment_method': paymentMethod},
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _isPlacingOrder = false;
      });
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order Created'),
          content: Text(
            'Payment ref: ${paymentResponse.data['payment_ref']}\n'
            'Amount: ${_formatRupiah((paymentResponse.data['amount'] as num).toInt())}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order failed: $e')));
    }
  }

  String _itemLabel(String itemType) {
    switch (itemType) {
      case 'mock_itp':
        return 'Mock Test — ITP';
      case 'mock_ibt':
        return 'Mock Test — iBT';
      case 'mock_ielts':
        return 'Mock Test — IELTS';
      case 'mock_toeic':
        return 'Mock Test — TOEIC';
      case 'tutor_bot_premium':
        return 'Tutor Bot Premium';
      case 'official_toefl':
        return 'Official TOEFL Test';
      case 'official_toeic':
        return 'Official TOEIC Test';
      default:
        return itemType;
    }
  }

  String _formatRupiah(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return 'Rp $buffer';
  }
}
