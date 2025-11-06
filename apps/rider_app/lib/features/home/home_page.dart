import 'package:flutter/material.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/features/auth/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _pickupController = TextEditingController(text: 'Sảnh A, Đại học UIT');
  final TextEditingController _destinationController = TextEditingController();
  final PageController _promoController = PageController(viewportFraction: 0.88);

  DateTime? _scheduledAt;
  String _selectedServiceId = _serviceOptions.first.id;
  bool _scheduleEnabled = false;
  late Future<_HomeSnapshot> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeSnapshot();
  }

  Future<_HomeSnapshot> _loadHomeSnapshot() async {
    final userInfo = await AuthService().getUserInfo();
    final now = DateTime.now();
    return _HomeSnapshot(
      riderName: userInfo['name']?.isNotEmpty == true ? userInfo['name']! : 'Bạn',
      walletBalance: 185000,
      rewardPoints: 340,
      savedPlaces: _mockSavedPlaces,
      promotions: _mockPromotions,
      upcomingTrips: _mockUpcomingTrips(now),
      recentTrips: _mockRecentTrips(now),
      news: _mockNewsItems,
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) {
    AuthService().logout();
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _refreshHome() async {
    setState(() {
      _homeFuture = _loadHomeSnapshot();
    });
    await _homeFuture;
  }

  void _handlePrimaryAction(_HomeSnapshot snapshot) {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn muốn đến đâu? Hãy nhập điểm đến trước nhé.')),
      );
      return;
    }

    final pickup = _pickupController.text.trim().isEmpty ? 'Vị trí hiện tại của bạn' : _pickupController.text.trim();
    final service = _serviceOptions.firstWhere((s) => s.id == _selectedServiceId);
    final scheduleText = _scheduleEnabled && _scheduledAt != null ? _formatSchedule(_scheduledAt!) : 'Ngay lập tức';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Xác nhận chuyến đi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow('Dịch vụ', service.title, icon: service.icon),
              _buildSummaryRow('Điểm đón', pickup, icon: Icons.radio_button_checked),
              _buildSummaryRow('Điểm đến', destination, icon: Icons.location_on),
              _buildSummaryRow('Thời gian', scheduleText, icon: Icons.schedule),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đặt chuyến thành công! Tài xế sẽ liên hệ bạn sớm.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF667EEA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Xác nhận đặt chuyến',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: const Color(0xFF667EEA)),
            ),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectService(String serviceId) {
    setState(() {
      _selectedServiceId = serviceId;
    });
  }

  void _handleQuickAction(_QuickAction action) {
    switch (action.id) {
      case 'popular-uit':
        _destinationController.text = 'Cổng chính Đại học UIT';
        break;
      case 'home-trip':
        _pickupController.text = '12 Võ Oanh, Bình Thạnh';
        _destinationController.text = 'UIT, Linh Trung, Thủ Đức';
        break;
      case 'express':
        _selectService('express');
        _destinationController.text = 'Bưu cục UIT-Express, Q.Thủ Đức';
        break;
      case 'support':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chúng tôi sẽ kết nối bạn với tổng đài trong giây lát.')),
        );
        break;
    }
  }

  void _showSavedPlaceSheet(_SavedPlace place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF667EEA).withValues(alpha: 0.1),
                child: Icon(place.icon, color: const Color(0xFF667EEA)),
              ),
              title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(place.address),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.radio_button_checked, color: Colors.green),
              title: const Text('Chọn làm điểm đón'),
              onTap: () {
                _pickupController.text = place.address;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFFFF6B6B)),
              title: const Text('Chọn làm điểm đến'),
              onTap: () {
                _destinationController.text = place.address;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final initialDate = _scheduledAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (!mounted) return;
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now.add(const Duration(minutes: 20))),
    );
    if (!mounted) return;
    if (time == null) return;
    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!mounted) return;
    setState(() {
      _scheduledAt = scheduled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FutureBuilder<_HomeSnapshot>(
        future: _homeFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final hasData = snapshot.connectionState == ConnectionState.done && data != null;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: FloatingActionButton.extended(
                onPressed: hasData ? () => _handlePrimaryAction(data) : null,
                backgroundColor: const Color(0xFF667EEA),
                elevation: 4,
                label: const Text(
                  'Đặt chuyến ngay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                icon: const Icon(Icons.directions_bike, color: Colors.white),
              ),
            ),
          );
        },
      ),
      body: FutureBuilder<_HomeSnapshot>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (snapshot.hasError || data == null) {
            return _buildErrorState();
          }
          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(_HomeSnapshot snapshot) {
    return Stack(
      children: [
        _buildBackground(),
        SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 18),
                _buildHeader(snapshot),
                _buildWalletAndPoints(snapshot),
                _buildSearchCard(snapshot),
                _buildSavedPlaces(snapshot),
                _buildQuickActions(),
                _buildUpcomingTrips(snapshot),
                _buildPromotions(snapshot),
                _buildRecentTrips(snapshot),
                _buildNews(snapshot),
                const SizedBox(height: 140),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return Container(
      height: 320,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 70, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Không tải được dữ liệu trang chủ',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshHome,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(_HomeSnapshot snapshot) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF667EEA), size: 30),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, ${snapshot.riderName}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Tài xế tin cậy gần bạn',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Wrap the IconButton with a Stack and position the badge outside the icon
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bạn đang xem bản demo, tính năng thông báo sẽ có sớm!')),
                  );
                },
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('3', style: TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletAndPoints(_HomeSnapshot snapshot) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UITGo Pay', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 6),
                Text(
                  '${_formatCurrency(snapshot.walletBalance)} đ',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nạp tiền sẽ được kích hoạt khi kết nối ví điện tử.')),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Nạp thêm'),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 72, color: Colors.grey[200]),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Điểm thưởng', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 6),
                Text(
                  '${snapshot.rewardPoints}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text('Đổi km miễn phí', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(_HomeSnapshot snapshot) {
    final selectedService = _serviceOptions.firstWhere((s) => s.id == _selectedServiceId);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Đặt dịch vụ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selectedService.icon, color: const Color(0xFF667EEA), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      selectedService.title,
                      style: const TextStyle(color: Color(0xFF667EEA), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _serviceOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final service = _serviceOptions[index];
                final isSelected = service.id == _selectedServiceId;
                return GestureDetector(
                  onTap: () => _selectService(service.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: service.gradient)
                          : null,
                      color: isSelected ? null : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          service.icon,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          service.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (service.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFF667EEA).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              service.badge!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? const Color(0xFF667EEA) : const Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildLocationField(
            controller: _pickupController,
            icon: Icons.radio_button_checked,
            hintText: 'Điểm đón',
            color: const Color(0xFF38B000),
            suffix: IconButton(
              onPressed: () => _pickupController.clear(),
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          _buildLocationField(
            controller: _destinationController,
            icon: Icons.location_on,
            hintText: 'Bạn muốn đến đâu?',
            color: const Color(0xFFFF6B6B),
            suffix: IconButton(
              onPressed: () => _destinationController.clear(),
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final currentPickup = _pickupController.text;
                  _pickupController.text = _destinationController.text;
                  _destinationController.text = currentPickup;
                },
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                label: const Text('Đổi vị trí'),
                style: ElevatedButton.styleFrom(
                  // Override global theme minimumSize to avoid infinite width in Row
                  minimumSize: const Size(0, 40),
                  backgroundColor: const Color(0xFF667EEA).withValues(alpha: 0.08),
                  foregroundColor: const Color(0xFF667EEA),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Switch.adaptive(
                      value: _scheduleEnabled,
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF667EEA);
                        }
                        return null;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF667EEA).withValues(alpha: 0.3);
                        }
                        return null;
                      }),
                      onChanged: (value) {
                        setState(() {
                          _scheduleEnabled = value;
                          if (!value) _scheduledAt = null;
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đặt lịch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          if (_scheduleEnabled && _scheduledAt != null)
                            Text(
                              _formatSchedule(_scheduledAt!),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    if (_scheduleEnabled)
                      TextButton(
                        onPressed: _pickSchedule,
                        child: const Text('Chọn giờ'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (snapshot.savedPlaces.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.savedPlaces.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final place = snapshot.savedPlaces[index];
                  return ActionChip(
                    label: Text(place.name),
                    avatar: Icon(place.icon, size: 18, color: Colors.grey[700]),
                    onPressed: () => _showSavedPlaceSheet(place),
                    backgroundColor: Colors.grey[100],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required Color color,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _buildSavedPlaces(_HomeSnapshot snapshot) {
    if (snapshot.savedPlaces.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: const [
              Text('Địa điểm yêu thích', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(
          height: 114,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final place = snapshot.savedPlaces[index];
              return GestureDetector(
                onTap: () => _showSavedPlaceSheet(place),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(place.icon, color: const Color(0xFF667EEA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        place.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemCount: snapshot.savedPlaces.length,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tiện ích nhanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _quickActions.map((action) {
              return GestureDetector(
                onTap: () => _handleQuickAction(action),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(action.icon, color: action.color),
                      const SizedBox(height: 12),
                      Text(
                        action.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTrips(_HomeSnapshot snapshot) {
    final trips = snapshot.upcomingTrips;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Chuyến đã đặt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Màn hình quản lý chuyến chưa khả dụng trong bản demo.')),
                    );
                  },
                  child: const Text('Quản lý'),
                ),
              ],
            ),
            if (trips.isEmpty)
              _buildEmptyState('Chưa có chuyến nào, đặt ngay để trải nghiệm.')
            else
              Column(
                children: trips.map((trip) => _buildTripTile(trip, highlight: true)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotions(_HomeSnapshot snapshot) {
    final promotions = snapshot.promotions;
    if (promotions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Ưu đãi nổi bật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _promoController,
              itemCount: promotions.length,
              itemBuilder: (context, index) {
                final promo = promotions[index];
                return Padding(
                  padding: EdgeInsets.only(right: index == promotions.length - 1 ? 20 : 10, left: index == 0 ? 20 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: promo.gradient),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: promo.gradient.last.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promo.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          promo.description,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                promo.code,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF667EEA)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              promo.expiry,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrips(_HomeSnapshot snapshot) {
    final trips = snapshot.recentTrips;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Chuyến gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lịch sử chuyến sẽ được đồng bộ khi kết nối backend.')),
                  ),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            if (trips.isEmpty)
              _buildEmptyState('Bạn chưa thực hiện chuyến đi nào. Khám phá UITGo ngay!')
            else
              Column(
                children: trips.map(_buildTripTile).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNews(_HomeSnapshot snapshot) {
    final items = snapshot.news;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tin tức UITGo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.icon, color: const Color(0xFF667EEA)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.description,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.timeAgo,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTripTile(_TripSummary trip, {bool highlight = false}) {
    final service = _serviceOptions.firstWhere((s) => s.id == trip.serviceId, orElse: () => _serviceOptions.first);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF667EEA).withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: service.gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(service.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_formatSchedule(trip.dateTime), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              _buildStatusChip(trip.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.radio_button_checked, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.origin,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag, size: 16, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.destination,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.attach_money, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${_formatCurrency(trip.estimatedPrice)} đ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (trip.status == TripStatus.scheduled)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bạn có thể sửa chuyến khi kết nối backend.')),
                    );
                  },
                  child: const Text('Sửa chuyến'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TripStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.route, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Thông tin cá nhân',
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuItem(
              icon: Icons.history,
              title: 'Lịch sử chuyến đi',
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuItem(
              icon: Icons.payment,
              title: 'Phương thức thanh toán',
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuItem(
              icon: Icons.location_on_outlined,
              title: 'Địa điểm đã lưu',
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuItem(
              icon: Icons.settings_outlined,
              title: 'Cài đặt',
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Trợ giúp & Hỗ trợ',
              onTap: () => Navigator.pop(context),
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'Đăng xuất',
              color: Colors.red[400],
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: color ?? Colors.grey[900],
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.riderName,
    required this.walletBalance,
    required this.rewardPoints,
    required this.savedPlaces,
    required this.promotions,
    required this.upcomingTrips,
    required this.recentTrips,
    required this.news,
  });

  final String riderName;
  final int walletBalance;
  final int rewardPoints;
  final List<_SavedPlace> savedPlaces;
  final List<_PromotionItem> promotions;
  final List<_TripSummary> upcomingTrips;
  final List<_TripSummary> recentTrips;
  final List<_NewsItem> news;
}

class _ServiceOption {
  const _ServiceOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String? badge;
}

class _QuickAction {
  const _QuickAction({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class _SavedPlace {
  const _SavedPlace({
    required this.name,
    required this.address,
    required this.icon,
  });

  final String name;
  final String address;
  final IconData icon;
}

class _PromotionItem {
  const _PromotionItem({
    required this.title,
    required this.description,
    required this.code,
    required this.expiry,
    required this.gradient,
  });

  final String title;
  final String description;
  final String code;
  final String expiry;
  final List<Color> gradient;
}

class _NewsItem {
  const _NewsItem({
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.icon,
  });

  final String title;
  final String description;
  final String timeAgo;
  final IconData icon;
}

enum TripStatus { scheduled, onTheWay, completed, cancelled }

class _TripSummary {
  const _TripSummary({
    required this.serviceId,
    required this.origin,
    required this.destination,
    required this.dateTime,
    required this.estimatedPrice,
    required this.status,
  });

  final String serviceId;
  final String origin;
  final String destination;
  final DateTime dateTime;
  final int estimatedPrice;
  final TripStatus status;
}

const List<_ServiceOption> _serviceOptions = [
  _ServiceOption(
    id: 'bike',
    title: 'UIT-Bike',
    subtitle: 'Xe máy siêu tốc',
    icon: Icons.two_wheeler,
    gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
    badge: 'Ưa thích',
  ),
  _ServiceOption(
    id: 'car',
    title: 'UIT-Car',
    subtitle: 'Ô tô thoải mái',
    icon: Icons.directions_car,
    gradient: [Color(0xFF38EF7D), Color(0xFF11998E)],
  ),
  _ServiceOption(
    id: 'express',
    title: 'UIT-Express',
    subtitle: 'Giao hàng nhanh',
    icon: Icons.local_shipping_outlined,
    gradient: [Color(0xFFFF9A56), Color(0xFFFF6A88)],
  ),
  _ServiceOption(
    id: 'food',
    title: 'UIT-Food',
    subtitle: 'Đồ ăn nóng hổi',
    icon: Icons.fastfood_outlined,
    gradient: [Color(0xFFFF6B6B), Color(0xFFFFD166)],
  ),
];

const List<_QuickAction> _quickActions = [
  _QuickAction(
    id: 'popular-uit',
    label: 'Đi UIT nhanh',
    description: 'Chỉ 5 phút gọi xe',
    icon: Icons.school_outlined,
    color: Color(0xFF667EEA),
  ),
  _QuickAction(
    id: 'home-trip',
    label: 'Về nhà',
    description: 'Đã lưu tuyến hằng ngày',
    icon: Icons.home_outlined,
    color: Color(0xFF38EF7D),
  ),
  _QuickAction(
    id: 'express',
    label: 'Gửi hàng',
    description: 'Gọi tài xế giao nhanh',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFFFF9A56),
  ),
  _QuickAction(
    id: 'support',
    label: 'Gọi hỗ trợ',
    description: 'Tổng đài 24/7',
    icon: Icons.headset_mic_outlined,
    color: Color(0xFFFF6B6B),
  ),
];

const List<_SavedPlace> _mockSavedPlaces = [
  _SavedPlace(
    name: 'Nhà riêng',
    address: '12 Võ Oanh, Bình Thạnh, TP.HCM',
    icon: Icons.home_rounded,
  ),
  _SavedPlace(
    name: 'Đại học UIT',
    address: 'Khu phố 6, P. Linh Trung, Thủ Đức',
    icon: Icons.school_rounded,
  ),
  _SavedPlace(
    name: 'Tòa nhà F',
    address: 'Tòa nhà F, UIT, Thủ Đức',
    icon: Icons.apartment_rounded,
  ),
];

const List<_PromotionItem> _mockPromotions = [
  _PromotionItem(
    title: 'Giảm 30% chuyến đầu',
    description: 'Nhập mã UITNEW để được ưu đãi tối đa 30.000đ',
    code: 'UITNEW',
    expiry: 'HSD: 30/09',
    gradient: [Color(0xFFFFA751), Color(0xFFFFE259)],
  ),
  _PromotionItem(
    title: 'Đi 5 chuyến - Tặng 1',
    description: 'Tích đủ 5 chuyến UIT-Bike để nhận chuyến miễn phí',
    code: 'FREERIDE5',
    expiry: 'HSD: 15/10',
    gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ),
  _PromotionItem(
    title: 'UIT-Food giảm 50%',
    description: 'Ưu đãi ngon cho sinh viên, áp dụng đơn từ 50k',
    code: 'UITFOOD50',
    expiry: 'HSD: 05/10',
    gradient: [Color(0xFFFF6B6B), Color(0xFFFF9A56)],
  ),
];

const List<_NewsItem> _mockNewsItems = [
  _NewsItem(
    title: 'UITGo mở rộng khu vực',
    description: 'Tài xế nay đã phủ sóng khắp TP Dĩ An và Thuận An.',
    timeAgo: '2 giờ trước',
    icon: Icons.map_outlined,
  ),
  _NewsItem(
    title: 'UIT-Food hợp tác cùng canteen',
    description: 'Đặt món tại căn tin B nhanh chóng, giao trong 10 phút.',
    timeAgo: 'Hôm qua',
    icon: Icons.restaurant_menu,
  ),
  _NewsItem(
    title: 'Chăm sóc khách hàng 24/7',
    description: 'Liên hệ ngay UITGo Care để được hỗ trợ mọi lúc.',
    timeAgo: '2 ngày trước',
    icon: Icons.support_agent,
  ),
];

List<_TripSummary> _mockUpcomingTrips(DateTime now) {
  return [
    _TripSummary(
      serviceId: 'bike',
      origin: 'KTX UIT, Thủ Đức',
      destination: 'Bến xe Miền Đông mới',
      dateTime: now.add(const Duration(hours: 2)),
      estimatedPrice: 78000,
      status: TripStatus.scheduled,
    ),
    _TripSummary(
      serviceId: 'car',
      origin: 'UIT, Tòa nhà H',
      destination: 'Quận 1, Nguyễn Huệ',
      dateTime: now.add(const Duration(hours: 5, minutes: 30)),
      estimatedPrice: 190000,
      status: TripStatus.scheduled,
    ),
  ];
}

List<_TripSummary> _mockRecentTrips(DateTime now) {
  return [
    _TripSummary(
      serviceId: 'express',
      origin: 'UIT, Linh Trung',
      destination: 'Ký túc xá khu B',
      dateTime: now.subtract(const Duration(hours: 4)),
      estimatedPrice: 45000,
      status: TripStatus.completed,
    ),
    _TripSummary(
      serviceId: 'bike',
      origin: 'Nhà sách Fahasa',
      destination: 'Ký túc xá UIT',
      dateTime: now.subtract(const Duration(days: 1, hours: 3)),
      estimatedPrice: 39000,
      status: TripStatus.completed,
    ),
    _TripSummary(
      serviceId: 'food',
      origin: 'UIT-Food - Canteen A',
      destination: 'Tòa nhà E, UIT',
      dateTime: now.subtract(const Duration(days: 2, hours: 1)),
      estimatedPrice: 62000,
      status: TripStatus.completed,
    ),
  ];
}

String _formatSchedule(DateTime time) {
  final day = time.day.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$day/$month • $hour:$minute';
}

String _formatCurrency(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final reversedIndex = digits.length - i;
    buffer.write(digits[i]);
    if (reversedIndex > 1 && reversedIndex % 3 == 1 && i != digits.length - 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

Color _statusColor(TripStatus status) {
  switch (status) {
    case TripStatus.scheduled:
      return const Color(0xFF667EEA);
    case TripStatus.onTheWay:
      return const Color(0xFFFFA751);
    case TripStatus.completed:
      return const Color(0xFF38EF7D);
    case TripStatus.cancelled:
      return const Color(0xFFFF6B6B);
  }
}

String _statusLabel(TripStatus status) {
  switch (status) {
    case TripStatus.scheduled:
      return 'Đã đặt';
    case TripStatus.onTheWay:
      return 'Đang tới';
    case TripStatus.completed:
      return 'Hoàn thành';
    case TripStatus.cancelled:
      return 'Đã hủy';
  }
}
