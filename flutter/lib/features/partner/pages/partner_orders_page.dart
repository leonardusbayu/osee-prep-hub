import 'package:flutter/material.dart';

import '../../teacher/pages/order_page.dart';

/// Partner Orders page — Goal 3/9: institution can order official tests.
/// Reuses the existing OrderPage widget (it already supports partner role
/// via getPricingForRole on the backend).
class PartnerOrdersPage extends StatelessWidget {
  const PartnerOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrderPage();
  }
}
