import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum SpotCategory { walks, dogParks, treats }

extension SpotCategoryUi on SpotCategory {
  String get label => switch (this) {
    SpotCategory.walks => 'Walks',
    SpotCategory.dogParks => 'Dog parks',
    SpotCategory.treats => 'Treat stops',
  };

  String get heading => switch (this) {
    SpotCategory.walks => 'Leash-worthy walks',
    SpotCategory.dogParks => 'Top-rated dog parks',
    SpotCategory.treats => 'Treats nearby',
  };

  String get emptyMessage => switch (this) {
    SpotCategory.walks => 'No mapped walking paths were found nearby.',
    SpotCategory.dogParks => 'No mapped dog parks were found nearby.',
    SpotCategory.treats => 'No mapped pet-treat stops were found nearby.',
  };

  IconData get icon => switch (this) {
    SpotCategory.walks => Icons.directions_walk_rounded,
    SpotCategory.dogParks => Icons.pets_rounded,
    SpotCategory.treats => Icons.cookie_rounded,
  };
}

class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.distanceMiles,
    required this.description,
    required this.badges,
    this.communityRating,
    this.ratingCount = 0,
    this.isPreview = false,
  });

  final String id;
  final String name;
  final SpotCategory category;
  final LatLng location;
  final double distanceMiles;
  final String description;
  final List<String> badges;
  final double? communityRating;
  final int ratingCount;
  final bool isPreview;

  Spot copyWith({
    double? communityRating,
    int? ratingCount,
    double? distanceMiles,
  }) {
    return Spot(
      id: id,
      name: name,
      category: category,
      location: location,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      description: description,
      badges: badges,
      communityRating: communityRating ?? this.communityRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isPreview: isPreview,
    );
  }
}
