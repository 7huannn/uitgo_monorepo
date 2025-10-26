import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Splash/Welcome hiển thị khi mở app.
/// - Luôn hiện animation.
/// - Khi animation xong: nếu đã đăng nhập -> /home, chưa đăng nhập -> /login.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  bool _navigated = false; // ngăn điều hướng 2 lần nếu hot-reload

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    // Khi animation hoàn tất -> điều hướng.
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        _goNext();
      }
    });
  }

  Future<void> _goNext() async {
    // TODO: thay bằng AuthService thật của bạn.
    final loggedIn = await _fakeIsLoggedIn();

    if (!mounted) return;
    if (loggedIn) {
      // vào thẳng Home, không cho back về Welcome
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // Mock check đăng nhập – thay bằng storage/secure storage của bạn.
  Future<bool> _fakeIsLoggedIn() async {
    await Future.delayed(const Duration(milliseconds: 200)); // giả lập I/O
    return false; // chỉnh true để test case đã đăng nhập
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: Lottie.asset(
          'assets/Welcome.json',
          controller: _c,
          width: 300,
          height: 150,
          fit: BoxFit.contain,
          onLoaded: (comp) {
            debugPrint(
              '✅ Lottie loaded, duration = ${comp.duration.inMilliseconds} ms',
            );
            _c
              ..duration = comp.duration
              ..forward(from: 0);
          },
          errorBuilder: (context, error, stack) {
            debugPrint('❌ Lottie error: $error');
            // Nếu lỗi asset, chờ 800ms rồi điều hướng luôn để không kẹt ở đây
            Future.microtask(() async {
              await Future.delayed(const Duration(milliseconds: 800));
              if (!_navigated) {
                _navigated = true;
                _goNext();
              }
            });
            return const Text(
              'Không tải được assets/Welcome.json',
              style: TextStyle(color: Colors.red),
            );
          },
        ),
      ),
    );
  }
}
