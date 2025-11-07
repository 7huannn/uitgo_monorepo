import 'package:flutter/material.dart';
import 'package:rider_app/core/widgets/feature_placeholder.dart';

class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Địa điểm đã lưu'),
      ),
      body: const FeaturePlaceholder(
        icon: Icons.location_on_outlined,
        message:
            'Bạn sẽ sớm lưu được nhà, cơ quan và các địa điểm yêu thích tại đây.',
      ),
    );
  }
}
