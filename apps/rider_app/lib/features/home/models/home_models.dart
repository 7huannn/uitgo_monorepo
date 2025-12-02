import 'package:flutter/material.dart';

class WalletSummary {
  WalletSummary({
    required this.balance,
    required this.rewardPoints,
    this.updatedAt,
  });

  final int balance;
  final int rewardPoints;
  final DateTime? updatedAt;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class SavedPlaceModel {
  SavedPlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SavedPlaceModel.fromJson(Map<String, dynamic> json) {
    return SavedPlaceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PromotionBanner {
  PromotionBanner({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.gradientStart,
    required this.gradientEnd,
    required this.priority,
    this.imageUrl,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String description;
  final String code;
  final String gradientStart;
  final String gradientEnd;
  final int priority;
  final String? imageUrl;
  final DateTime? expiresAt;

  List<Color> get gradient => [
        _colorFromHex(gradientStart, const Color(0xFF667EEA)),
        _colorFromHex(gradientEnd, const Color(0xFF764BA2)),
      ];

  factory PromotionBanner.fromJson(Map<String, dynamic> json) {
    return PromotionBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      code: json['code'] as String? ?? '',
      gradientStart: json['gradientStart'] as String? ?? '#667EEA',
      gradientEnd: json['gradientEnd'] as String? ?? '#764BA2',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }

  String get expiryLabel {
    if (expiresAt == null) return 'Đang diễn ra';
    final date = expiresAt!;
    return 'HSD: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}

class HomeNewsItem {
  HomeNewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.icon,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String icon;
  final DateTime publishedAt;

  factory HomeNewsItem.fromJson(Map<String, dynamic> json) {
    return HomeNewsItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? '',
      icon: json['icon'] as String? ?? 'news',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String timeAgo() {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}

Color _colorFromHex(String input, Color fallback) {
  final hex = input.replaceAll('#', '');
  if (hex.length != 6 && hex.length != 8) {
    return fallback;
  }
  final buffer = StringBuffer();
  if (hex.length == 6) {
    buffer.write('FF');
  }
  buffer.write(hex.toUpperCase());
  final value = int.tryParse(buffer.toString(), radix: 16);
  if (value == null) {
    return fallback;
  }
  return Color(value);
}
