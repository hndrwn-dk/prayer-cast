import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'indonesia_location.dart';

/// Resolved GPS fix + display labels for prayer-time prefs.
final class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    this.administrativeArea = '',
  });

  final double latitude;
  final double longitude;
  final String city;
  final String country;

  /// Province / kabupaten from reverse geocode; used as a Kemenag match hint.
  final String administrativeArea;
}

enum LocationResolveCode {
  serviceOff,
  denied,
  deniedForever,
  timeout,
  unavailable,
}

/// Typed failure for the “use current location” flow.
final class LocationResolveFailure implements Exception {
  const LocationResolveFailure(this.code);

  final LocationResolveCode code;

  @override
  String toString() => 'LocationResolveFailure($code)';
}

/// Prayer-city location: permission check + optional GPS resolve.
abstract interface class LocationResolving {
  /// True when the OS already granted while-in-use or always.
  Future<bool> hasGrantedPermission();

  /// Requests permission if needed, reads a position, reverse-geocodes labels.
  Future<ResolvedLocation> resolveCurrent();
}

/// GPS + reverse-geocode helper for prayer times.
///
/// Android: COARSE only (FINE is tools:node="remove"). Approximate location
/// is a fused *cached* city-block fix, not a new GPS sample.
/// [getCurrentPosition] with [LocationAccuracy.low] + a 20s Dart [timeLimit]
/// waits for a new PRIORITY_LOW_POWER update and cancels before the network
/// provider typically returns.
final class LocationResolver implements LocationResolving {
  const LocationResolver();

  /// Balanced / approximate — not GPS (high/best). No Dart timeLimit.
  static final LocationSettings coarseSettings = AndroidSettings(
    accuracy: LocationAccuracy.medium,
    intervalDuration: Duration.zero,
  );

  @override
  Future<bool> hasGrantedPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Requests permission, reads a current position, and reverse-geocodes labels.
  @override
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

    late final Position position;
    try {
      position = await _readPosition();
    } on LocationResolveFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationResolveFailure(LocationResolveCode.timeout);
    } catch (_) {
      throw const LocationResolveFailure(LocationResolveCode.unavailable);
    }

    return _resolvedFromPosition(position);
  }

  /// Approximate location: use fused last-known (what COARSE actually
  /// delivers) before requesting a new update.
  Future<Position> _readPosition() async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (hasUsableCoordinates(lastKnown)) {
      return lastKnown!;
    }
    return Geolocator.getCurrentPosition(locationSettings: coarseSettings);
  }

  Future<ResolvedLocation> _resolvedFromPosition(Position position) async {
    var city = '';
    var country = '';
    var administrativeArea = '';
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) {
        final p = places.first;
        final labels = labelsFromGeocode(
          country: p.country,
          isoCountryCode: p.isoCountryCode,
          locality: p.locality,
          subAdministrativeArea: p.subAdministrativeArea,
          administrativeArea: p.administrativeArea,
        );
        city = labels.city;
        country = labels.country;
        administrativeArea = labels.administrativeArea;
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
      administrativeArea: administrativeArea,
    );
  }

  /// True when [position] has finite latitude/longitude.
  static bool hasUsableCoordinates(Position? position) {
    if (position == null) return false;
    return position.latitude.isFinite && position.longitude.isFinite;
  }

  /// Maps reverse-geocode fields to prayer-city labels.
  ///
  /// Indonesia: display city prefers kabupaten/kota
  /// (`subAdministrativeArea`), then kelurahan (`locality`). The admin
  /// hint prefers kabupaten/kota so a kelurahan-only city can still
  /// match Kemenag.
  static ({String city, String country, String administrativeArea})
      labelsFromGeocode({
    String? country,
    String? isoCountryCode,
    String? locality,
    String? subAdministrativeArea,
    String? administrativeArea,
  }) {
    final resolvedCountry = _firstNonEmpty([country, isoCountryCode]);
    final admin = _firstNonEmpty([
      subAdministrativeArea,
      administrativeArea,
    ]);
    final city = isIndonesiaCountry(resolvedCountry)
        ? _firstNonEmpty([
            subAdministrativeArea,
            locality,
            administrativeArea,
          ])
        : _firstNonEmpty([
            locality,
            subAdministrativeArea,
            administrativeArea,
          ]);
    return (
      city: city,
      country: resolvedCountry,
      administrativeArea: admin,
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
