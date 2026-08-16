import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/spot.dart';

abstract interface class NearbyRepository {
  Future<List<Spot>> findNearby(LatLng center, SpotCategory category);
}

class OpenStreetMapNearbyRepository implements NearbyRepository {
  OpenStreetMapNearbyRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static final _endpoint = Uri.parse('https://overpass-api.de/api/interpreter');

  @override
  Future<List<Spot>> findNearby(LatLng center, SpotCategory category) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'Suppup/1.0 (com.josh.suppup)',
          },
          body: {'data': _query(center, category)},
        )
        .timeout(const Duration(seconds: 22));
    if (response.statusCode != 200) {
      throw NearbyException('The nearby map service is taking a break.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = payload['elements'] as List<dynamic>? ?? const [];
    final spots = <Spot>[];
    for (final rawElement in elements) {
      final element = Map<String, dynamic>.from(rawElement as Map);
      final tags = Map<String, dynamic>.from(
        element['tags'] as Map? ?? const {},
      );
      final centerData = Map<String, dynamic>.from(
        element['center'] as Map? ?? const {},
      );
      final latitude = (element['lat'] ?? centerData['lat']) as num?;
      final longitude = (element['lon'] ?? centerData['lon']) as num?;
      if (latitude == null || longitude == null) continue;

      final point = LatLng(latitude.toDouble(), longitude.toDouble());
      final distanceMeters = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        point.latitude,
        point.longitude,
      );
      spots.add(
        Spot(
          id: '${element['type']}-${element['id']}',
          name: _name(tags, category),
          category: category,
          location: point,
          distanceMiles: distanceMeters / 1609.344,
          description: _description(tags, category),
          badges: _badges(tags, category),
        ),
      );
    }

    return rankSpots(spots, category).take(20).toList();
  }

  String _query(LatLng center, SpotCategory category) {
    final around = 'around:8000,${center.latitude},${center.longitude}';
    final body = switch (category) {
      SpotCategory.walks =>
        '''
        way($around)["highway"~"path|footway|pedestrian"]["access"!="private"]["foot"!="no"];
        relation($around)["route"="hiking"]["access"!="private"];
      ''',
      SpotCategory.dogParks =>
        '''
        nwr($around)["leisure"="dog_park"];
      ''',
      SpotCategory.treats =>
        '''
        nwr($around)["shop"~"pet|animal_food"];
        nwr($around)["amenity"~"cafe|ice_cream"]["dog"~"yes|leashed"];
      ''',
    };
    return '[out:json][timeout:18];($body);out tags center 80;';
  }

  String _name(Map<String, dynamic> tags, SpotCategory category) {
    final name = tags['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return switch (category) {
      SpotCategory.walks => 'Mapped walking path',
      SpotCategory.dogParks => 'Neighborhood dog park',
      SpotCategory.treats => 'Pet-friendly treat stop',
    };
  }

  String _description(Map<String, dynamic> tags, SpotCategory category) {
    return switch (category) {
      SpotCategory.walks =>
        tags['description']?.toString() ??
            'A nearby mapped path that allows foot traffic. Check posted leash signs when you arrive.',
      SpotCategory.dogParks =>
        tags['description']?.toString() ??
            'A mapped dog park near you. Rate it in Suppup after your visit.',
      SpotCategory.treats =>
        tags['description']?.toString() ??
            'A mapped pet shop or dog-friendly stop where treats may be available.',
    };
  }

  List<String> _badges(Map<String, dynamic> tags, SpotCategory category) {
    final badges = <String>[];
    void addWhen(String key, String value, String label) {
      if (tags[key]?.toString() == value) badges.add(label);
    }

    if (category == SpotCategory.walks) {
      badges.add(tags['surface']?.toString() ?? 'Walking path');
      addWhen('lit', 'yes', 'Well lit');
      if (tags['dog']?.toString() != 'no') badges.add('Dogs allowed');
    } else if (category == SpotCategory.dogParks) {
      badges.add('Dog park');
      addWhen('fenced', 'yes', 'Fenced');
      addWhen('drinking_water', 'yes', 'Water');
      addWhen('lit', 'yes', 'Well lit');
    } else {
      badges.add(tags['shop'] == 'pet' ? 'Pet shop' : 'Dog-friendly');
      addWhen('outdoor_seating', 'yes', 'Patio');
      addWhen('wheelchair', 'yes', 'Accessible');
    }
    return badges.take(3).toList();
  }
}

List<Spot> rankSpots(List<Spot> spots, SpotCategory category) {
  final ranked = [...spots];
  ranked.sort((left, right) {
    if (category == SpotCategory.dogParks) {
      final ratingComparison = (right.communityRating ?? -1).compareTo(
        left.communityRating ?? -1,
      );
      if (ratingComparison != 0) return ratingComparison;
      final countComparison = right.ratingCount.compareTo(left.ratingCount);
      if (countComparison != 0) return countComparison;
    }
    return left.distanceMiles.compareTo(right.distanceMiles);
  });
  return ranked;
}

class NearbyException implements Exception {
  const NearbyException(this.message);

  final String message;

  @override
  String toString() => message;
}
