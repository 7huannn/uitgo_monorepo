import 'package:flutter/material.dart';
import 'package:rider_app/core/widgets/feature_placeholder.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ giúp & Hỗ trợ'),
      ),
      body: const FeaturePlaceholder(
        icon: Icons.help_outline,
        message:
            'Trung tâm hỗ trợ đang được chuẩn bị.\nBạn sẽ gửi phản hồi và xem FAQ tại đây.',
      ),
    );
  }
}
