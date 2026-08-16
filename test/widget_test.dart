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
