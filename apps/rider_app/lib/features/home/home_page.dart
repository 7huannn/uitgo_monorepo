import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/features/auth/services/auth_service.dart';
import 'package:rider_app/features/home/models/home_models.dart';
import 'package:rider_app/features/home/services/home_service.dart';
import 'package:rider_app/features/notifications/services/notification_service.dart';
import 'package:rider_app/features/places/models/place_suggestion.dart';
import 'package:rider_app/features/places/services/geocoding_service.dart';
import 'package:rider_app/features/trip/models/trip_models.dart';
import 'package:rider_app/features/trip/services/trip_service.dart';
import 'package:rider_app/features/trip/services/routing_service.dart';
import 'package:rider_app/features/wallet/state/wallet_notifier.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.debugStartReady = false});

  // Test-only: bypass loading services and render the ready state immediately.
  final bool debugStartReady;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TextEditingController _pickupController =
      TextEditingController(text: 'Sảnh A, Đại học UIT');
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();
  final LayerLink _pickupLayerLink = LayerLink();
  final LayerLink _destinationLayerLink = LayerLink();
  final GlobalKey _pickupFieldKey = GlobalKey();
  final GlobalKey _destinationFieldKey = GlobalKey();
  final NotificationService _notificationService = NotificationService();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _pickupOverlayEntry;
  OverlayEntry? _destinationOverlayEntry;

  DateTime? _scheduledAt;
  String _selectedServiceId = _serviceOptions.first.id;
  bool _scheduleEnabled = false;
  final TripService _tripService = TripService();
  final HomeService _homeService = HomeService();
  final GeocodingService _geocodingService = GeocodingService();
  final RoutingService _routingService = RoutingService();
  TripDetail? _activeTrip;
  LocationUpdate? _liveLocation;
  String? _liveStatus;
  bool _isBooking = false;
  late Future<_HomeSnapshot> _homeFuture;
  PlaceSuggestion? _pickupPlace;
  PlaceSuggestion? _destinationPlace;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  List<PlaceSuggestion> _pickupSuggestions = const [];
  List<PlaceSuggestion> _destinationSuggestions = const [];
  Timer? _pickupDebounce;
  Timer? _destinationDebounce;
  bool _searchingPickup = false;
  bool _searchingDestination = false;
  RouteOverview? _routeOverview;
  bool _loadingRoutePreview = false;
  String? _routeError;
  bool _suppressPickupTextChange = false;
  bool _suppressDestinationTextChange = false;
  bool _interactingWithPickupOverlay = false;
  bool _interactingWithDestinationOverlay = false;
  bool _overlayRebuildPending = false;
  Size _pickupFieldSize = Size.zero;
  Size _destinationFieldSize = Size.zero;
  int _unreadNotifications = 0;
  PromotionBanner? _appliedPromotion;
  String? _promoError;
  List<PromotionBanner> _currentPromotions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleViewportChange);
    _pickupPlace = const PlaceSuggestion(
      name: 'Sảnh A, Đại học UIT',
      latitude: 10.8705,
      longitude: 106.8032,
      address: 'Khu phố 6, Linh Trung',
    );
    _pickupLatLng = const LatLng(10.8705, 106.8032);
    _setPickupText(_pickupPlace!.displayName, suppressOnChanged: true);
    _pickupFocus.addListener(_onPickupFocusChange);
    _destinationFocus.addListener(_onDestinationFocusChange);
    _promoCodeController.addListener(_onPromoCodeChanged);
    if (widget.debugStartReady) {
      _homeFuture = Future.value(
        _HomeSnapshot(
          riderName: 'Bạn',
          wallet: WalletSummary(balance: 0, rewardPoints: 0),
          savedPlaces: const [],
          promotions: const [],
          upcomingTrips: const [],
          recentTrips: const [],
          news: const [],
        ),
      );
    } else {
      _homeFuture = _loadHomeSnapshot();
    }
    unawaited(_refreshUnreadNotifications());
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _handleViewportChange();
  }

  Future<_HomeSnapshot> _loadHomeSnapshot() async {
    final userInfo = await AuthService().getUserInfo();
    final riderName =
        userInfo['name']?.isNotEmpty == true ? userInfo['name']! : 'Bạn';

    final results = await Future.wait([
      _homeService.fetchWallet(),
      _homeService.fetchSavedPlaces(),
      _homeService.fetchPromotions(),
      _homeService.fetchNews(limit: 5),
      _tripService.listTrips(role: 'rider', page: 1, pageSize: 20),
    ]);

    final wallet = results[0] as WalletSummary;
    final savedPlaces = results[1] as List<SavedPlaceModel>;
    final promotions = results[2] as List<PromotionBanner>;
    _currentPromotions = promotions;
    final news = results[3] as List<HomeNewsItem>;
    final pagedTrips = results[4] as PagedTrips;
    final trips = [...pagedTrips.items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) {
      context.read<WalletNotifier>().replace(wallet);
    }

    final upcoming =
        trips.where((trip) => !_isTerminalStatus(trip.status)).take(3).toList();
    final recent =
        trips.where((trip) => _isTerminalStatus(trip.status)).take(5).toList();

    return _HomeSnapshot(
      riderName: riderName,
      wallet: wallet,
      savedPlaces: savedPlaces,
      promotions: promotions,
      upcomingTrips: upcoming,
      recentTrips: recent,
      news: news,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removePickupOverlay();
    _removeDestinationOverlay();
    _pickupFocus.removeListener(_onPickupFocusChange);
    _destinationFocus.removeListener(_onDestinationFocusChange);
    _promoCodeController.removeListener(_onPromoCodeChanged);
    _pickupController.dispose();
    _destinationController.dispose();
    _promoCodeController.dispose();
    _scrollController.removeListener(_handleViewportChange);
    _scrollController.dispose();
    _cancelPickupDebounce(reason: 'dispose');
    _cancelDestinationDebounce(reason: 'dispose');
    _scheduleSuppressionRelease(
        isPickup: true, reason: 'dispose', immediate: true);
    _scheduleSuppressionRelease(
        isPickup: false, reason: 'dispose', immediate: true);
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    unawaited(_tripService.closeChannel());
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    context.goNamed(AppRouteNames.login);
  }

  Future<void> _openWalletPage() async {
    if (!mounted) return;
    await context.pushNamed(AppRouteNames.payments);
  }

  void _refreshFocusState() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleViewportChange() {
    if (!mounted) return;
    _pickupOverlayEntry?.markNeedsBuild();
    _destinationOverlayEntry?.markNeedsBuild();
    if (_overlayRebuildPending) return;
    _overlayRebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildPending = false;
      if (!mounted) return;
      _pickupOverlayEntry?.markNeedsBuild();
      _destinationOverlayEntry?.markNeedsBuild();
    });
  }

  void _onPickupFocusChange() {
    _refreshFocusState();
    _refreshPickupOverlay();
  }

  void _onDestinationFocusChange() {
    _refreshFocusState();
    _refreshDestinationOverlay();
  }

  bool get _canBook => _pickupLatLng != null && _destinationLatLng != null;

  void _cancelPickupDebounce({required String reason}) {
    if (_pickupDebounce == null) return;
    if (_pickupDebounce!.isActive) {
      debugPrint('[SUGGESTION_TAP][pickup] cancel debounce (reason: $reason)');
    }
    _pickupDebounce?.cancel();
    _pickupDebounce = null;
  }

  void _cancelDestinationDebounce({required String reason}) {
    if (_destinationDebounce == null) return;
    if (_destinationDebounce!.isActive) {
      debugPrint(
          '[SUGGESTION_TAP][destination] cancel debounce (reason: $reason)');
    }
    _destinationDebounce?.cancel();
    _destinationDebounce = null;
  }

  void _logCtaState(String source) {
    debugPrint(
      '[SUGGESTION_TAP][CTA] $source pickupReady=${_pickupLatLng != null} '
      'destReady=${_destinationLatLng != null} canBook=$_canBook',
    );
  }

  Future<void> _refreshHome() async {
    setState(() {
      _homeFuture = _loadHomeSnapshot();
    });
    await _homeFuture;
    await _refreshUnreadNotifications();
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final page = await _notificationService.listNotifications(
        unreadOnly: true,
        limit: 1,
      );
      if (!mounted) return;
      setState(() {
        _unreadNotifications = page.total;
      });
    } catch (e) {
      debugPrint('Failed to load unread notifications: $e');
      if (!mounted) return;
      setState(() {
        _unreadNotifications = 0;
      });
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      final page = await _notificationService.listNotifications(
        unreadOnly: true,
        limit: 50,
      );
      if (page.items.isEmpty) return;
      await Future.wait(
        page.items.map((notification) async {
          try {
            await _notificationService.markAsRead(notification.id);
          } catch (error) {
            debugPrint(
                'Failed to mark notification ${notification.id}: $error');
          }
        }),
      );
    } catch (e) {
      debugPrint('Failed to mark notifications as read: $e');
    }
  }

  Future<void> _openNotifications() async {
    await context.pushNamed(AppRouteNames.notifications);
    if (!mounted) return;
    setState(() {
      _unreadNotifications = 0;
    });
    unawaited(() async {
      await _markAllNotificationsAsRead();
      await _refreshUnreadNotifications();
    }());
  }

  void _setOverlayPointerInteraction({
    required bool isPickup,
    required bool active,
  }) {
    final label = isPickup ? 'pickup' : 'destination';
    final previous = isPickup
        ? _interactingWithPickupOverlay
        : _interactingWithDestinationOverlay;
    if (previous == active) return;
    if (isPickup) {
      _interactingWithPickupOverlay = active;
    } else {
      _interactingWithDestinationOverlay = active;
    }
    debugPrint(
      '[SUGGESTION_TAP][$label] overlay pointer ${active ? 'down' : 'up'}',
    );
    if (!active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isPickup) {
          _refreshPickupOverlay();
        } else {
          _refreshDestinationOverlay();
        }
      });
    }
  }

  void _refreshPickupOverlay() {
    final shouldShow = _pickupFocus.hasFocus && _pickupSuggestions.isNotEmpty;
    if (shouldShow) {
      _showPickupOverlay();
    } else if (!_interactingWithPickupOverlay) {
      _removePickupOverlay();
    }
  }

  void _refreshDestinationOverlay() {
    final shouldShow =
        _destinationFocus.hasFocus && _destinationSuggestions.isNotEmpty;
    if (shouldShow) {
      _showDestinationOverlay();
    } else if (!_interactingWithDestinationOverlay) {
      _removeDestinationOverlay();
    }
  }

  void _setPickupText(
    String text, {
    bool suppressOnChanged = false,
    String reason = 'setPickupText',
  }) {
    if (suppressOnChanged) {
      _beginSuppression(isPickup: true, reason: reason);
    }
    _applySuggestionToController(
      controller: _pickupController,
      text: text,
      debugLabel: 'pickup',
    );
    if (suppressOnChanged) {
      _scheduleSuppressionRelease(isPickup: true, reason: reason);
    }
  }

  void _setDestinationText(
    String text, {
    bool suppressOnChanged = false,
    String reason = 'setDestinationText',
  }) {
    if (suppressOnChanged) {
      _beginSuppression(isPickup: false, reason: reason);
    }
    _applySuggestionToController(
      controller: _destinationController,
      text: text,
      debugLabel: 'destination',
    );
    if (suppressOnChanged) {
      _scheduleSuppressionRelease(isPickup: false, reason: reason);
    }
  }

  void _applySuggestionToController({
    required TextEditingController controller,
    required String text,
    required String debugLabel,
  }) {
    final trimmed = text.trim();
    final resolvedText = trimmed.isEmpty ? text : trimmed;
    debugPrint(
      '[SUGGESTION_TAP][$debugLabel] preApply controller="${controller.text}" '
      'target="$resolvedText"',
    );
    controller.value = TextEditingValue(
      text: resolvedText,
      selection: TextSelection.collapsed(offset: resolvedText.length),
      composing: TextRange.empty,
    );
    debugPrint(
      '[SUGGESTION_TAP][$debugLabel] postApply controller="${controller.text}"',
    );
    debugPrint(
      '[APPLY_HELPER][$debugLabel] commit="$resolvedText" composingCleared',
    );
    assert(() {
      final ok = controller.text == resolvedText;
      if (!ok) {
        debugPrint(
          '[SUGGESTION_TAP][ASSERT][$debugLabel] Controller text mismatch '
          '(expected "$resolvedText", got "${controller.text}")',
        );
      }
      return ok;
    }());
  }

  void _beginSuppression({required bool isPickup, required String reason}) {
    if (isPickup) {
      if (!_suppressPickupTextChange) {
        debugPrint(
            '[SUGGESTION_TAP][pickup] begin suppression (reason: $reason)');
      } else {
        debugPrint(
            '[SUGGESTION_TAP][pickup] suppression already active (reason: $reason)');
      }
      _suppressPickupTextChange = true;
    } else {
      if (!_suppressDestinationTextChange) {
        debugPrint(
            '[SUGGESTION_TAP][destination] begin suppression (reason: $reason)');
      } else {
        debugPrint(
            '[SUGGESTION_TAP][destination] suppression already active (reason: $reason)');
      }
      _suppressDestinationTextChange = true;
    }
  }

  void _scheduleSuppressionRelease({
    required bool isPickup,
    required String reason,
    bool immediate = false,
  }) {
    void release() {
      if (isPickup) {
        if (_suppressPickupTextChange) {
          debugPrint(
              '[SUGGESTION_TAP][pickup] release suppression (reason: $reason)');
          _suppressPickupTextChange = false;
        }
      } else {
        if (_suppressDestinationTextChange) {
          debugPrint(
              '[SUGGESTION_TAP][destination] release suppression (reason: $reason)');
          _suppressDestinationTextChange = false;
        }
      }
    }

    if (immediate) {
      release();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => release());
  }

  void _onPickupChanged(String value) {
    if (_suppressPickupTextChange) {
      debugPrint('[SUGGESTION_TAP][pickup] skip onChanged (suppressed)');
      return;
    }
    _cancelPickupDebounce(reason: 'onChanged');
    final trimmed = value.trim();
    setState(() {
      _pickupPlace = null;
      _pickupLatLng = null;
      _routeOverview = null;
      _routeError = null;
      _searchingPickup = trimmed.length >= 2;
    });
    if (trimmed.length < 2) {
      setState(() {
        _pickupSuggestions = const [];
        _searchingPickup = false;
      });
      _refreshPickupOverlay();
      _logCtaState('pickup:onChanged<2');
      return;
    }
    _pickupDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _geocodingService.search(trimmed);
        if (!mounted) return;
        setState(() {
          _pickupSuggestions = results;
          _searchingPickup = false;
        });
        _refreshPickupOverlay();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _pickupSuggestions = const [];
          _searchingPickup = false;
        });
        _refreshPickupOverlay();
      }
    });
  }

  void _onDestinationChanged(String value) {
    if (_suppressDestinationTextChange) {
      debugPrint('[SUGGESTION_TAP][destination] skip onChanged (suppressed)');
      return;
    }
    _cancelDestinationDebounce(reason: 'onChanged');
    final trimmed = value.trim();
    setState(() {
      _destinationPlace = null;
      _destinationLatLng = null;
      _routeOverview = null;
      _routeError = null;
      _searchingDestination = trimmed.length >= 2;
    });
    if (trimmed.length < 2) {
      setState(() {
        _destinationSuggestions = const [];
        _searchingDestination = false;
      });
      _refreshDestinationOverlay();
      _logCtaState('destination:onChanged<2');
      return;
    }
    _destinationDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _geocodingService.search(trimmed);
        if (!mounted) return;
        setState(() {
          _destinationSuggestions = results;
          _searchingDestination = false;
        });
        _refreshDestinationOverlay();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _destinationSuggestions = const [];
          _searchingDestination = false;
        });
        _refreshDestinationOverlay();
      }
    });
  }

  void _selectPickupSuggestion(PlaceSuggestion suggestion) {
    debugPrint(
        '[SUGGESTION_TAP][pickup] select label="${suggestion.name}" display="${suggestion.displayName}"');
    _commitSuggestion(suggestion, isPickup: true);
  }

  void _selectDestinationSuggestion(PlaceSuggestion suggestion) {
    debugPrint(
        '[SUGGESTION_TAP][destination] select label="${suggestion.name}" display="${suggestion.displayName}"');
    _commitSuggestion(suggestion, isPickup: false);
  }

  void _commitSuggestion(PlaceSuggestion suggestion, {required bool isPickup}) {
    final label = isPickup ? 'pickup' : 'destination';
    final controller = isPickup ? _pickupController : _destinationController;
    final focusNode = isPickup ? _pickupFocus : _destinationFocus;
    final removeOverlay =
        isPickup ? _removePickupOverlay : _removeDestinationOverlay;
    final cancelDebounce =
        isPickup ? _cancelPickupDebounce : _cancelDestinationDebounce;

    cancelDebounce(reason: 'selection');
    _beginSuppression(isPickup: isPickup, reason: 'selection');

    setState(() {
      if (isPickup) {
        _pickupPlace = suggestion;
        _pickupLatLng = LatLng(suggestion.latitude, suggestion.longitude);
        _pickupSuggestions = const [];
        _searchingPickup = false;
      } else {
        _destinationPlace = suggestion;
        _destinationLatLng = LatLng(suggestion.latitude, suggestion.longitude);
        _destinationSuggestions = const [];
        _searchingDestination = false;
      }
    });

    final displayName = suggestion.displayName;
    final sanitizedLabel = displayName.trim();
    final committedLabel =
        sanitizedLabel.isEmpty ? suggestion.name : sanitizedLabel;

    _applySuggestionToController(
      controller: controller,
      text: committedLabel,
      debugLabel: label,
    );

    debugPrint('[$label] ${suggestion.name} -> '
        '${suggestion.latitude}, ${suggestion.longitude}');

    focusNode.unfocus();
    removeOverlay();

    _scheduleSuppressionRelease(isPickup: isPickup, reason: 'selection');

    _tryLoadRouteOverview();
    _logCtaState('$label:selection');
  }

  Future<void> _tryLoadRouteOverview() async {
    final pickup = _pickupLatLng;
    final dest = _destinationLatLng;
    if (pickup == null || dest == null) {
      debugPrint(
        '[SUGGESTION_TAP][route] missing coords pickup=$pickup dest=$dest '
        'canBook=$_canBook',
      );
      setState(() {
        _routeOverview = null;
        _routeError = null;
      });
      _logCtaState('route:missing-coords');
      return;
    }
    debugPrint(
      '[SUGGESTION_TAP][route] fetching preview pickup=$pickup dest=$dest',
    );
    setState(() {
      _loadingRoutePreview = true;
      _routeError = null;
    });
    try {
      final overview = await _routingService.fetchRoute(
        pickup,
        dest,
      );
      if (!mounted) return;
      if (overview == null) {
        setState(() {
          _routeOverview = null;
          _loadingRoutePreview = false;
          _routeError = 'Không tính được tuyến đường';
        });
        debugPrint('[SUGGESTION_TAP][route] preview null from service');
        return;
      }
      setState(() {
        _routeOverview = overview;
        _loadingRoutePreview = false;
      });
      debugPrint(
        '[SUGGESTION_TAP][route] preview ready '
        'distance=${overview.formattedDistance} ETA=${overview.formattedEta}',
      );
      _logCtaState('route:ready');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeOverview = null;
        _loadingRoutePreview = false;
        _routeError = 'Không tính được tuyến đường';
      });
      debugPrint('[SUGGESTION_TAP][route] error $e');
    }
  }

  void _handlePrimaryAction(_HomeSnapshot snapshot) {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bạn muốn đến đâu? Hãy nhập điểm đến trước nhé.')),
      );
      return;
    }
    if (_pickupLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn vị trí hợp lệ từ gợi ý.')),
      );
      return;
    }

    final pickup = _pickupController.text.trim().isEmpty
        ? 'Vị trí hiện tại của bạn'
        : _pickupController.text.trim();
    final service =
        _serviceOptions.firstWhere((s) => s.id == _selectedServiceId);
    final scheduleText = _scheduleEnabled && _scheduledAt != null
        ? _formatSchedule(_scheduledAt!)
        : 'Ngay lập tức';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow('Dịch vụ', service.title, icon: service.icon),
              _buildSummaryRow('Điểm đón', pickup,
                  icon: Icons.radio_button_checked),
              _buildSummaryRow('Điểm đến', destination,
                  icon: Icons.location_on),
              _buildSummaryRow('Thời gian', scheduleText, icon: Icons.schedule),
              if (_loadingRoutePreview)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              else if (_routeOverview != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow(
                      'Quãng đường',
                      '${_routeOverview!.formattedDistance} • ETA ${_routeOverview!.formattedEta}',
                      icon: Icons.alt_route,
                    ),
                    if (_routeOverview!.isApproximate)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Đang dùng quãng đường ước tính do dịch vụ định tuyến tạm gián đoạn.',
                          style: TextStyle(
                              color: Colors.orange[700], fontSize: 12),
                        ),
                      ),
                  ],
                )
              else if (_routeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _routeError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_appliedPromotion != null)
                _buildSummaryRow(
                  'Ưu đãi',
                  '${_appliedPromotion!.code} • ${_appliedPromotion!.title}',
                  icon: Icons.card_giftcard,
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isBooking || !_canBook
                    ? null
                    : () => _bookTrip(
                          sheetContext,
                          service: service,
                          pickup: pickup,
                          destination: destination,
                          scheduleText: scheduleText,
                          pickupPlace: _pickupPlace!,
                          destinationPlace: _destinationPlace!,
                          promotionCode: _appliedPromotion?.code,
                        ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF667EEA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Xác nhận đặt chuyến',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
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
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
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
    setState(() {
      switch (action.id) {
        case 'popular-uit':
          _setDestinationText(
            'Cổng chính Đại học UIT',
            suppressOnChanged: false,
          );
          _destinationPlace = null;
          _destinationLatLng = null;
          break;
        case 'home-trip':
          _setPickupText(
            '12 Võ Oanh, Bình Thạnh',
            suppressOnChanged: false,
          );
          _setDestinationText(
            'UIT, Linh Trung, Thủ Đức',
            suppressOnChanged: false,
          );
          _pickupPlace = null;
          _destinationPlace = null;
          _pickupLatLng = null;
          _destinationLatLng = null;
          break;
        case 'express':
          _selectService('express');
          _setDestinationText(
            'Bưu cục UIT-Express, Q.Thủ Đức',
            suppressOnChanged: false,
          );
          _destinationPlace = null;
          _destinationLatLng = null;
          break;
        case 'support':
          break;
      }
      _routeOverview = null;
      _routeError = null;
    });
    if (action.id == 'support') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Chúng tôi sẽ kết nối bạn với tổng đài trong giây lát.')),
      );
    }
  }

  void _showSavedPlaceSheet(SavedPlaceModel place) {
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
                child: Icon(_savedPlaceIcon(place),
                    color: const Color(0xFF667EEA)),
              ),
              title: Text(place.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(place.address),
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.radio_button_checked, color: Colors.green),
              title: const Text('Chọn làm điểm đón'),
              onTap: () {
                _applySavedPlace(place, isPickup: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFFFF6B6B)),
              title: const Text('Chọn làm điểm đến'),
              onTap: () {
                _applySavedPlace(place, isPickup: false);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applySavedPlace(SavedPlaceModel place, {required bool isPickup}) {
    final suggestion = PlaceSuggestion(
      name: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    setState(() {
      if (isPickup) {
        _pickupPlace = suggestion;
        _pickupLatLng = LatLng(place.latitude, place.longitude);
        _setPickupText(suggestion.displayName);
      } else {
        _destinationPlace = suggestion;
        _destinationLatLng = LatLng(place.latitude, place.longitude);
        _setDestinationText(suggestion.displayName);
      }
    });
    _tryLoadRouteOverview();
  }

  void _onPromoCodeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _applyPromotionCode({String? code}) {
    final availablePromos = _currentPromotions;
    final raw = (code ?? _promoCodeController.text).trim();
    if (raw.isEmpty) {
      setState(() {
        _promoError = 'Vui lòng nhập mã ưu đãi.';
        _appliedPromotion = null;
      });
      return;
    }
    if (availablePromos.isEmpty) {
      setState(() {
        _promoError = 'Hiện chưa có ưu đãi khả dụng.';
        _appliedPromotion = null;
      });
      return;
    }
    final normalized = raw.toUpperCase();
    PromotionBanner? matched;
    for (final promo in availablePromos) {
      if (promo.code.trim().toUpperCase() == normalized) {
        matched = promo;
        break;
      }
    }
    if (matched == null) {
      setState(() {
        _promoError = 'Mã không hợp lệ hoặc đã hết hạn.';
        _appliedPromotion = null;
      });
      return;
    }
    final applied = matched;
    setState(() {
      _appliedPromotion = applied;
      _promoError = null;
      _promoCodeController.text = applied.code;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã áp dụng mã ${applied.code}')),
    );
  }

  void _clearPromotion() {
    setState(() {
      _appliedPromotion = null;
      _promoError = null;
      _promoCodeController.clear();
    });
  }

  Future<void> _bookTrip(
    BuildContext sheetContext, {
    required _ServiceOption service,
    required String pickup,
    required String destination,
    required String scheduleText,
    required PlaceSuggestion pickupPlace,
    required PlaceSuggestion destinationPlace,
    String? promotionCode,
  }) async {
    if (_isBooking) return;
    setState(() {
      _isBooking = true;
    });

    try {
      final trip = await _tripService.createTrip(
        originText: pickup,
        destText: destination,
        serviceId: service.id,
        originLat: pickupPlace.latitude,
        originLng: pickupPlace.longitude,
        destLat: destinationPlace.latitude,
        destLng: destinationPlace.longitude,
        promotionCode: promotionCode,
      );

      if (!mounted) return;

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      setState(() {
        _activeTrip = trip;
        _liveStatus = trip.status;
        _liveLocation = trip.lastLocation;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Đặt chuyến thành công! Mã chuyến: ${trip.id} • $scheduleText'),
        ),
      );

      // Dùng push để giữ lịch sử điều hướng, giúp người dùng có nút back
      // quay về màn hình trước.
      context.pushNamed(
        AppRouteNames.tripTracking,
        pathParameters: {'id': trip.id},
        extra: trip,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đặt chuyến thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
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
      initialTime: TimeOfDay.fromDateTime(
          _scheduledAt ?? now.add(const Duration(minutes: 20))),
    );
    if (!mounted) return;
    if (time == null) return;
    final scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
          final hasData =
              snapshot.connectionState == ConnectionState.done && data != null;
          final canBook = hasData && _canBook;
          final resolvedData = data;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: FloatingActionButton.extended(
                onPressed: canBook && resolvedData != null
                    ? () => _handlePrimaryAction(resolvedData)
                    : null,
                backgroundColor:
                    canBook ? const Color(0xFF667EEA) : Colors.grey[400],
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
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshHome,
        child: ListView(
          key: const ValueKey('homeListView'),
          controller: _scrollController,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeroSection(snapshot),
            if (_activeTrip != null) _buildLiveTripCard(),
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
    );
  }

  Widget _buildHeroSection(_HomeSnapshot snapshot) {
    return Container(
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
      child: Column(
        children: [
          const SizedBox(height: 18),
          _buildHeader(snapshot),
          _buildWalletAndPoints(snapshot),
          _buildSearchCard(snapshot),
          const SizedBox(height: 28),
        ],
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
    final unreadCount = _unreadNotifications.clamp(0, 999);
    final hasUnread = unreadCount > 0;
    final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';
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
                    Icon(Icons.verified_outlined,
                        size: 18, color: Colors.white),
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
                icon: const Icon(Icons.notifications_none,
                    color: Colors.white, size: 28),
                onPressed: _openNotifications,
              ),
              if (hasUnread)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        badgeLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
    return Consumer<WalletNotifier>(
      builder: (context, notifier, _) {
        final wallet = notifier.summary ?? snapshot.wallet;
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
                    const Text('UITGo Pay',
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatCurrency(wallet.balance)} đ',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _openWalletPage,
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
                    const Text('Điểm thưởng',
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(
                      '${wallet.rewardPoints}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text('Đổi km miễn phí',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveTripCard() {
    final trip = _activeTrip;
    if (trip == null) {
      return const SizedBox.shrink();
    }
    final status = (_liveStatus ?? trip.status).toLowerCase();
    final location = _liveLocation ?? trip.lastLocation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.directions_bike,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chuyến của bạn',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trip.originText} → ${trip.destText}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                _buildStatusChipFromString(status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: Color(0xFF667EEA)),
                const SizedBox(width: 6),
                Text(
                  'Khởi tạo: ${_formatSchedule(trip.createdAt.toLocal())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.my_location,
                      size: 16, color: Color(0xFF38B000)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tài xế gần đây: ${_formatLocation(location)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Mã chuyến: ${trip.id}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(_HomeSnapshot snapshot) {
    final selectedService =
        _serviceOptions.firstWhere((s) => s.id == _selectedServiceId);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selectedService.icon,
                        color: const Color(0xFF667EEA), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      selectedService.title,
                      style: const TextStyle(
                          color: Color(0xFF667EEA),
                          fontWeight: FontWeight.w600),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF667EEA)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              service.badge!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF667EEA)
                                    : const Color(0xFF667EEA),
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
            fieldKey: _pickupFieldKey,
            layerLink: _pickupLayerLink,
            controller: _pickupController,
            icon: Icons.radio_button_checked,
            hintText: 'Điểm đón',
            color: const Color(0xFF38B000),
            focusNode: _pickupFocus,
            onChanged: _onPickupChanged,
            isSearching: _searchingPickup,
            inputKey: const Key('pickupInput'),
            isPickupField: true,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _pickupController.clear();
                  _pickupPlace = null;
                  _pickupLatLng = null;
                  _pickupSuggestions = const [];
                  _routeOverview = null;
                  _routeError = null;
                });
                _removePickupOverlay();
              },
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          _buildLocationField(
            fieldKey: _destinationFieldKey,
            layerLink: _destinationLayerLink,
            controller: _destinationController,
            icon: Icons.location_on,
            hintText: 'Bạn muốn đến đâu?',
            color: const Color(0xFFFF6B6B),
            focusNode: _destinationFocus,
            onChanged: _onDestinationChanged,
            isSearching: _searchingDestination,
            inputKey: const Key('destinationInput'),
            isPickupField: false,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _destinationController.clear();
                  _destinationPlace = null;
                  _destinationLatLng = null;
                  _destinationSuggestions = const [];
                  _routeOverview = null;
                  _routeError = null;
                });
                _removeDestinationOverlay();
              },
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingRoutePreview)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (_routeOverview != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alt_route, color: Color(0xFF667EEA)),
                      const SizedBox(width: 8),
                      Text(
                        '${_routeOverview!.formattedDistance} • ETA ${_routeOverview!.formattedEta}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667EEA)),
                      ),
                    ],
                  ),
                  if (_routeOverview!.isApproximate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Đang hiển thị quãng đường ước tính vì dịch vụ bản đồ tạm gián đoạn.',
                        style:
                            TextStyle(color: Colors.orange[700], fontSize: 12),
                      ),
                    ),
                ],
              ),
            )
          else if (_routeError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _routeError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final currentPickup = _pickupController.text;
                  setState(() {
                    _setPickupText(
                      _destinationController.text,
                      suppressOnChanged: true,
                    );
                    _setDestinationText(
                      currentPickup,
                      suppressOnChanged: true,
                    );
                    final temp = _pickupPlace;
                    _pickupPlace = _destinationPlace;
                    _destinationPlace = temp;
                    final tempLat = _pickupLatLng;
                    _pickupLatLng = _destinationLatLng;
                    _destinationLatLng = tempLat;
                  });
                  _tryLoadRouteOverview();
                },
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                label: const Text('Đổi vị trí'),
                style: ElevatedButton.styleFrom(
                  // Override global theme minimumSize to avoid infinite width in Row
                  minimumSize: const Size(0, 40),
                  backgroundColor:
                      const Color(0xFF667EEA).withValues(alpha: 0.08),
                  foregroundColor: const Color(0xFF667EEA),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
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
                          const Text('Đặt lịch',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          if (_scheduleEnabled && _scheduledAt != null)
                            Text(
                              _formatSchedule(_scheduledAt!),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
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
                    avatar: Icon(_savedPlaceIcon(place),
                        size: 18, color: Colors.grey[700]),
                    onPressed: () => _showSavedPlaceSheet(place),
                    backgroundColor: Colors.grey[100],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildPromotionInput(snapshot),
        ],
      ),
    );
  }

  Widget _buildPromotionInput(_HomeSnapshot snapshot) {
    final quickPromos = snapshot.promotions.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ưu đãi & mã giảm giá',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoCodeController,
                decoration: InputDecoration(
                  hintText: 'Nhập mã ưu đãi (ví dụ UITNEW)',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _appliedPromotion != null ||
                          (_promoCodeController.text.isNotEmpty)
                      ? IconButton(
                          tooltip: 'Xóa mã',
                          icon: const Icon(Icons.close),
                          onPressed: _clearPromotion,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => _applyPromotionCode(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _appliedPromotion != null ? 'Đã áp dụng' : 'Áp dụng',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (_promoError != null) ...[
          const SizedBox(height: 6),
          Text(
            _promoError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        if (_appliedPromotion != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF38B000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Color(0xFF38B000)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_appliedPromotion!.code} • ${_appliedPromotion!.title}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _clearPromotion,
                  child: const Text('Gỡ'),
                ),
              ],
            ),
          ),
        ],
        if (quickPromos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickPromos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final promo = quickPromos[index];
                final selectedCode =
                    (_appliedPromotion?.code ?? '').toUpperCase();
                final promoCodeUpper = promo.code.toUpperCase();
                final selected = selectedCode == promoCodeUpper;
                return ChoiceChip(
                  label: Text(promo.code),
                  selected: selected,
                  onSelected: (_) => _applyPromotionCode(code: promo.code),
                  selectedColor:
                      const Color(0xFF667EEA).withValues(alpha: 0.15),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF667EEA)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            'Chưa có ưu đãi nổi bật, vui lòng quay lại sau.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationField({
    GlobalKey? fieldKey,
    required LayerLink layerLink,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required Color color,
    Widget? suffix,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    bool isSearching = false,
    Key? inputKey,
    required bool isPickupField,
  }) {
    return CompositedTransformTarget(
      link: layerLink,
      child: KeyedSubtree(
        key: ValueKey(isPickupField
            ? 'pickupFieldContainer'
            : 'destinationFieldContainer'),
        child: Container(
          key: fieldKey,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
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
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event.logicalKey == LogicalKeyboardKey.escape &&
                            event is KeyDownEvent) {
                          focusNode?.unfocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        key: inputKey,
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: hintText,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (suffix != null) suffix,
                ],
              ),
              if (isSearching) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
      ),
    );
  }

  OverlayEntry _buildSuggestionOverlay({
    required LayerLink link,
    required List<PlaceSuggestion> suggestions,
    required Color color,
    required ValueChanged<PlaceSuggestion> onSelect,
    required Size Function() fieldSizeResolver,
    required bool isPickup,
  }) {
    return OverlayEntry(
      builder: (context) {
        final fieldSize = fieldSizeResolver();
        final width = fieldSize.width > 0 ? fieldSize.width : 320.0;
        final verticalOffset =
            (fieldSize.height > 0 ? fieldSize.height : 56.0) + 8.0;
        final overlayWidth = MediaQuery.sizeOf(context).width;
        final normalizedWidth = width <= 0 || overlayWidth <= 0
            ? null
            : (width / overlayWidth).clamp(0.0, 1.0);
        return CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: Offset(0, verticalOffset),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) =>
                _setOverlayPointerInteraction(isPickup: isPickup, active: true),
            onPointerUp: (_) => _setOverlayPointerInteraction(
                isPickup: isPickup, active: false),
            onPointerCancel: (_) => _setOverlayPointerInteraction(
                isPickup: isPickup, active: false),
            child: PointerInterceptor(
              child: Align(
                alignment: Alignment.topLeft,
                widthFactor: normalizedWidth != null && normalizedWidth > 0
                    ? normalizedWidth
                    : null,
                child: SizedBox(
                  key: ValueKey(isPickup
                      ? 'pickupSuggestionsOverlay'
                      : 'destinationSuggestionsOverlay'),
                  width: width,
                  child: _buildSuggestionPanel(
                    suggestions: suggestions,
                    color: color,
                    onSelect: onSelect,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionPanel({
    required List<PlaceSuggestion> suggestions,
    required Color color,
    required ValueChanged<PlaceSuggestion> onSelect,
  }) {
    return Material(
      color: Colors.white,
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return InkWell(
              onTap: () {
                debugPrint(
                  '[SUGGESTION_TAP] onTap label="${suggestion.name}" '
                  'display="${suggestion.displayName}" index=$index',
                );
                onSelect(suggestion);
              },
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  suggestion.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: suggestion.address != null
                    ? Text(
                        suggestion.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                leading: Icon(Icons.place, color: color.withValues(alpha: 0.8)),
              ),
            );
          },
        ),
      ),
    );
  }

  Size _fieldSize(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return Size.zero;
    }
    return renderObject.size;
  }

  Size _resolveFieldSize({required bool isPickup}) {
    final key = isPickup ? _pickupFieldKey : _destinationFieldKey;
    final lastSize = isPickup ? _pickupFieldSize : _destinationFieldSize;
    final measured = _fieldSize(key);
    if (measured != Size.zero) {
      if (isPickup) {
        _pickupFieldSize = measured;
      } else {
        _destinationFieldSize = measured;
      }
      return measured;
    }
    return lastSize;
  }

  void _showPickupOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _pickupOverlayEntry?.remove();
    final size = _resolveFieldSize(isPickup: true);
    final widthLog = size.width > 0 ? size.width : 360.0;
    final offsetLog = (size.height > 0 ? size.height : 56.0) + 8.0;
    debugPrint(
        '[SUGGESTION_TAP][pickup] show overlay width=$widthLog offset=$offsetLog');
    _pickupOverlayEntry = _buildSuggestionOverlay(
      link: _pickupLayerLink,
      suggestions: _pickupSuggestions,
      color: const Color(0xFF38B000),
      onSelect: _selectPickupSuggestion,
      fieldSizeResolver: () => _resolveFieldSize(isPickup: true),
      isPickup: true,
    );
    overlay.insert(_pickupOverlayEntry!);
  }

  void _removePickupOverlay() {
    if (_pickupOverlayEntry != null) {
      debugPrint('[SUGGESTION_TAP][pickup] removing overlay');
      _pickupOverlayEntry?.remove();
      _pickupOverlayEntry = null;
      _interactingWithPickupOverlay = false;
    }
  }

  void _showDestinationOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _destinationOverlayEntry?.remove();
    final size = _resolveFieldSize(isPickup: false);
    final widthLog = size.width > 0 ? size.width : 360.0;
    final offsetLog = (size.height > 0 ? size.height : 56.0) + 8.0;
    debugPrint(
        '[SUGGESTION_TAP][destination] show overlay width=$widthLog offset=$offsetLog');
    _destinationOverlayEntry = _buildSuggestionOverlay(
      link: _destinationLayerLink,
      suggestions: _destinationSuggestions,
      color: const Color(0xFFFF6B6B),
      onSelect: _selectDestinationSuggestion,
      fieldSizeResolver: () => _resolveFieldSize(isPickup: false),
      isPickup: false,
    );
    overlay.insert(_destinationOverlayEntry!);
  }

  void _removeDestinationOverlay() {
    if (_destinationOverlayEntry != null) {
      debugPrint('[SUGGESTION_TAP][destination] removing overlay');
      _destinationOverlayEntry?.remove();
      _destinationOverlayEntry = null;
      _interactingWithDestinationOverlay = false;
    }
  }

  Widget _buildSavedPlaces(_HomeSnapshot snapshot) {
    final places = snapshot.savedPlaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              const Text(
                'Địa điểm yêu thích',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.pushNamed(AppRouteNames.savedPlaces),
                child: const Text('Quản lý'),
              ),
            ],
          ),
        ),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lưu địa điểm quen thuộc để đặt xe nhanh hơn.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.pushNamed(AppRouteNames.savedPlaces),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Thêm địa điểm'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 114,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final place = places[index];
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
                            Icon(_savedPlaceIcon(place),
                                color: const Color(0xFF667EEA)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          place.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSpacing = 14.0;
    final horizontalPadding = 20.0;
    // Two cards per row, balanced width.
    final cardWidth = (screenWidth - (horizontalPadding * 2) - cardSpacing) / 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tiện ích nhanh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: cardSpacing,
            runSpacing: cardSpacing,
            children: _quickActions.map((action) {
              return GestureDetector(
                onTap: () => _handleQuickAction(action),
                child: Container(
                  width: cardWidth.clamp(140.0, 220.0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                const Text('Chuyến đã đặt',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.pushNamed(AppRouteNames.tripHistory),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            if (trips.isEmpty)
              _buildEmptyState('Chưa có chuyến nào, đặt ngay để trải nghiệm.')
            else
              Column(
                children: trips
                    .map((trip) => _buildTripTile(trip, highlight: true))
                    .toList(),
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
            child: Text('Ưu đãi nổi bật',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: promotions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final promo = promotions[index];
                return SizedBox(
                  width: 300,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _showPromotionDetails(promo),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: promo.gradient),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  promo.gradient.last.withValues(alpha: 0.25),
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
                            Expanded(
                              child: Text(
                                promo.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    promo.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF667EEA),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  promo.expiryLabel,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _applyPromotionCode(code: promo.code),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.local_offer, size: 16),
                                  label: const Text('Dùng mã này'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Sao chép mã',
                                  onPressed: () => _copyPromoCode(promo.code),
                                  icon: const Icon(Icons.copy,
                                      size: 18, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _copyPromoCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép mã $code')),
    );
  }

  Future<void> _showPromotionDetails(PromotionBanner promo) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
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
                  promo.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  promo.description,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667EEA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          promo.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nhập mã này ở bước thanh toán.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  promo.expiryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Áp dụng khi đặt chuyến bằng UITGo Pay.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _copyPromoCode(promo.code);
                      if (Navigator.of(sheetContext).canPop()) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text(
                      'Sao chép & đóng',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        );
      },
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
                const Text('Chuyến gần đây',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.pushNamed(AppRouteNames.tripHistory),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            if (trips.isEmpty)
              _buildEmptyState(
                  'Bạn chưa thực hiện chuyến đi nào. Khám phá UITGo ngay!')
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
          const Text('Tin tức UITGo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                    child:
                        Icon(_newsIcon(item), color: const Color(0xFF667EEA)),
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
                          item.body,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.timeAgo(),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
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

  Widget _buildTripTile(TripDetail trip, {bool highlight = false}) {
    final service = _serviceOptions.firstWhere((s) => s.id == trip.serviceId,
        orElse: () => _serviceOptions.first);
    final createdAt = trip.createdAt.toLocal();
    final status = trip.status;
    final isTrackable = !_isTerminalStatus(status);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF667EEA).withValues(alpha: 0.05)
            : Colors.grey[50],
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
                    Text(service.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_formatSchedule(createdAt),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              _buildStatusChipFromString(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.radio_button_checked,
                  size: 16, color: Color(0xFF38B000)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.originText,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.flag, size: 16, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.destText,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.confirmation_number,
                  size: 16, color: Color(0xFF667EEA)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.id,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              if (isTrackable)
                TextButton(
                  onPressed: () => context.pushNamed(
                    AppRouteNames.tripTracking,
                    pathParameters: {'id': trip.id},
                    extra: trip,
                  ),
                  child: const Text('Theo dõi'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChipFromString(String status) {
    final color = _statusColorFromBackend(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _statusLabelFromBackend(status),
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  IconData _savedPlaceIcon(SavedPlaceModel place) {
    final name = place.name.toLowerCase();
    if (name.contains('nhà') || name.contains('home')) {
      return Icons.home_rounded;
    }
    if (name.contains('uit') || name.contains('trường')) {
      return Icons.school_rounded;
    }
    if (name.contains('công ty') || name.contains('office')) {
      return Icons.business_rounded;
    }
    return Icons.location_on_rounded;
  }

  IconData _newsIcon(HomeNewsItem item) {
    switch (item.icon.toLowerCase()) {
      case 'shield':
      case 'safety':
        return Icons.shield_outlined;
      case 'two_wheeler':
      case 'bike':
        return Icons.two_wheeler;
      case 'gift':
      case 'promo':
        return Icons.card_giftcard;
      default:
        return Icons.campaign_outlined;
    }
  }

  bool _isTerminalStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'completed' || normalized == 'cancelled';
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
    final rootContext = context;
    const menuItems = [
      _MenuItemData(
        icon: Icons.person_outline,
        title: 'Thông tin cá nhân',
        routeName: AppRouteNames.profile,
      ),
      _MenuItemData(
        icon: Icons.history,
        title: 'Lịch sử chuyến đi',
        routeName: AppRouteNames.tripHistory,
      ),
      _MenuItemData(
        icon: Icons.payment,
        title: 'Ví & Thanh toán',
        routeName: AppRouteNames.payments,
      ),
      _MenuItemData(
        icon: Icons.location_on_outlined,
        title: 'Địa điểm đã lưu',
        routeName: AppRouteNames.savedPlaces,
      ),
      _MenuItemData(
        icon: Icons.settings_outlined,
        title: 'Cài đặt',
        routeName: AppRouteNames.settings,
      ),
      _MenuItemData(
        icon: Icons.help_outline,
        title: 'Trợ giúp & Hỗ trợ',
        routeName: AppRouteNames.help,
      ),
      _MenuItemData(
        icon: Icons.logout,
        title: 'Đăng xuất',
        color: Color(0xFFEF5350),
      ),
    ];

    showModalBottomSheet(
      context: rootContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
            for (final item in menuItems) ...[
              _buildMenuItem(
                icon: item.icon,
                title: item.title,
                color: item.color,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (item.routeName != null) {
                    rootContext.pushNamed(item.routeName!);
                  } else {
                    await _logout();
                  }
                },
              ),
              if (item != menuItems.last) const Divider(height: 1),
            ],
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

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.title,
    this.routeName,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? routeName;
  final Color? color;
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.riderName,
    required this.wallet,
    required this.savedPlaces,
    required this.promotions,
    required this.upcomingTrips,
    required this.recentTrips,
    required this.news,
  });

  final String riderName;
  final WalletSummary wallet;
  final List<SavedPlaceModel> savedPlaces;
  final List<PromotionBanner> promotions;
  final List<TripDetail> upcomingTrips;
  final List<TripDetail> recentTrips;
  final List<HomeNewsItem> news;
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

String _formatSchedule(DateTime time) {
  final day = time.day.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$day/$month • $hour:$minute';
}

String _formatLocation(LocationUpdate update) {
  final lat = update.latitude.toStringAsFixed(5);
  final lng = update.longitude.toStringAsFixed(5);
  return '$lat, $lng';
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

String _statusLabelFromBackend(String status) {
  switch (status.toLowerCase()) {
    case 'requested':
      return 'Đang yêu cầu';
    case 'accepted':
      return 'Đã nhận chuyến';
    case 'arriving':
      return 'Tài xế đang tới';
    case 'in_ride':
      return 'Đang di chuyển';
    case 'completed':
      return 'Hoàn thành';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return status;
  }
}

Color _statusColorFromBackend(String status) {
  switch (status.toLowerCase()) {
    case 'requested':
      return const Color(0xFF667EEA);
    case 'accepted':
      return const Color(0xFF11998E);
    case 'arriving':
      return const Color(0xFFFFA751);
    case 'in_ride':
      return const Color(0xFF764BA2);
    case 'completed':
      return const Color(0xFF38EF7D);
    case 'cancelled':
      return const Color(0xFFFF6B6B);
    default:
      return Colors.grey;
  }
}
