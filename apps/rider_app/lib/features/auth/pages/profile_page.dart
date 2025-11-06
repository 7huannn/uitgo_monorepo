import 'package:flutter/material.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/features/auth/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  Map<String, String?> _userInfo = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final info = await _authService.getUserInfo();
    setState(() {
      _userInfo = info;
      _loading = false;
    });
  }

  Future<void> _onLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // Header với avatar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      _userInfo['name']?.substring(0, 1).toUpperCase() ?? 'U',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userInfo['name'] ?? 'User',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userInfo['email'] ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Thông tin tài khoản
            _buildSection(
              context,
              'Thông tin cá nhân',
              [
                _buildListTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Chỉnh sửa hồ sơ',
                  onTap: () {
                    // TODO: Navigate to edit profile
                  },
                ),
                _buildListTile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  onTap: () {
                    // TODO: Navigate to change password
                  },
                ),
              ],
            ),

            // Cài đặt
            _buildSection(
              context,
              'Cài đặt',
              [
                _buildListTile(
                  context,
                  icon: Icons.notifications_outlined,
                  title: 'Thông báo',
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
                _buildListTile(
                  context,
                  icon: Icons.language_outlined,
                  title: 'Ngôn ngữ',
                  trailing: const Text('Tiếng Việt'),
                  onTap: () {
                    // TODO: Navigate to language settings
                  },
                ),
                _buildListTile(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: 'Chế độ tối',
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      // TODO: Toggle dark mode
                    },
                  ),
                ),
              ],
            ),

            // Hỗ trợ
            _buildSection(
              context,
              'Hỗ trợ',
              [
                _buildListTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Trung tâm trợ giúp',
                  onTap: () {
                    // TODO: Navigate to help center
                  },
                ),
                _buildListTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Chính sách bảo mật',
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
                _buildListTile(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Điều khoản sử dụng',
                  onTap: () {
                    // TODO: Navigate to terms of service
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Nút đăng xuất
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: _onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Version
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Version 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}