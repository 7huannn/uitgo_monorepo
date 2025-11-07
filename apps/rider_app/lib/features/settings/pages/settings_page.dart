import 'package:flutter/material.dart';
import 'package:rider_app/core/widgets/feature_placeholder.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: const FeaturePlaceholder(
        icon: Icons.settings_outlined,
        message:
            'Màn hình cài đặt chung đang được phát triển.\nBạn sẽ quản lý thông báo và bảo mật tại đây.',
      ),
    );
  }
}
