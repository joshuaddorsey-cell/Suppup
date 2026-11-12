import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:suppup/models/spot.dart';
import 'package:suppup/services/nearby_service.dart';

void main() {
  test('stalled disk cache cannot block a successful network result', () async {
    final repository = OpenStreetMapNearbyRepository(
      cacheStore: _StalledCacheStore(),
      client: MockClient((_) async => http.Response('{"elements":[]}', 200)),
    );
    final spots = await repository
        .findNearby(const LatLng(33.775, -84.351), SpotCategory.walks)
        .timeout(const Duration(seconds: 4));
    expect(spots, isEmpty);
  });

  test('uses the backup server and caches successful nearby results', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      expect(request.method, 'POST');
      expect(request.body, contains('data='));

      if (request.url.host == 'primary.example') {
        return http.Response('busy', 504);
      }

      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'node',
              'id': 42,
              'lat': 33.776,
              'lon': -84.352,
              'tags': {'name': 'Freedom Park Trail', 'surface': 'paved'},
            },
          ],
        }),
        200,
      );
    });
    final repository = OpenStreetMapNearbyRepository(
      client: client,
      endpoints: [
        Uri.parse('https://primary.example/api/interpreter'),
        Uri.parse('https://backup.example/api/interpreter'),
      ],
    );
    const center = LatLng(33.775, -84.351);

    final first = await repository.findNearby(center, SpotCategory.walks);
    final cached = await repository.findNearby(center, SpotCategory.walks);

    expect(first, hasLength(1));
    expect(first.single.name, 'Freedom Park Trail');
    expect(first.single.badges, contains('paved'));
    expect(cached.single.id, first.single.id);
    expect(requestCount, 2);
  });

  test('throws only after every nearby server fails', () async {
    var requestCount = 0;
    final repository = OpenStreetMapNearbyRepository(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('busy', 503);
      }),
      endpoints: [
        Uri.parse('https://primary.example/api/interpreter'),
        Uri.parse('https://backup.example/api/interpreter'),
      ],
    );

    await expectLater(
      repository.findNearby(
        const LatLng(33.775, -84.351),
        SpotCategory.dogParks,
      ),
      throwsA(isA<NearbyException>()),
    );
    expect(requestCount, 2);
  });

  test(
    'reuses saved nearby results after the repository is recreated',
    () async {
      var requestCount = 0;
      final cacheStore = _MemoryNearbyCacheStore();
      final client = MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 99,
                'lat': 33.776,
                'lon': -84.352,
                'tags': {'name': 'Saved Dog Walk'},
              },
            ],
          }),
          200,
        );
      });
      const center = LatLng(33.775, -84.351);

      final firstRepository = OpenStreetMapNearbyRepository(
        client: client,
        endpoints: [Uri.parse('https://primary.example/api/interpreter')],
        cacheStore: cacheStore,
      );
      await firstRepository.findNearby(center, SpotCategory.walks);

      final reopenedRepository = OpenStreetMapNearbyRepository(
        client: client,
        endpoints: [Uri.parse('https://primary.example/api/interpreter')],
        cacheStore: cacheStore,
      );
      final saved = await reopenedRepository.cachedNearby(
        center,
        SpotCategory.walks,
      );
      final freshEnough = await reopenedRepository.findNearby(
        center,
        SpotCategory.walks,
      );

      expect(saved, isNotNull);
      expect(saved!.single.name, 'Saved Dog Walk');
      expect(freshEnough.single.id, saved.single.id);
      expect(requestCount, 1);
    },
  );
}

class _MemoryNearbyCacheStore implements NearbyCacheStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _StalledCacheStore implements NearbyCacheStore {
  @override
  Future<String?> read(String key) => Completer<String?>().future;
  @override
  Future<void> write(String key, String value) => Completer<void>().future;
}
