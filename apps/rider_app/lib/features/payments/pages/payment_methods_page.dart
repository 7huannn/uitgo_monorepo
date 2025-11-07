import 'package:flutter/material.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final List<_PaymentMethod> _methods = [
    _PaymentMethod(
      id: 'wallet',
      title: 'UITGo Wallet',
      subtitle: 'Số dư khả dụng cho mọi dịch vụ',
      icon: Icons.account_balance_wallet_outlined,
      isDefault: true,
    ),
    _PaymentMethod(
      id: 'visa',
      title: 'Visa **** 8821',
      subtitle: 'Hết hạn 06/27',
      icon: Icons.credit_card,
    ),
    _PaymentMethod(
      id: 'cash',
      title: 'Tiền mặt',
      subtitle: 'Thanh toán trực tiếp cho tài xế',
      icon: Icons.payments_outlined,
    ),
  ];

  bool _autoTopUp = true;

  void _setDefault(String id) {
    setState(() {
      for (final method in _methods) {
        method.isDefault = method.id == id;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã đặt ${_titleFor(id)} làm mặc định.')),
    );
  }

  String _titleFor(String id) => _methods
      .firstWhere((m) => m.id == id, orElse: () => _methods.first)
      .title;

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Chức năng quản lý thẻ sẽ sớm được cập nhật trong bản kế tiếp.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phương thức thanh toán'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComingSoon,
        icon: const Icon(Icons.add_card),
        label: const Text('Thêm thẻ'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text(
            'Mặc định',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._methods.map(_buildMethodTile),
          const SizedBox(height: 24),
          SwitchListTile.adaptive(
            value: _autoTopUp,
            onChanged: (value) {
              setState(() {
                _autoTopUp = value;
              });
            },
            title: const Text('Tự động nạp UITGo Wallet'),
            subtitle: const Text(
                'Tự động nạp thêm 100.000đ khi số dư xuống dưới 20.000đ.'),
          ),
          const SizedBox(height: 12),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Thanh toán an toàn'),
              subtitle: const Text(
                  'Mọi thẻ được mã hoá theo chuẩn PCI-DSS. Thông tin của bạn luôn an toàn.'),
              trailing: TextButton(
                onPressed: _showComingSoon,
                child: const Text('Tìm hiểu thêm'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile(_PaymentMethod method) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(method.icon, color: const Color(0xFF667EEA)),
        ),
        title: Text(
          method.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(method.subtitle),
        trailing: method.isDefault
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Mặc định',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            : TextButton(
                onPressed: () => _setDefault(method.id),
                child: const Text('Chọn'),
              ),
      ),
    );
  }
}

class _PaymentMethod {
  _PaymentMethod({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isDefault = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  bool isDefault;
}
