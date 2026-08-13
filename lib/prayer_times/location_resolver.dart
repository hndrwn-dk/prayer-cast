import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resolved GPS fix + display labels for prayer-time prefs.
final class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String country;
}

enum LocationResolveCode {
  serviceOff,
  denied,
  deniedForever,
}

/// Typed failure for the “use current location” flow.
final class LocationResolveFailure implements Exception {
  const LocationResolveFailure(this.code);

  final LocationResolveCode code;

  @override
  String toString() => 'LocationResolveFailure($code)';
}

/// GPS + reverse-geocode helper for prayer times.
final class LocationResolver {
  const LocationResolver();

  /// Requests permission, reads a current position, and reverse-geocodes labels.
  Future<ResolvedLocation> resolveCurrent() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationResolveFailure(LocationResolveCode.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationResolveFailure(LocationResolveCode.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationResolveFailure(LocationResolveCode.deniedForever);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );

    var city = '';
    var country = '';
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) {
        final p = places.first;
        city = _firstNonEmpty([
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ]);
        country = _firstNonEmpty([p.country, p.isoCountryCode]);
      }
    } catch (_) {
      // Labels are best-effort; coordinates alone are enough for Aladhan.
    }

    if (city.isEmpty) {
      city =
          '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
    }
    if (country.isEmpty) {
      country = 'GPS';
    }

    return ResolvedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      country: country,
    );
  }

  static String _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      final t = c?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return '';
  }
}
