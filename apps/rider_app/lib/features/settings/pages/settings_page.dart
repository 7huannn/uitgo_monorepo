import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _rideUpdatesEnabled = true;
  bool _biometricLogin = false;

  void _showTodo(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature sẽ sớm được bổ sung.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Thông báo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _notificationsEnabled,
            title: const Text('Nhận thông báo khuyến mãi'),
            subtitle: const Text('Gửi ưu đãi tốt nhất đến bạn qua push/email.'),
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
          ),
          SwitchListTile.adaptive(
            value: _rideUpdatesEnabled,
            title: const Text('Thông báo tiến trình chuyến đi'),
            subtitle:
                const Text('Cập nhật khi tài xế nhận chuyến hoặc hoàn tất.'),
            onChanged: (value) {
              setState(() => _rideUpdatesEnabled = value);
            },
          ),
          const SizedBox(height: 24),
          const Text('Bảo mật',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _biometricLogin,
            title: const Text('Đăng nhập sinh trắc học'),
            subtitle: const Text('Mở UITGo nhanh bằng Face ID/Touch ID.'),
            onChanged: (value) {
              setState(() => _biometricLogin = value);
              _showTodo('Sinh trắc học');
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Đổi mật khẩu'),
            subtitle: const Text('Thiết lập lại mật khẩu UITGo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTodo('Đổi mật khẩu'),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Quyền riêng tư'),
            subtitle: const Text('Điều chỉnh dữ liệu chia sẻ với tài xế'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTodo('Quyền riêng tư'),
          ),
          const SizedBox(height: 24),
          const Text('Khác',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Điều khoản sử dụng'),
            onTap: () => _showTodo('Điều khoản sử dụng'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Phiên bản ứng dụng'),
            subtitle: Text('0.3.0-dev'),
          ),
        ],
      ),
    );
  }
}
