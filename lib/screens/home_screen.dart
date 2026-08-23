import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/preview_spots.dart';
import '../models/spot.dart';
import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/bone_pattern_background.dart';
import '../widgets/spot_card.dart';
import 'spot_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.locationProvider,
    this.nearbyRepository,
    this.preferenceStore,
    this.showMap = true,
  });

  final LocationProvider? locationProvider;
  final NearbyRepository? nearbyRepository;
  final PreferenceStore? preferenceStore;
  final bool showMap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _demoCenter = LatLng(40.7128, -74.0060);
  static final _privacyPolicyUri = Uri.parse(
    'https://joshuaddorsey-cell.github.io/Suppup/privacy.html',
  );
  static final _openStreetMapCopyrightUri = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  late final LocationProvider _locationProvider;
  late final NearbyRepository _nearbyRepository;
  late final PreferenceStore _preferences;

  SpotCategory _category = SpotCategory.walks;
  LatLng _center = _demoCenter;
  List<Spot> _spots = const [];
  Set<String> _favorites = const {};
  bool _loading = true;
  bool _showFavorites = false;
  String? _notice;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _locationProvider =
        widget.locationProvider ?? const DeviceLocationProvider();
    _nearbyRepository =
        widget.nearbyRepository ??
        OpenStreetMapNearbyRepository(
          cacheStore: SharedPreferencesNearbyCacheStore(),
        );
    _preferences = widget.preferenceStore ?? UserPreferenceStore();
    unawaited(_load(refreshLocation: true));
  }

  Future<void> _load({required bool refreshLocation}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _notice = null;
    });

    final favoritesFuture = _preferences.favorites();
    var center = _center;
    var usePreview = false;
    String? notice;
    if (refreshLocation || _center == _demoCenter) {
      try {
        center = await _locationProvider.currentLocation();
      } catch (error) {
        usePreview = true;
        notice = error is LocationException
            ? error.message
            : 'Location is unavailable. Showing a clearly labeled Suppup preview.';
      }
    }

    List<Spot>? savedResults;
    if (!usePreview && _nearbyRepository is CachedNearbyRepository) {
      try {
        savedResults = await _nearbyRepository.cachedNearby(center, _category);
        if (savedResults != null && mounted && requestId == _requestId) {
          Set<String> favorites;
          try {
            favorites = await favoritesFuture;
            savedResults = await _applySavedRatings(savedResults);
          } catch (_) {
            favorites = <String>{};
          }
          if (!mounted || requestId != _requestId) return;
          setState(() {
            _center = center;
            _spots = rankSpots(savedResults!, _category);
            _favorites = favorites;
            _notice = 'Showing saved nearby results while Suppup refreshes.';
          });
        }
      } catch (_) {
        savedResults = null;
      }
    }

    List<Spot> results;
    if (usePreview) {
      results = previewSpots(center, _category);
    } else {
      try {
        results = await _nearbyRepository.findNearby(center, _category);
      } catch (_) {
        if (savedResults != null) {
          if (!mounted || requestId != _requestId) return;
          setState(() {
            _notice =
                'Live results could not refresh. Showing your saved nearby results.';
            _loading = false;
          });
          return;
        }
        usePreview = true;
        results = previewSpots(center, _category);
        notice =
            'Live map results are temporarily unavailable. These are Suppup preview examples.';
      }
    }

    Set<String> favorites;
    try {
      favorites = await _preferences.favorites();
      results = await _applySavedRatings(results);
    } catch (_) {
      favorites = <String>{};
    }

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _center = center;
      _spots = rankSpots(results, _category);
      _favorites = favorites;
      _notice = notice;
      _loading = false;
    });
  }

  Future<List<Spot>> _applySavedRatings(List<Spot> spots) async {
    return Future.wait(
      spots.map((spot) async {
        final savedRating = await _preferences.ratingFor(spot.id);
        return savedRating == null
            ? spot
            : spot.copyWith(
                communityRating: savedRating,
                ratingCount: spot.ratingCount == 0 ? 1 : spot.ratingCount,
              );
      }),
    );
  }

  Future<void> _refreshSavedState() async {
    try {
      final favorites = await _preferences.favorites();
      final spots = await _applySavedRatings(_spots);
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _spots = rankSpots(spots, _category);
      });
    } catch (_) {
      // The live result remains useful even if local preferences are unavailable.
    }
  }

  Future<void> _openExternalPage(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that page.')),
      );
    }
  }

  Future<void> _toggleFavorite(Spot spot) async {
    final nextValue = !_favorites.contains(spot.id);
    setState(() {
      final values = {..._favorites};
      nextValue ? values.add(spot.id) : values.remove(spot.id);
      _favorites = values;
    });
    await _preferences.setFavorite(spot.id, value: nextValue);
  }

  Future<void> _openSpot(Spot spot) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SpotDetailsScreen(
          spot: spot,
          initialFavorite: _favorites.contains(spot.id),
          preferences: _preferences,
        ),
      ),
    );
    if (changed == true) await _refreshSavedState();
  }

  void _chooseCategory(SpotCategory category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _showFavorites = false;
    });
    unawaited(_load(refreshLocation: false));
  }

  @override
  Widget build(BuildContext context) {
    final visibleSpots = _showFavorites
        ? _spots.where((spot) => _favorites.contains(spot.id)).toList()
        : _spots;

    return Scaffold(
      body: BonePatternBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _load(refreshLocation: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
              children: [
                _Header(
                  showingFavorites: _showFavorites,
                  onFavorites: () => setState(() {
                    _showFavorites = !_showFavorites;
                  }),
                ),
                const SizedBox(height: 22),
                _HeroMessage(onRefresh: () => _load(refreshLocation: true)),
                const SizedBox(height: 18),
                _CategoryPicker(
                  selected: _category,
                  onSelected: _chooseCategory,
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    minHeight: 5,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 14),
                  _NoticeBanner(message: _notice!),
                ],
                const SizedBox(height: 18),
                if (widget.showMap)
                  _MapPreview(
                    center: _center,
                    spots: visibleSpots.take(10).toList(),
                    onSpot: _openSpot,
                  )
                else
                  const SizedBox(height: 1),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showFavorites ? 'Saved spots' : _category.heading,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${visibleSpots.length} found',
                      style: const TextStyle(
                        color: SuppupColors.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_loading && visibleSpots.isEmpty)
                  _EmptyState(
                    message: _showFavorites
                        ? 'Save a spot with the heart and it will appear here.'
                        : _category.emptyMessage,
                  )
                else
                  for (final spot in visibleSpots) ...[
                    SpotCard(
                      spot: spot,
                      isFavorite: _favorites.contains(spot.id),
                      onTap: () => _openSpot(spot),
                      onFavorite: () => _toggleFavorite(spot),
                    ),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => _openExternalPage(_privacyPolicyUri),
                        child: const Text('Privacy policy'),
                      ),
                      const Text(
                        '•',
                        style: TextStyle(color: SuppupColors.muted),
                      ),
                      TextButton(
                        onPressed: () =>
                            _openExternalPage(_openStreetMapCopyrightUri),
                        child: const Text('© OpenStreetMap contributors'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showingFavorites, required this.onFavorites});

  final bool showingFavorites;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: SuppupColors.cream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: SuppupColors.coral.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/suppup-puppy-logo-v2.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPPUP',
                style: TextStyle(
                  color: SuppupColors.ink,
                  fontSize: 22,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'GOOD WALKS. HAPPY DOGS.',
                style: TextStyle(
                  color: SuppupColors.muted,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: showingFavorites ? 'Show nearby spots' : 'Show favorites',
          onPressed: onFavorites,
          icon: Icon(
            showingFavorites ? Icons.explore_rounded : Icons.favorite_rounded,
            color: showingFavorites ? SuppupColors.forest : SuppupColors.coral,
          ),
        ),
      ],
    );
  }
}

class _HeroMessage extends StatelessWidget {
  const _HeroMessage({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SuppupColors.forest, Color(0xFF39886E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where should we\nwag today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.03,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Fresh nearby picks for you and your best friend.',
                  style: TextStyle(color: Color(0xFFDDF3E8), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Refresh location',
            onPressed: onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: SuppupColors.forest,
            ),
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onSelected});

  final SpotCategory selected;
  final ValueChanged<SpotCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < SpotCategory.values.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _CategoryButton(
              category: SpotCategory.values[index],
              selected: selected == SpotCategory.values[index],
              onTap: () => onSelected(SpotCategory.values[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SpotCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SuppupColors.ink : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('category-${category.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
          child: Column(
            children: [
              Icon(
                category.icon,
                color: selected ? Colors.white : SuppupColors.forest,
              ),
              const SizedBox(height: 5),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : SuppupColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.center,
    required this.spots,
    required this.onSpot,
  });

  final LatLng center;
  final List<Spot> spots;
  final ValueChanged<Spot> onSpot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 238,
        child: FlutterMap(
          key: ValueKey(
            '${center.latitude}-${center.longitude}-${spots.length}',
          ),
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12.6,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.josh.suppup',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 42,
                  height: 42,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: SuppupColors.forest, width: 4),
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      size: 22,
                      color: SuppupColors.forest,
                    ),
                  ),
                ),
                for (final spot in spots)
                  Marker(
                    point: spot.location,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => onSpot(spot),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SuppupColors.coral,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          spot.category.icon,
                          size: 21,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap')],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SuppupColors.sunshine.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: SuppupColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: SuppupColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.pets_rounded, size: 44, color: SuppupColors.coral),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
