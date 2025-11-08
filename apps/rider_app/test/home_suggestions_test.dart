import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:rider_app/features/home/home_page.dart';
import 'package:rider_app/features/home/models/home_models.dart';
import 'package:rider_app/features/home/services/home_service.dart' as home_svc;
import 'package:rider_app/features/notifications/models/notification_model.dart';
import 'package:rider_app/features/notifications/services/notification_service.dart'
    as notif_svc;
import 'package:rider_app/features/places/models/place_suggestion.dart';
import 'package:rider_app/features/places/services/geocoding_service.dart'
    as geo_svc;
import 'package:rider_app/features/trip/models/trip_models.dart';
import 'package:rider_app/features/trip/services/trip_service.dart' as trip_svc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Stub HomeService endpoints to avoid network.
    home_svc.debugFetchWallet = () async => WalletSummary(
          balance: 0,
          rewardPoints: 0,
        );
    home_svc.debugFetchSavedPlaces = () async => <SavedPlaceModel>[];
    home_svc.debugFetchPromotions = () async => <PromotionBanner>[];
    home_svc.debugFetchNews = ({int limit = 5}) async => <HomeNewsItem>[];

    // Stub notifications to zero unread.
    notif_svc.debugListNotifications = ({
      bool unreadOnly = true,
      int limit = 20,
      int offset = 0,
    }) async => NotificationPageResult(
          items: const <AppNotification>[],
          total: 0,
          limit: limit,
          offset: offset,
        );

    // Stub trips list.
    trip_svc.debugListTrips = ({
      required String role,
      int limit = 20,
      int offset = 0,
      int? page,
      int? pageSize,
    }) async => PagedTrips(
          items: const <TripDetail>[],
          total: 0,
          limit: limit,
          offset: offset,
        );
  });

  tearDown(() {
    // Clear debug hooks between tests.
    home_svc.debugFetchWallet = null;
    home_svc.debugFetchSavedPlaces = null;
    home_svc.debugFetchPromotions = null;
    home_svc.debugFetchNews = null;
    notif_svc.debugListNotifications = null;
    trip_svc.debugListTrips = null;
    geo_svc.debugSearch = null;
  });

  Future<void> _pumpHome(WidgetTester tester) async {
    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(1280, 1024);
    binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage(debugStartReady: true)));
    // Wait until the destination input appears.
    final finder = find.byKey(const Key('destinationInput'));
    for (var i = 0; i < 30; i++) {
      if (finder.evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsOneWidget);
  }

  TextEditingController _controllerOf(
    WidgetTester tester,
    Finder field,
  ) {
    final textField = tester.widget<TextField>(field);
    final controller = textField.controller;
    expect(controller, isNotNull, reason: 'TextField must expose a controller');
    return controller!;
  }

  Future<void> _tapSuggestion(
    WidgetTester tester,
    String label,
  ) async {
    final suggestionFinder = find.text(label);
    await tester.ensureVisible(suggestionFinder);
    await tester.pump();
    await tester.tap(suggestionFinder);
  }

  Future<void> _typeDestination(
    WidgetTester tester,
    String query,
  ) async {
    final destField = find.byKey(const Key('destinationInput'));
    await tester.enterText(destField, query);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Selecting Tây Ninh commits label, sets coords and closes overlay',
      (tester) async {
    int geocodeCalls = 0;
    geo_svc.debugSearch = (rawQuery, {LatLng? proximity}) async {
      geocodeCalls++;
      final q = rawQuery.toLowerCase();
      if (q.contains('tây') || q.contains('tay')) {
        return const [
          PlaceSuggestion(
            name: 'Tây Ninh',
            latitude: 11.3101,
            longitude: 106.0983,
          )
        ];
      }
      return const [];
    };

    // runtime logs are not asserted in headless tests to avoid altering
    // Flutter foundation debug globals. We still assert behavior via state.

    await _pumpHome(tester);

    // Enter prefix into destination field (2nd TextField), trigger debounce.
    final destField = find.byKey(const Key('destinationInput'));
    await tester.enterText(destField, 'tây');
    await tester.pump(const Duration(milliseconds: 400));

    // Tap the suggestion row.
    await _tapSuggestion(tester, 'Tây Ninh');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    // Assert controller text is full label.
    final destController = _controllerOf(tester, destField);
    expect(destController.text, equals('Tây Ninh'));

    // Assert overlay closed (no suggestion tile remains).
    expect(find.widgetWithText(ListTile, 'Tây Ninh'), findsNothing);

    // No extra geocode call on commit beyond the initial one.
    expect(geocodeCalls, equals(1));

    // CTA enabled when both coords exist (pickup has default coords in init).
    final fab = find.byType(FloatingActionButton);
    final fabWidget = tester.widget<FloatingActionButton>(fab);
    expect(fabWidget.onPressed, isNotNull);

    // onChanged may not fire in this headless test after programmatic write.
  });

  testWidgets('Selecting Gò Dầu commits label with accents and closes overlay',
      (tester) async {
    int geocodeCalls = 0;
    geo_svc.debugSearch = (rawQuery, {LatLng? proximity}) async {
      geocodeCalls++;
      final q = rawQuery.toLowerCase();
      if (q.contains('gò') || q.contains('go')) {
        return const [
          PlaceSuggestion(
            name: 'Gò Dầu',
            latitude: 11.0255,
            longitude: 106.2748,
          )
        ];
      }
      return const [];
    };

    // No debugPrint capture in headless tests.

    await _pumpHome(tester);

    // Enter prefix into destination field (2nd TextField), trigger debounce.
    final destField = find.byKey(const Key('destinationInput'));
    await tester.enterText(destField, 'gò');
    await tester.pump(const Duration(milliseconds: 400));

    // Tap the suggestion row.
    await _tapSuggestion(tester, 'Gò Dầu');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    // Assert controller text is full label with accents preserved.
    final destController = _controllerOf(tester, destField);
    expect(destController.text, equals('Gò Dầu'));
    expect(destController.selection.isCollapsed, isTrue);
    expect(destController.selection.extentOffset, equals(destController.text.length));
    expect(destController.value.composing.isValid, isFalse);

    // Overlay removed.
    expect(find.widgetWithText(ListTile, 'Gò Dầu'), findsNothing);

    // No extra geocode call on commit.
    expect(geocodeCalls, equals(1));

    // No further assertions on logs in headless test.
  });

  testWidgets('Selecting label with comma commits entire display string',
      (tester) async {
    int geocodeCalls = 0;
    geo_svc.debugSearch = (rawQuery, {LatLng? proximity}) async {
      geocodeCalls++;
      final q = rawQuery.toLowerCase();
      if (q.contains('whis')) {
        return const [
          PlaceSuggestion(
            name: 'Whisky a Go Go',
            latitude: 34.0903,
            longitude: -118.3858,
            address: 'Los Angeles, California',
          ),
        ];
      }
      return const [];
    };

    await _pumpHome(tester);

    final destField = find.byKey(const Key('destinationInput'));
    await tester.enterText(destField, 'whis');
    await tester.pump(const Duration(milliseconds: 400));

    await _tapSuggestion(tester, 'Whisky a Go Go');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    final destController = _controllerOf(tester, destField);
    expect(
      destController.text,
      equals('Whisky a Go Go, Los Angeles, California'),
    );
    expect(destController.selection.isCollapsed, isTrue);
    expect(destController.selection.extentOffset,
        equals(destController.text.length));
    expect(destController.value.composing.isValid, isFalse);
    expect(geocodeCalls, equals(1));
  });

  testWidgets('Suggestion commit clears any composing range for IME',
      (tester) async {
    int geocodeCalls = 0;
    geo_svc.debugSearch = (rawQuery, {LatLng? proximity}) async {
      geocodeCalls++;
      final q = rawQuery.toLowerCase();
      if (q.contains('gò') || q.contains('go')) {
        return const [
          PlaceSuggestion(
            name: 'Gò Dầu',
            latitude: 11.0255,
            longitude: 106.2748,
          )
        ];
      }
      return const [];
    };

    await _pumpHome(tester);

    final destField = find.byKey(const Key('destinationInput'));
    await tester.enterText(destField, 'gò');
    await tester.pump(const Duration(milliseconds: 400));

    final destController = _controllerOf(tester, destField);
    destController.value = destController.value.copyWith(
      composing: const TextRange(start: 0, end: 2),
    );
    expect(destController.value.composing.isValid, isTrue);

    await tester.pump(); // process widget updates without letting debounce fire again

    await _tapSuggestion(tester, 'Gò Dầu');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(destController.text, equals('Gò Dầu'));
    expect(destController.selection.isCollapsed, isTrue);
    expect(destController.selection.extentOffset,
        equals(destController.text.length));
    expect(destController.value.composing.isValid, isFalse);
    expect(geocodeCalls, equals(1));
  });

  testWidgets('Destination overlay anchors directly under the input field',
      (tester) async {
    geo_svc.debugSearch = (rawQuery, {LatLng? proximity}) async {
      final q = rawQuery.toLowerCase();
      if (q.contains('gò') || q.contains('go')) {
        return const [
          PlaceSuggestion(
            name: 'Gò Dầu',
            latitude: 11.0255,
            longitude: 106.2748,
          )
        ];
      }
      return const [];
    };

    await _pumpHome(tester);
    await _typeDestination(tester, 'gò');

    final fieldRect =
        tester.getRect(find.byKey(const ValueKey('destinationFieldContainer')));
    final overlayFinder =
        find.byKey(const ValueKey('destinationSuggestionsOverlay'));
    expect(overlayFinder, findsOneWidget);
    final overlayRect = tester.getRect(overlayFinder);

    expect((overlayRect.left - fieldRect.left).abs(), lessThan(2.0));
    expect((overlayRect.width - fieldRect.width).abs(), lessThan(2.0));
    final gap = overlayRect.top - fieldRect.bottom;
    expect(gap, closeTo(8, 2));
  });

  testWidgets('Destination overlay realigns after window resize', (tester) async {
    geo_svc.debugSearch = (rawQuery, {LatLng? proximity}) async {
      final q = rawQuery.toLowerCase();
      if (q.contains('gò') || q.contains('go')) {
        return const [
          PlaceSuggestion(
            name: 'Gò Dầu',
            latitude: 11.0255,
            longitude: 106.2748,
          )
        ];
      }
      return const [];
    };

    await _pumpHome(tester);
    await _typeDestination(tester, 'gò');

    final overlayFinder =
        find.byKey(const ValueKey('destinationSuggestionsOverlay'));
    expect(overlayFinder, findsOneWidget);
    final initialRect = tester.getRect(overlayFinder);
    final fieldFinder =
        find.byKey(const ValueKey('destinationFieldContainer'));
    final initialFieldRect = tester.getRect(fieldFinder);
    final initialGap = initialRect.top - initialFieldRect.bottom;
    expect(initialGap, closeTo(8, 2));

    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(1024, 900);
    binding.handleMetricsChanged();
    await tester.pumpAndSettle();

    final updatedFieldRect = tester.getRect(fieldFinder);
    final updatedRect = tester.getRect(overlayFinder);
    final leftDiff = (updatedRect.left - updatedFieldRect.left).abs();
    final widthDiff = (updatedRect.width - updatedFieldRect.width).abs();
    expect(leftDiff, lessThan(2.0));
    expect(widthDiff, lessThan(2.0));
    final updatedGap = updatedRect.top - updatedFieldRect.bottom;
    expect(updatedGap, closeTo(8, 2));
  });
}
