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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final vehicle = profile!.vehicle;
    final theme = Theme.of(context);
    final availabilityColor = availability ? Colors.green : Colors.red;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    profile!.fullName.isNotEmpty
                        ? profile!.fullName.substring(0, 1).toUpperCase()
                        : '?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile!.fullName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star, size: 18, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            profile!.rating.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.phone_iphone,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            profile!.phone,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Chip(
                  backgroundColor: availabilityColor.withOpacity(0.1),
                  label: Text(
                    availability ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: availabilityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.badge,
              label: 'GPLX',
              value: profile!.licenseNumber,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.directions_car,
              label: 'Phương tiện',
              value: vehicle == null
                  ? 'Chưa cập nhật'
                  : '${vehicle.make} ${vehicle.model} - ${vehicle.color}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.local_offer,
              label: 'Biển số',
              value: vehicle?.plateNumber ?? 'Chưa cập nhật',
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile.adaptive(
                value: availability,
                onChanged: isLoading ? null : onToggle,
                title: Text(
                  availability ? 'Đang nhận chuyến' : 'Tạm dừng nhận chuyến',
                  style: TextStyle(
                    color: availabilityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Bật để cho điều phối viên biết bạn sẵn sàng nhận chuyến mới.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style:
              theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
