import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spot.dart';

abstract interface class NearbyRepository {
  Future<List<Spot>> findNearby(LatLng center, SpotCategory category);
}

abstract interface class CachedNearbyRepository implements NearbyRepository {
  Future<List<Spot>?> cachedNearby(LatLng center, SpotCategory category);
}

abstract interface class NearbyCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesNearbyCacheStore implements NearbyCacheStore {
  static const _keyPrefix = 'nearby_cache_v1_';
  final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async {
    final preferences = await _preferences;
    return preferences.getString('$_keyPrefix$key');
  }

  @override
  Future<void> write(String key, String value) async {
    final preferences = await _preferences;
    await preferences.setString('$_keyPrefix$key', value);
  }
}

class OpenStreetMapNearbyRepository implements CachedNearbyRepository {
  OpenStreetMapNearbyRepository({
    http.Client? client,
    List<Uri>? endpoints,
    Duration? requestTimeout,
    Duration? totalRequestTimeout,
    Duration? cacheTtl,
    Duration? maximumCacheAge,
    this.cacheStore,
  }) : _client = client ?? http.Client(),
       _endpoints = endpoints ?? _defaultEndpoints,
       _requestTimeout = requestTimeout ?? const Duration(seconds: 7),
       _totalRequestTimeout =
           totalRequestTimeout ?? const Duration(seconds: 12),
       _cacheTtl = cacheTtl ?? const Duration(minutes: 30),
       _maximumCacheAge = maximumCacheAge ?? const Duration(hours: 24);

  final http.Client _client;
  final List<Uri> _endpoints;
  final Duration _requestTimeout;
  final Duration _totalRequestTimeout;
  final Duration _cacheTtl;
  final Duration _maximumCacheAge;
  final NearbyCacheStore? cacheStore;
  final Map<String, _CachedNearbyResults> _cache = {};

  static final List<Uri> _defaultEndpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
  ];

  @override
  Future<List<Spot>?> cachedNearby(LatLng center, SpotCategory category) async {
    final cached = await _readCache(_cacheKey(center, category));
    if (cached == null ||
        DateTime.now().difference(cached.savedAt) > _maximumCacheAge) {
      return null;
    }
    return _refreshDistances(cached.spots, center);
  }

  @override
  Future<List<Spot>> findNearby(LatLng center, SpotCategory category) async {
    final cacheKey = _cacheKey(center, category);
    final cached = await _readCache(cacheKey);
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) < _cacheTtl) {
      return _refreshDistances(cached.spots, center);
    }

    Object? lastFailure;
    final query = _query(center, category);
    final stopwatch = Stopwatch()..start();
    for (final endpoint in _endpoints) {
      final remaining = _totalRequestTimeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) break;
      final attemptTimeout = remaining < _requestTimeout
          ? remaining
          : _requestTimeout;
      try {
        final response = await _client
            .post(
              endpoint,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'Suppup/1.0.1 (com.josh.suppup)',
              },
              body: {'data': query},
            )
            .timeout(attemptTimeout);
        if (response.statusCode != 200) {
          lastFailure = 'HTTP ${response.statusCode} from ${endpoint.host}';
          continue;
        }

        final spots = _parseResponse(response.body, center, category);
        final entry = _CachedNearbyResults(DateTime.now(), spots);
        _cache[cacheKey] = entry;
        await _writeCache(cacheKey, entry);
        return [...spots];
      } catch (error) {
        lastFailure = error;
      }
    }

    throw NearbyException(
      'The nearby map services are taking a break. $lastFailure',
    );
  }

  Future<_CachedNearbyResults?> _readCache(String key) async {
    final memoryEntry = _cache[key];
    if (memoryEntry != null) return memoryEntry;

    try {
      final encoded = await cacheStore?.read(key);
      if (encoded == null) return null;
      final entry = _CachedNearbyResults.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      _cache[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, _CachedNearbyResults entry) async {
    try {
      await cacheStore?.write(key, jsonEncode(entry.toJson()));
    } catch (_) {
      // Nearby results still work when persistent cache storage is unavailable.
    }
  }

  List<Spot> _refreshDistances(List<Spot> spots, LatLng center) {
    return spots.map((spot) {
      final distanceMeters = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        spot.location.latitude,
        spot.location.longitude,
      );
      return spot.copyWith(distanceMiles: distanceMeters / 1609.344);
    }).toList();
  }

  List<Spot> _parseResponse(
    String responseBody,
    LatLng center,
    SpotCategory category,
  ) {
    final payload = jsonDecode(responseBody) as Map<String, dynamic>;
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

  String _cacheKey(LatLng center, SpotCategory category) =>
      '${category.name}:${center.latitude.toStringAsFixed(2)}:'
      '${center.longitude.toStringAsFixed(2)}';

  String _query(LatLng center, SpotCategory category) {
    final radiusMeters = category == SpotCategory.walks ? 4000 : 8000;
    final around =
        'around:$radiusMeters,${center.latitude},${center.longitude}';
    final body = switch (category) {
      SpotCategory.walks =>
        '''
        way($around)["highway"~"path|footway|pedestrian"]["access"!="private"]["foot"!="no"];
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
    return '[out:json][timeout:8];($body);out tags center 60;';
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

class _CachedNearbyResults {
  const _CachedNearbyResults(this.savedAt, this.spots);

  final DateTime savedAt;
  final List<Spot> spots;

  factory _CachedNearbyResults.fromJson(Map<String, dynamic> json) {
    final rawSpots = json['spots'] as List<dynamic>? ?? const [];
    return _CachedNearbyResults(
      DateTime.parse(json['savedAt'] as String),
      rawSpots.map((rawSpot) {
        final spot = Map<String, dynamic>.from(rawSpot as Map);
        return Spot(
          id: spot['id'] as String,
          name: spot['name'] as String,
          category: SpotCategory.values.byName(spot['category'] as String),
          location: LatLng(
            (spot['latitude'] as num).toDouble(),
            (spot['longitude'] as num).toDouble(),
          ),
          distanceMiles: (spot['distanceMiles'] as num).toDouble(),
          description: spot['description'] as String,
          badges: (spot['badges'] as List<dynamic>)
              .map((badge) => badge as String)
              .toList(),
          communityRating: (spot['communityRating'] as num?)?.toDouble(),
          ratingCount: spot['ratingCount'] as int? ?? 0,
          isPreview: spot['isPreview'] as bool? ?? false,
        );
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'savedAt': savedAt.toIso8601String(),
    'spots': spots.map((spot) {
      return {
        'id': spot.id,
        'name': spot.name,
        'category': spot.category.name,
        'latitude': spot.location.latitude,
        'longitude': spot.location.longitude,
        'distanceMiles': spot.distanceMiles,
        'description': spot.description,
        'badges': spot.badges,
        'communityRating': spot.communityRating,
        'ratingCount': spot.ratingCount,
        'isPreview': spot.isPreview,
      };
    }).toList(),
  };
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
