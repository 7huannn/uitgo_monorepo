import 'package:flutter/material.dart';
import 'package:rider_app/core/widgets/feature_placeholder.dart';

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phương thức thanh toán'),
      ),
      body: const FeaturePlaceholder(
        icon: Icons.credit_card,
        message:
            'Tính năng đang được xây dựng.\nBạn sớm có thể quản lý thẻ và ví ở đây.',
      ),
    );
  }
}
