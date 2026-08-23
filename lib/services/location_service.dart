import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

abstract interface class LocationProvider {
  Future<LatLng> currentLocation();
}

class DeviceLocationProvider implements LocationProvider {
  const DeviceLocationProvider();

  static const _recentLocationAge = Duration(minutes: 10);
  static const _freshLocationTimeout = Duration(seconds: 6);

  @override
  Future<LatLng> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Turn on phone location to see walks, parks, and treats near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Suppup needs location permission to find dog-friendly places near you.',
      );
    }

    final lastKnownPosition = await Geolocator.getLastKnownPosition();
    if (lastKnownPosition != null &&
        DateTime.now().difference(lastKnownPosition.timestamp).abs() <=
            _recentLocationAge) {
      return LatLng(lastKnownPosition.latitude, lastKnownPosition.longitude);
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _freshLocationTimeout,
        ),
      );
    } catch (_) {
      if (lastKnownPosition == null) rethrow;
      position = lastKnownPosition;
    }
    return LatLng(position.latitude, position.longitude);
  }
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
