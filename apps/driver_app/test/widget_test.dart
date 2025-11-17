import 'package:driver_app/features/home/widgets/trip_card.dart';
import 'package:driver_app/features/trips/models/trip_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TripCard renders pickup and drop-off locations',
      (WidgetTester tester) async {
    final trip = TripDetail(
      id: 'trip-1',
      riderId: 'rider-1',
      serviceId: 'UIT-Bike',
      originText: 'UIT Campus A',
      destText: 'KTX Khu B',
      originLat: 10.87,
      originLng: 106.8,
      destLat: 10.88,
      destLng: 106.82,
      status: TripStatus.requested,
      createdAt: DateTime(2024, 7, 1, 8, 30),
      updatedAt: DateTime(2024, 7, 1, 8, 45),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCard(trip: trip),
        ),
      ),
    );

    expect(find.textContaining('UIT Campus A'), findsOneWidget);
    expect(find.textContaining('KTX Khu B'), findsOneWidget);
    expect(find.textContaining('Chờ xác nhận'), findsOneWidget);
  });
}
