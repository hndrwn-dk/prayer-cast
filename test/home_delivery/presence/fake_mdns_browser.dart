import 'package:prayer_cast/home_delivery/presence/mdns_browser.dart';

/// Scripted [MdnsBrowser] for presence unit tests.
final class FakeMdnsBrowser implements MdnsBrowser {
  FakeMdnsBrowser(this._responses);

  /// Queue of per-browse responses. Each [browse] call takes the next list.
  final List<List<DiscoveredService>> _responses;
  int _index = 0;

  /// Optional dynamic responder; wins over the queue when set.
  List<DiscoveredService> Function({
    required List<String> serviceTypes,
    required Duration budget,
  })? onBrowse;

  int browseCount = 0;

  @override
  Future<List<DiscoveredService>> browse({
    required List<String> serviceTypes,
    required Duration budget,
    bool Function(List<DiscoveredService> soFar)? shouldStop,
  }) async {
    browseCount += 1;
    final List<DiscoveredService> services;
    if (onBrowse != null) {
      services = onBrowse!(serviceTypes: serviceTypes, budget: budget);
    } else {
      if (_index >= _responses.length) {
        services = const [];
      } else {
        services = _responses[_index++];
      }
    }

    // Honour early-exit for Signal A tests.
    if (shouldStop != null && shouldStop(services)) {
      return services;
    }
    // Filter to requested types when scripted lists mix types.
    return services
        .where((s) => serviceTypes.contains(s.serviceType))
        .toList(growable: false);
  }
}
