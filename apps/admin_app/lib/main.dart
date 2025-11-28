import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/models.dart';
import 'core/ws_client.dart';

void main() {
  runApp(const UITGoAdminApp());
}

class UITGoAdminApp extends StatelessWidget {
  const UITGoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UIT-Go Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late ApiClient _client;
  final _apiController = TextEditingController(text: 'http://localhost:8080');
  final _loginEmail = TextEditingController(text: 'admin@example.com');
  final _loginPassword = TextEditingController(text: 'admin123');
  final _registerName = TextEditingController(text: 'UIT Rider');
  final _registerEmail = TextEditingController(text: 'rider@example.com');
  final _registerPhone = TextEditingController(text: '0900000000');
  final _registerPassword = TextEditingController(text: '123456');
  final _driverLicense = TextEditingController(text: 'A1-123456');
  final _vehicleMake = TextEditingController(text: 'Honda');
  final _vehicleModel = TextEditingController(text: 'Wave');
  final _vehicleColor = TextEditingController(text: 'Blue');
  final _vehiclePlate = TextEditingController(text: '59A1-00000');
  final _origin = TextEditingController(text: 'UIT Campus');
  final _destination = TextEditingController(text: 'Dormitory');
  final _service = TextEditingController(text: 'UIT-Bike');
  final _originLat = TextEditingController();
  final _originLng = TextEditingController();
  final _destLat = TextEditingController();
  final _destLng = TextEditingController();
  final _tripId = TextEditingController();
  final _assignDriverId = TextEditingController();
  final _wsTripId = TextEditingController();
  final _wsUserId = TextEditingController(text: 'demo-rider');
  final _wsLat = TextEditingController(text: '10.8705');
  final _wsLng = TextEditingController(text: '106.8032');
  final _userSearch = TextEditingController();

  String _apiBase = 'http://localhost:8080';
  String _authToken = '';
  UserProfile? _me;
  UserProfile? _adminMe;
  TripDetail? _trip;
  List<UserProfile> _users = [];
  int _usersTotal = 0;
  String _userRoleFilter = 'all';
  String _userDisabledFilter = 'all';
  int _userLimit = 20;
  int _userOffset = 0;
  List<Promotion> _promotions = [];
  final _promoTitle = TextEditingController();
  final _promoDesc = TextEditingController();
  final _promoCode = TextEditingController();
  final _promoGradientStart = TextEditingController(text: '#0FB7A0');
  final _promoGradientEnd = TextEditingController(text: '#1E9FD7');
  final _promoImageUrl = TextEditingController();
  final _promoExpires = TextEditingController();
  final _promoPriority = TextEditingController(text: '0');
  bool _healthOk = false;
  bool _busy = false;
  bool _wsConnecting = false;
  TripWsClient? _wsClient;
  String _wsRole = 'rider';
  final List<String> _logs = [];
  final List<String> _wsLogs = [];

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: _apiBase);
    _restorePrefs();
  }

  @override
  void dispose() {
    _apiController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPhone.dispose();
    _registerPassword.dispose();
    _driverLicense.dispose();
    _vehicleMake.dispose();
    _vehicleModel.dispose();
    _vehicleColor.dispose();
    _vehiclePlate.dispose();
    _origin.dispose();
    _destination.dispose();
    _service.dispose();
    _originLat.dispose();
    _originLng.dispose();
    _destLat.dispose();
    _destLng.dispose();
    _tripId.dispose();
    _assignDriverId.dispose();
    _wsTripId.dispose();
    _wsUserId.dispose();
    _wsLat.dispose();
    _wsLng.dispose();
    _userSearch.dispose();
    _promoTitle.dispose();
    _promoDesc.dispose();
    _promoCode.dispose();
    _promoGradientStart.dispose();
    _promoGradientEnd.dispose();
    _promoImageUrl.dispose();
    _promoExpires.dispose();
    _promoPriority.dispose();
    _wsClient?.disconnect();
    super.dispose();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getString('admin_api_base');
    final savedEmail = prefs.getString('admin_email');
    final savedToken = prefs.getString('admin_token');
    if (savedBase != null && savedBase.isNotEmpty) {
      _apiBase = savedBase;
      _apiController.text = savedBase;
      _client.baseUrl = savedBase;
    }
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _loginEmail.text = savedEmail;
    }
    if (savedToken != null && savedToken.isNotEmpty) {
      _setToken(savedToken, persist: false);
      unawaited(_loadProfile());
    }
    setState(() {});
  }

  void _setToken(String token, {bool persist = true}) async {
    _authToken = token;
    _client.accessToken = token;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', token);
    }
  }

  void _log(String message) {
    final ts = TimeOfDay.now().format(context);
    setState(() {
      _logs.insert(0, '[$ts] $message');
      if (_logs.length > 400) {
        _logs.removeRange(300, _logs.length);
      }
    });
  }

  void _logWs(String message) {
    final ts = TimeOfDay.now().format(context);
    setState(() {
      _wsLogs.insert(0, '[$ts] $message');
      if (_wsLogs.length > 400) {
        _wsLogs.removeRange(300, _wsLogs.length);
      }
    });
  }

  Future<void> _saveApiBase() async {
    final base = _apiController.text.trim();
    if (base.isEmpty) return;
    setState(() => _apiBase = base);
    _client.baseUrl = base;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_api_base', base);
    _log('API base set to $base');
  }

  Future<void> _pingHealth() async {
    setState(() => _busy = true);
    try {
      final ok = await _client.pingHealth();
      setState(() => _healthOk = ok);
      _log(ok ? 'Health OK' : 'Health failed');
    } catch (e) {
      _log('Health error: $e');
      setState(() => _healthOk = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      final session =
          await _client.login(_loginEmail.text, _loginPassword.text);
      _setToken(session.accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_email', _loginEmail.text.trim());
      _log('Logged in as ${session.email} (${session.role})');
      await _loadProfile();
      await _loadUsers();
      await _loadPromotions();
    } catch (e) {
      _log('Login failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerRider() async {
    setState(() => _busy = true);
    try {
      final session = await _client.registerUser(
        name: _registerName.text,
        email: _registerEmail.text,
        phone: _registerPhone.text,
        password: _registerPassword.text,
      );
      _log('Registered rider ${session.email}');
    } catch (e) {
      _log('Register rider failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerDriver() async {
    setState(() => _busy = true);
    try {
      final session = await _client.registerDriver(
        name: _registerName.text,
        email: _registerEmail.text,
        phone: _registerPhone.text,
        password: _registerPassword.text,
        licenseNumber: _driverLicense.text,
        vehicleMake: _vehicleMake.text,
        vehicleModel: _vehicleModel.text,
        vehicleColor: _vehicleColor.text,
        plate: _vehiclePlate.text,
      );
      _log('Registered driver ${session.email}');
    } catch (e) {
      _log('Register driver failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadProfile() async {
    if (_authToken.isEmpty) return;
    try {
      final me = await _client.me();
      final adminMe = await _client.adminMe();
      setState(() {
        _me = me;
        _adminMe = adminMe;
      });
      _log('Profile loaded: ${me.email} (${me.role})');
    } catch (e) {
      _log('Fetch profile failed: $e');
    }
  }

  Future<void> _logout() async {
    _setToken('', persist: true);
    setState(() {
      _me = null;
      _adminMe = null;
      _trip = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    _log('Logged out');
  }

  Future<void> _createTrip() async {
    if (_authToken.isEmpty) {
      _log('Login required before creating trip');
      return;
    }
    setState(() => _busy = true);
    try {
      final trip = await _client.createTrip(
        originText: _origin.text,
        destText: _destination.text,
        serviceId: _service.text,
        originLat: _parseDouble(_originLat.text),
        originLng: _parseDouble(_originLng.text),
        destLat: _parseDouble(_destLat.text),
        destLng: _parseDouble(_destLng.text),
      );
      setState(() {
        _trip = trip;
        _tripId.text = trip.id;
        _wsTripId.text = trip.id;
      });
      _log('Created trip ${trip.id}');
    } catch (e) {
      _log('Create trip failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchTrip() async {
    final id = _tripId.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final trip = await _client.fetchTrip(id);
      setState(() => _trip = trip);
      _log('Fetched trip $id (${trip.status})');
    } catch (e) {
      _log('Fetch trip failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final id = _tripId.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _client.updateTripStatus(id, status);
      _log('Updated status to $status');
      await _fetchTrip();
    } catch (e) {
      _log('Update status failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignDriver() async {
    final id = _tripId.text.trim();
    final driverId = _assignDriverId.text.trim();
    if (id.isEmpty || driverId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _client.assignDriver(id, driverId);
      _log('Assigned driver $driverId');
      await _fetchTrip();
    } catch (e) {
      _log('Assign driver failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _busy = true);
    try {
      final page = await _client.listUsers(
        role: _userRoleFilter,
        disabled: _userDisabledFilter,
        q: _userSearch.text,
        limit: _userLimit,
        offset: _userOffset,
      );
      setState(() {
        _users = page.items;
        _usersTotal = page.total;
      });
      _log('Loaded ${page.items.length}/${page.total} users');
    } catch (e) {
      _log('Load users failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPromotions() async {
    setState(() => _busy = true);
    try {
      final items = await _client.listPromotions();
      setState(() => _promotions = items);
      _log('Loaded ${items.length} promotions');
    } catch (e) {
      _log('Load promotions failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPromotion() async {
    setState(() => _busy = true);
    try {
      final priority = int.tryParse(_promoPriority.text.trim()) ?? 0;
      final created = await _client.createPromotion(
        title: _promoTitle.text,
        description: _promoDesc.text,
        code: _promoCode.text,
        gradientStart: _promoGradientStart.text,
        gradientEnd: _promoGradientEnd.text,
        imageUrl: _promoImageUrl.text.isEmpty ? null : _promoImageUrl.text,
        expiresAtRfc3339:
            _promoExpires.text.isEmpty ? null : _promoExpires.text,
        priority: priority,
      );
      _log('Created promotion ${created.code}');
      _promoTitle.clear();
      _promoDesc.clear();
      _promoCode.clear();
      _promoImageUrl.clear();
      _promoExpires.clear();
      _promoPriority.text = '0';
      await _loadPromotions();
    } catch (e) {
      _log('Create promotion failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePromotion(String id) async {
    setState(() => _busy = true);
    try {
      await _client.deletePromotion(id);
      _log('Deleted promotion $id');
      await _loadPromotions();
    } catch (e) {
      _log('Delete promotion failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateUserRole(UserProfile user, String role) async {
    setState(() => _busy = true);
    try {
      final updated =
          await _client.updateUser(userId: user.id, role: role, disabled: null);
      _log('Updated role ${user.email} -> ${updated.role}');
      await _loadUsers();
    } catch (e) {
      _log('Update role failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleUserDisabled(UserProfile user, bool disabled) async {
    setState(() => _busy = true);
    try {
      final updated = await _client.updateUser(
        userId: user.id,
        disabled: disabled,
      );
      _log('${disabled ? 'Disabled' : 'Enabled'} ${updated.email}');
      await _loadUsers();
    } catch (e) {
      _log('Update user failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectWs() async {
    final id = _wsTripId.text.trim();
    if (id.isEmpty || _authToken.isEmpty) {
      _logWs('Trip ID and login required for WS');
      return;
    }
    setState(() => _wsConnecting = true);
    final client = TripWsClient(
      baseUrl: _apiBase,
      tripId: id,
      role: _wsRole,
      accessToken: _authToken,
      userIdOverride:
          _wsUserId.text.trim().isEmpty ? null : _wsUserId.text.trim(),
    );
    try {
      await client.connect(
        onMessage: (data) => _logWs('← $data'),
        onError: (error) => _logWs('WS error: $error'),
        onDone: () => _logWs('WS disconnected'),
      );
      setState(() => _wsClient = client);
      _logWs('Connected WS as $_wsRole');
    } catch (e) {
      _logWs('WS connect failed: $e');
    } finally {
      if (mounted) setState(() => _wsConnecting = false);
    }
  }

  Future<void> _disconnectWs() async {
    await _wsClient?.disconnect();
    setState(() => _wsClient = null);
    _logWs('WS disconnected');
  }

  void _sendWsStatus(String status) {
    final client = _wsClient;
    if (client == null) return;
    client.sendStatus(status);
    _logWs('→ status $status');
  }

  void _sendWsLocation() {
    final client = _wsClient;
    if (client == null) return;
    final lat = _parseDouble(_wsLat.text) ?? 0;
    final lng = _parseDouble(_wsLng.text) ?? 0;
    client.sendLocation(lat, lng);
    _logWs('→ location $lat,$lng');
  }

  double? _parseDouble(String input) {
    final value = double.tryParse(input.trim());
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 1260 ? 1260.0 : width - 24;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UIT-Go Admin'),
          actions: [
            if (_healthOk)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: Icon(Icons.health_and_safety, color: Colors.green),
                  label: Text('API healthy'),
                  backgroundColor: Color(0xFFE8F5E9),
                ),
              ),
            if (_me != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.admin_panel_settings),
                  label: Text('${_me!.email} (${_me!.role})'),
                ),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Users'),
              Tab(text: 'Trips'),
              Tab(text: 'Realtime'),
              Tab(text: 'Logs'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4F7FB), Color(0xFFE6F4F1)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: TabBarView(
                children: [
                  _section(
                    title: 'Điều phối nhanh',
                    subtitle:
                        'Thiết lập API, đăng nhập admin và tạo user trong vài thao tác.',
                    actions: [
                      _pillButton(
                        label: 'Ping /health',
                        icon: Icons.health_and_safety,
                        onTap: _busy ? null : _pingHealth,
                      ),
                      _pillButton(
                        label: 'Đăng nhập admin',
                        icon: Icons.login,
                        onTap: _busy ? null : _login,
                      ),
                    ],
                    cards: [
                      _buildConfigCard(),
                      _buildAuthCard(),
                      _buildRegisterCard(),
                      _buildPromoCard(),
                    ],
                  ),
                  _section(
                    title: 'Quản lý người dùng',
                    subtitle:
                        'Tìm kiếm, đổi role, bật/tắt tài khoản rider/driver/admin.',
                    actions: [
                      _pillButton(
                        label: 'Tải danh sách',
                        icon: Icons.refresh,
                        onTap: _busy ? null : _loadUsers,
                      ),
                    ],
                    cards: [
                      _buildUsersCard(),
                    ],
                  ),
                  _section(
                    title: 'Chuyến đi',
                    subtitle:
                        'Tạo, truy vấn, cập nhật trạng thái và gán tài xế.',
                    actions: [
                      _pillButton(
                        label: 'Tạo trip',
                        icon: Icons.add_location_alt,
                        onTap: _busy ? null : _createTrip,
                      ),
                      _pillButton(
                        label: 'Fetch trip',
                        icon: Icons.search,
                        onTap: _busy ? null : _fetchTrip,
                      ),
                    ],
                    cards: [
                      _buildTripCreateCard(),
                      _buildTripCard(),
                    ],
                  ),
                  _section(
                    title: 'Realtime WS',
                    subtitle:
                        'Kết nối WS theo role rider/driver/admin, gửi status/location.',
                    actions: [
                      _pillButton(
                        label: 'Connect',
                        icon: Icons.wifi,
                        onTap:
                            (_wsClient?.isConnected ?? false) || _wsConnecting
                                ? null
                                : _connectWs,
                      ),
                      _pillButton(
                        label: 'Disconnect',
                        icon: Icons.wifi_off,
                        onTap: (_wsClient?.isConnected ?? false)
                            ? _disconnectWs
                            : null,
                      ),
                    ],
                    cards: [
                      _buildWsCard(),
                    ],
                  ),
                  _section(
                    title: 'Nhật ký',
                    subtitle: 'Theo dõi log API & WS, chẩn đoán nhanh.',
                    actions: const [],
                    cards: [
                      _buildLogCard(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return _card(
      title: 'API & Health',
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _apiController,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              hintText: 'http://localhost:8080',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _saveApiBase,
                icon: const Icon(Icons.save),
                label: const Text('Save base'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pingHealth,
                icon: Icon(
                  _healthOk ? Icons.check_circle : Icons.health_and_safety,
                  color: _healthOk ? Colors.green : null,
                ),
                label: Text(_healthOk ? 'Health OK' : 'Ping /health'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return _card(
      title: 'Admin login',
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _loginEmail,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _loginPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _login,
                icon: const Icon(Icons.login),
                label: const Text('Login'),
              ),
              OutlinedButton.icon(
                onPressed: _authToken.isNotEmpty ? _logout : null,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
              OutlinedButton.icon(
                onPressed: _authToken.isEmpty ? null : _loadProfile,
                icon: const Icon(Icons.verified_user),
                label: const Text('Check /admin/me'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_me != null)
            _infoRow(
              'Authenticated',
              '${_me!.email} • role=${_me!.role}',
            ),
          if (_adminMe != null) _infoRow('Admin verified', _adminMe!.email),
          if (_authToken.isNotEmpty)
            SelectableText(
              _authToken,
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    return _card(
      title: 'Create users',
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _registerName,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _registerEmail,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: _registerPhone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          TextField(
            controller: _registerPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const Divider(height: 24),
          TextField(
            controller: _driverLicense,
            decoration: const InputDecoration(labelText: 'License number'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleMake,
                  decoration: const InputDecoration(labelText: 'Make'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _vehicleModel,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleColor,
                  decoration: const InputDecoration(labelText: 'Color'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _vehiclePlate,
                  decoration: const InputDecoration(labelText: 'Plate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _registerRider,
                icon: const Icon(Icons.person_add),
                label: const Text('Register rider'),
              ),
              ElevatedButton.icon(
                onPressed: _busy ? null : _registerDriver,
                icon: const Icon(Icons.two_wheeler),
                label: const Text('Register driver'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return _card(
      title: 'Promotions',
      width: 780,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _promoTitle,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _promoDesc,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _promoCode,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _promoPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _promoGradientStart,
                  decoration:
                      const InputDecoration(labelText: 'Gradient start (#hex)'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _promoGradientEnd,
                  decoration:
                      const InputDecoration(labelText: 'Gradient end (#hex)'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _promoImageUrl,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _promoExpires,
                  decoration: const InputDecoration(
                    labelText: 'Expires (RFC3339)',
                    hintText: '2025-12-31T23:59:59Z',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _createPromotion,
                icon: const Icon(Icons.add),
                label: const Text('Create promotion'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _loadPromotions,
                icon: const Icon(Icons.refresh),
                label: const Text('Load promotions'),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_promotions.isEmpty)
            const Text('No promotions loaded')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _promotions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = _promotions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      p.code.isNotEmpty
                          ? p.code.substring(0, 1).toUpperCase()
                          : '#',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('${p.title} (${p.code})'),
                  subtitle: Text(
                    '${p.description}\nPriority ${p.priority}'
                    '${p.expiresAt != null ? ' • expires ${p.expiresAt}' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever),
                    onPressed: _busy ? null : () => _deletePromotion(p.id),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUsersCard() {
    final totalPages = (_usersTotal / (_userLimit > 0 ? _userLimit : 1)).ceil();
    return _card(
      title: 'Users',
      width: 780,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearch,
                  decoration: const InputDecoration(
                    labelText: 'Tìm email hoặc tên',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _userRoleFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All roles')),
                  DropdownMenuItem(value: 'rider', child: Text('Rider')),
                  DropdownMenuItem(value: 'driver', child: Text('Driver')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _userRoleFilter = v);
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _userDisabledFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _userDisabledFilter = v);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Load users'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) _userLimit = parsed.clamp(1, 200);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Offset'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed >= 0) {
                      _userOffset = parsed;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('Total: $_usersTotal'
                  '${totalPages > 1 ? ' • pages ~$totalPages' : ''}'),
            ],
          ),
          const Divider(height: 20),
          if (_users.isEmpty)
            const Text('No users loaded')
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.shade50,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final u = _users[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text(
                        u.name.isNotEmpty
                            ? u.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      u.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${u.name} • ${u.role}${u.disabled ? ' • disabled' : ''}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: u.role,
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null && value != u.role) {
                                    _updateUserRole(u, value);
                                  }
                                },
                          items: const [
                            DropdownMenuItem(
                                value: 'rider', child: Text('Rider')),
                            DropdownMenuItem(
                                value: 'driver', child: Text('Driver')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admin')),
                          ],
                        ),
                        Switch(
                          value: u.disabled,
                          onChanged: _busy
                              ? null
                              : (value) => _toggleUserDisabled(u, value),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCreateCard() {
    return _card(
      title: 'Create trip',
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _origin,
            decoration: const InputDecoration(labelText: 'Origin text'),
          ),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(labelText: 'Destination text'),
          ),
          TextField(
            controller: _service,
            decoration: const InputDecoration(labelText: 'Service id'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _originLat,
                  decoration: const InputDecoration(labelText: 'Origin lat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _originLng,
                  decoration: const InputDecoration(labelText: 'Origin lng'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _destLat,
                  decoration: const InputDecoration(labelText: 'Dest lat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _destLng,
                  decoration: const InputDecoration(labelText: 'Dest lng'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _createTrip,
            icon: const Icon(Icons.add_location_alt),
            label: const Text('POST /v1/trips'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard() {
    final trip = _trip;
    return _card(
      title: 'Trip tools',
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tripId,
            decoration: const InputDecoration(labelText: 'Trip ID'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _fetchTrip,
                icon: const Icon(Icons.search),
                label: const Text('Fetch trip'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _updateStatus('completed'),
                icon: const Icon(Icons.flag),
                label: const Text('Mark completed'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'arriving',
                  items: const [
                    DropdownMenuItem(
                        value: 'accepted', child: Text('accepted')),
                    DropdownMenuItem(
                        value: 'arriving', child: Text('arriving')),
                    DropdownMenuItem(value: 'in_ride', child: Text('in_ride')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('completed')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('cancelled')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) _updateStatus(value);
                        },
                  decoration: const InputDecoration(
                    labelText: 'Update status',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _assignDriverId,
            decoration:
                const InputDecoration(labelText: 'Assign driver ID (optional)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _assignDriver,
            icon: const Icon(Icons.person_pin_circle),
            label: const Text('Assign driver'),
          ),
          const SizedBox(height: 12),
          if (trip != null) _buildTripSummary(trip),
        ],
      ),
    );
  }

  Widget _buildTripSummary(TripDetail trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('Trip', trip.id),
        _infoRow('Status', trip.status),
        _infoRow('Rider', trip.riderId),
        _infoRow('Driver', trip.driverId ?? '—'),
        _infoRow('Service', trip.serviceId),
        _infoRow('Origin', trip.originText),
        _infoRow('Destination', trip.destText),
        if (trip.lastLocation != null)
          _infoRow(
            'Last location',
            '${trip.lastLocation!.latitude.toStringAsFixed(5)}, '
                '${trip.lastLocation!.longitude.toStringAsFixed(5)}',
          ),
      ],
    );
  }

  Widget _buildWsCard() {
    final connected = _wsClient?.isConnected ?? false;
    return _card(
      title: 'Realtime (WS)',
      width: 780,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wsTripId,
                  decoration: const InputDecoration(labelText: 'Trip ID'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _wsUserId,
                  decoration: const InputDecoration(
                    labelText: 'User override (optional)',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _wsRole,
                onChanged: connected
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _wsRole = value);
                        }
                      },
                items: const [
                  DropdownMenuItem(value: 'rider', child: Text('rider')),
                  DropdownMenuItem(value: 'driver', child: Text('driver')),
                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: connected || _wsConnecting ? null : _connectWs,
                icon: const Icon(Icons.wifi),
                label: const Text('Connect'),
              ),
              OutlinedButton.icon(
                onPressed: connected ? _disconnectWs : null,
                icon: const Icon(Icons.wifi_off),
                label: const Text('Disconnect'),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wsLat,
                  decoration: const InputDecoration(labelText: 'Lat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _wsLng,
                  decoration: const InputDecoration(labelText: 'Lng'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: connected ? _sendWsLocation : null,
                child: const Text('Send location'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: connected ? () => _sendWsStatus('arriving') : null,
                child: const Text('Set arriving'),
              ),
              OutlinedButton(
                onPressed: connected ? () => _sendWsStatus('in_ride') : null,
                child: const Text('Set in_ride'),
              ),
              OutlinedButton(
                onPressed: connected ? () => _sendWsStatus('completed') : null,
                child: const Text('Set completed'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: min(_wsLogs.length, 200),
                itemBuilder: (context, index) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(_wsLogs[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard() {
    return _card(
      title: 'Activity log',
      width: 780,
      child: SizedBox(
        height: 200,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            reverse: true,
            itemCount: min(_logs.length, 400),
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(_logs[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> actions,
    required List<Widget> cards,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heroHeader(title: title, subtitle: subtitle, actions: actions),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards,
          ),
        ],
      ),
    );
  }

  Widget _heroHeader({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0FB7A0), Color(0xFF1E9FD7)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    double width = 360,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.dashboard_customize, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
