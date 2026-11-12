import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:suppup/app.dart';
import 'package:suppup/data/preview_spots.dart';
import 'package:suppup/models/spot.dart';
import 'package:suppup/screens/home_screen.dart';
import 'package:suppup/services/location_service.dart';
import 'package:suppup/services/nearby_service.dart';
import 'package:suppup/services/user_preferences.dart';

void main() {
  testWidgets('shows all three nearby dog-friendly categories', (tester) async {
    final location = _FakeLocation();
    final repository = _FakeNearbyRepository();
    final preferences = _MemoryPreferences();

    await tester.pumpWidget(
      SuppupApp(
        home: HomeScreen(
          locationProvider: location,
          nearbyRepository: repository,
          preferenceStore: preferences,
          showMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SUPPUP'), findsOneWidget);
    expect(find.text('Walks'), findsOneWidget);
    expect(find.text('Dog parks'), findsOneWidget);
    expect(find.text('Treat stops'), findsOneWidget);
    expect(find.text('Leash-worthy walks'), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-dogParks')));
    await tester.pumpAndSettle();
    expect(find.text('Top-rated dog parks'), findsOneWidget);
    expect(find.text('Wagging Meadows Dog Park'), findsOneWidget);
  });

  testWidgets('stalled location leaves loading and shows labeled preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      SuppupApp(
        home: HomeScreen(
          locationProvider: _StalledLocation(),
          nearbyRepository: _FakeNearbyRepository(),
          preferenceStore: _MemoryPreferences(),
          showMap: false,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Location is unavailable'), findsOneWidget);
  });

  testWidgets('stalled preferences do not block nearby results', (
    tester,
  ) async {
    await tester.pumpWidget(
      SuppupApp(
        home: HomeScreen(
          locationProvider: _FakeLocation(),
          nearbyRepository: _FakeNearbyRepository(),
          preferenceStore: _StalledPreferences(),
          showMap: false,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining(' found'), findsOneWidget);
  });

  testWidgets('early preferences error is handled while location is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      SuppupApp(
        home: HomeScreen(
          locationProvider: _StalledLocation(),
          nearbyRepository: _FakeNearbyRepository(),
          preferenceStore: _FailingPreferences(),
          showMap: false,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'stalled nearby lookup leaves loading and shows labeled preview',
    (tester) async {
      await tester.pumpWidget(
        SuppupApp(
          home: HomeScreen(
            locationProvider: _FakeLocation(),
            nearbyRepository: _StalledNearbyRepository(),
            preferenceStore: _MemoryPreferences(),
            showMap: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.textContaining('Live map results are temporarily unavailable'),
        findsOneWidget,
      );
    },
  );

  testWidgets('saved results remain visible when refresh stalls', (
    tester,
  ) async {
    await tester.pumpWidget(
      SuppupApp(
        home: HomeScreen(
          locationProvider: _FakeLocation(),
          nearbyRepository: _SavedNearbyRepository(),
          preferenceStore: _MemoryPreferences(),
          showMap: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Showing saved nearby results'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.textContaining('Live results could not refresh'),
      findsOneWidget,
    );
    expect(find.textContaining(' found'), findsOneWidget);
  });

  test('dog parks rank by rating before distance', () {
    const center = LatLng(40, -75);
    final lowerRatedNearby = Spot(
      id: 'near',
      name: 'Nearby',
      category: SpotCategory.dogParks,
      location: center,
      distanceMiles: 0.2,
      description: '',
      badges: const [],
      communityRating: 4.2,
      ratingCount: 20,
    );
    final topRatedFarther = Spot(
      id: 'top',
      name: 'Top rated',
      category: SpotCategory.dogParks,
      location: center,
      distanceMiles: 2,
      description: '',
      badges: const [],
      communityRating: 4.9,
      ratingCount: 8,
    );

    final ranked = rankSpots([
      lowerRatedNearby,
      topRatedFarther,
    ], SpotCategory.dogParks);

    expect(ranked.first.id, 'top');
  });
}

class _FakeLocation implements LocationProvider {
  @override
  Future<LatLng> currentLocation() async => const LatLng(40.7128, -74.0060);
}

class _FakeNearbyRepository implements NearbyRepository {
  @override
  Future<List<Spot>> findNearby(LatLng center, SpotCategory category) async =>
      previewSpots(center, category);
}

class _MemoryPreferences implements PreferenceStore {
  final Set<String> _favorites = {};
  final Map<String, double> _ratings = {};

  @override
  Future<Set<String>> favorites() async => {..._favorites};

  @override
  Future<double?> ratingFor(String id) async => _ratings[id];

  @override
  Future<void> setFavorite(String id, {required bool value}) async {
    value ? _favorites.add(id) : _favorites.remove(id);
  }

  @override
  Future<void> setRating(String id, double value) async {
    _ratings[id] = value;
  }
}

class _StalledLocation implements LocationProvider {
  @override
  Future<LatLng> currentLocation() => Completer<LatLng>().future;
}

class _StalledNearbyRepository implements NearbyRepository {
  @override
  Future<List<Spot>> findNearby(LatLng center, SpotCategory category) =>
      Completer<List<Spot>>().future;
}

class _StalledPreferences extends _MemoryPreferences {
  @override
  Future<Set<String>> favorites() => Completer<Set<String>>().future;
  @override
  Future<double?> ratingFor(String id) => Completer<double?>().future;
}

class _FailingPreferences extends _MemoryPreferences {
  @override
  Future<Set<String>> favorites() =>
      Future.error(StateError('storage unavailable'));
}

class _SavedNearbyRepository extends _StalledNearbyRepository
    implements CachedNearbyRepository {
  @override
  Future<List<Spot>?> cachedNearby(
    LatLng center,
    SpotCategory category,
  ) async => previewSpots(center, category);
}
