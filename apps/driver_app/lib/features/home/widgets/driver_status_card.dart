import 'package:flutter/material.dart';

import '../../driver/models/driver_models.dart';

class DriverStatusCard extends StatelessWidget {
  const DriverStatusCard({
    super.key,
    required this.profile,
    required this.isLoading,
    required this.onToggle,
  });

  final DriverProfile? profile;
  final bool isLoading;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Chưa có hồ sơ tài xế',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('Liên hệ điều phối viên để được tạo tài khoản tài xế.'),
            ],
          ),
        ),
      );
    }

    final availability = profile!.availability == DriverAvailability.online;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile!.fullName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Biển số: ${profile!.vehicle?.plateNumber ?? 'Chưa cập nhật'}',
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: availability,
              onChanged: isLoading ? null : onToggle,
              title: Text(
                availability ? 'Đang trực tuyến' : 'Ngoại tuyến',
                style: TextStyle(
                  color: availability ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Bật để nhận chuyến mới từ điều phối viên.'),
            ),
          ],
        ),
      ),
    );
  }
}
