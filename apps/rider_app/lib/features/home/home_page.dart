import 'package:flutter/material.dart';
import 'package:rider_app/app/router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _logout(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const Center(child: Text('Chào mừng đến UIT-Go! (Rider)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Đặt chuyến'),
        icon: const Icon(Icons.directions_car),
      ),
    );
  }
}
