import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/spot.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/bone_pattern_background.dart';

class SpotDetailsScreen extends StatefulWidget {
  const SpotDetailsScreen({
    super.key,
    required this.spot,
    required this.initialFavorite,
    required this.preferences,
  });

  final Spot spot;
  final bool initialFavorite;
  final PreferenceStore preferences;

  @override
  State<SpotDetailsScreen> createState() => _SpotDetailsScreenState();
}

class _SpotDetailsScreenState extends State<SpotDetailsScreen> {
  late bool _favorite;
  double? _rating;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.initialFavorite;
    _rating = widget.spot.communityRating;
  }

  Future<void> _toggleFavorite() async {
    final value = !_favorite;
    setState(() => _favorite = value);
    await widget.preferences.setFavorite(widget.spot.id, value: value);
    _changed = true;
  }

  Future<void> _rate(double value) async {
    setState(() => _rating = value);
    await widget.preferences.setRating(widget.spot.id, value);
    _changed = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your Suppup rating was saved.')),
    );
  }

  Future<void> _openDirections() async {
    if (widget.spot.isPreview) return;
    final point = widget.spot.location;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.latitude},${point.longitude}',
      'travelmode': 'walking',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open walking directions.')),
      );
    }
  }

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Spot details'),
          actions: [
            IconButton(
              tooltip: _favorite ? 'Remove favorite' : 'Save favorite',
              onPressed: _toggleFavorite,
              icon: Icon(
                _favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _favorite ? SuppupColors.coral : SuppupColors.ink,
              ),
            ),
          ],
        ),
        body: BonePatternBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: widget.spot.location,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.josh.suppup',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.spot.location,
                            width: 52,
                            height: 52,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: SuppupColors.coral,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 9,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.spot.category.icon,
                                color: Colors.white,
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
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.spot.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: SuppupColors.mint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${widget.spot.distanceMiles.toStringAsFixed(1)} mi',
                      style: const TextStyle(
                        color: SuppupColors.forest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.spot.description),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in widget.spot.badges)
                    Chip(label: Text(badge)),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: SuppupColors.mint.withValues(alpha: 0.7),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How was it?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your rating helps the best dog spots rise to the top.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var value = 1; value <= 5; value++)
                            IconButton(
                              key: Key('rate-$value'),
                              tooltip: '$value stars',
                              onPressed: () => _rate(value.toDouble()),
                              iconSize: 34,
                              padding: const EdgeInsets.only(right: 4),
                              icon: Icon(
                                (_rating ?? 0) >= value
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: SuppupColors.sunshine,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.spot.isPreview ? null : _openDirections,
                icon: const Icon(Icons.directions_walk_rounded),
                label: Text(
                  widget.spot.isPreview
                      ? 'Directions available with live results'
                      : 'Start walking directions',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
