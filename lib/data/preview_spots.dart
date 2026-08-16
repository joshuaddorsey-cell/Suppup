import 'package:latlong2/latlong.dart';

import '../models/spot.dart';

List<Spot> previewSpots(LatLng center, SpotCategory category) {
  final definitions = switch (category) {
    SpotCategory.walks => const [
      (
        'Riverside Sniff Loop',
        'A relaxed waterside loop with shade and plenty of sniff stops.',
        ['Leash-friendly', 'Shaded', 'Easy'],
        4.8,
        124,
      ),
      (
        'Maple Greenway',
        'A smooth neighborhood greenway that works well for everyday walks.',
        ['Paved', 'Well lit', 'Easy'],
        4.6,
        81,
      ),
      (
        'Creekside Adventure Trail',
        'A slightly longer path for dogs who need a little more adventure.',
        ['Nature trail', 'Moderate', 'Water nearby'],
        4.7,
        63,
      ),
    ],
    SpotCategory.dogParks => const [
      (
        'Wagging Meadows Dog Park',
        'A roomy fenced park with separate areas and water access.',
        ['Fenced', 'Water', 'Small-dog area'],
        4.9,
        218,
      ),
      (
        'Happy Tails Dog Run',
        'A friendly local run with benches, shade, and an active crowd.',
        ['Fenced', 'Shade', 'Benches'],
        4.7,
        146,
      ),
      (
        'Barkside Commons',
        'A compact off-leash stop that is especially good for quick play.',
        ['Off leash', 'Waste bags', 'Compact'],
        4.5,
        74,
      ),
    ],
    SpotCategory.treats => const [
      (
        'Biscuit & Bone',
        'Fresh-baked dog treats and a water bowl by the entrance.',
        ['Dog treats', 'Water bowl', 'Local'],
        4.9,
        92,
      ),
      (
        'Paws Pantry',
        'A neighborhood pet shop with natural chews and training treats.',
        ['Pet shop', 'Natural treats', 'Open today'],
        4.7,
        118,
      ),
      (
        'The Patio Pup Café',
        'A dog-welcoming patio with people snacks and a small pup menu.',
        ['Dog-friendly patio', 'Pup cups', 'Water'],
        4.6,
        57,
      ),
    ],
  };

  const offsets = [(0.004, 0.002), (-0.003, 0.005), (0.006, -0.004)];
  return [
    for (var index = 0; index < definitions.length; index++)
      Spot(
        id: 'preview-${category.name}-$index',
        name: definitions[index].$1,
        category: category,
        location: LatLng(
          center.latitude + offsets[index].$1,
          center.longitude + offsets[index].$2,
        ),
        distanceMiles: 0.4 + (index * 0.55),
        description: definitions[index].$2,
        badges: definitions[index].$3,
        communityRating: definitions[index].$4,
        ratingCount: definitions[index].$5,
        isPreview: true,
      ),
  ];
}
