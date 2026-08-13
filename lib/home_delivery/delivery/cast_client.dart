import 'dart:async';
import 'dart:io';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart' as cast;
import 'package:nsd/nsd.dart' as nsd;

import '../common/logger.dart';
import '../logging/outcome.dart';

/// Snapshot of a discovered Cast receiver.
final class CastReceiver {
  const CastReceiver({
    required this.deviceId,
    required this.friendlyName,
    required this.host,
  });

  /// Cast device `id` — stable; never match by friendly name (§5.3).
  final String deviceId;
  final String friendlyName;
  final InternetAddress host;
}

/// Current media status used for the §4.8 duplicate check.
final class CastMediaSnapshot {
  const CastMediaSnapshot({
    required this.contentId,
    required this.isPlaying,
  });

  final String contentId;
  final bool isPlaying;
}

/// Port over the Cast SDK so unit tests never touch real hardware.
abstract interface class CastPlatform {
  /// Discover devices for up to [budget]; return current sightings.
  Future<List<CastReceiver>> discover({
    required Duration budget,
  });

  Future<void> connect(CastReceiver receiver);

  Future<double> getVolume();

  Future<void> setVolume(double volume);

  Future<CastMediaSnapshot?> currentMedia();

  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
  });

  /// Emits when the receiver reports IDLE/FINISHED after loadMedia.
  Stream<CastPlaybackEvent> get playbackEvents;

  Future<void> endSession();
}

enum CastPlaybackEvent { idle, finished, playing, other }

/// flutter_chrome_cast wrapper with volume save/restore (spec §5.3, §4.8).
///
/// WHY: Match the saved target by Cast device id (not friendly name). Save
/// receiver volume before playback and restore after — leaving a Nest Mini at
/// 90% after Maghrib is a bug report. Receiver-side duplicate check aborts
/// with `SUPPRESSED_ALREADY_PLAYING` if the adzan is already playing.
final class CastClient {
  CastClient({
    required CastPlatform platform,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _platform = platform,
        _logger = logger;

  final CastPlatform _platform;
  final HomeDeliveryLogger _logger;

  double? _savedVolume;
  CastReceiver? _connected;

  CastReceiver? get connected => _connected;

  /// Discover and connect to the saved Cast [deviceId].
  Future<CastReceiver> connectById(
    String deviceId, {
    Duration budget = const Duration(seconds: 8),
  }) async {
    final found = await _platform.discover(budget: budget);
    CastReceiver? match;
    for (final device in found) {
      if (device.deviceId == deviceId) {
        match = device;
        break;
      }
    }
    if (match == null) {
      throw CastTargetMissingFailure(
        'Saved Cast device id $deviceId not discoverable',
      );
    }

    try {
      await _platform.connect(match);
    } catch (e, st) {
      if (e is CastConnectFailure) rethrow;
      _logger.error(
        'Cast connect failed',
        tag: 'CastClient',
        error: e,
        stackTrace: st,
      );
      throw CastConnectFailure('Connect failed: $e', cause: e);
    }
    _connected = match;
    return match;
  }

  /// Save current volume, then set [playbackVolume] (0.0–1.0).
  Future<void> applyPlaybackVolume(double playbackVolume) async {
    _savedVolume = await _platform.getVolume();
    await _platform.setVolume(playbackVolume.clamp(0.0, 1.0));
    _logger.info(
      'Volume $_savedVolume → $playbackVolume',
      tag: 'CastClient',
    );
  }

  /// Restore volume saved by [applyPlaybackVolume], if any.
  Future<void> restoreVolume() async {
    final saved = _savedVolume;
    if (saved == null) return;
    try {
      await _platform.setVolume(saved);
      _logger.info('Volume restored to $saved', tag: 'CastClient');
    } catch (e, st) {
      _logger.warn(
        'Failed to restore volume',
        tag: 'CastClient',
        error: e,
        stackTrace: st,
      );
    } finally {
      _savedVolume = null;
    }
  }

  /// §4.8 — abort if the receiver is already playing our adzan contentId.
  Future<void> assertNotAlreadyPlaying(String contentId) async {
    final status = await _platform.currentMedia();
    if (status != null &&
        status.isPlaying &&
        status.contentId == contentId) {
      throw CastAlreadyPlayingFailure(contentId);
    }
  }

  /// loadMedia with buffered stream type (§5.3).
  Future<void> loadAdzan({
    required String contentId,
    required Uri contentUrl,
  }) async {
    try {
      await _platform.loadMedia(
        contentId: contentId,
        contentUrl: contentUrl,
        contentType: 'audio/mpeg',
      );
    } catch (e, st) {
      if (e is CastLoadMediaFailure) rethrow;
      _logger.error(
        'loadMedia failed',
        tag: 'CastClient',
        error: e,
        stackTrace: st,
      );
      throw CastLoadMediaFailure('loadMedia failed: $e', cause: e);
    }
  }

  Stream<CastPlaybackEvent> get playbackEvents => _platform.playbackEvents;

  Future<void> endSession({bool restoreVolumeFirst = true}) async {
    if (restoreVolumeFirst) {
      await restoreVolume();
    }
    try {
      await _platform.endSession();
    } catch (e, st) {
      _logger.warn(
        'endSession failed',
        tag: 'CastClient',
        error: e,
        stackTrace: st,
      );
    }
    _connected = null;
  }

  /// Build the contentId used for §4.8 duplicate detection.
  static String contentIdFor({
    required String sessionId,
    required String voiceId,
  }) =>
      'adzan:$sessionId:$voiceId';
}

/// Production [CastPlatform] backed by `flutter_chrome_cast` + NSD for IPs.
final class FlutterCastPlatform implements CastPlatform {
  FlutterCastPlatform({HomeDeliveryLogger logger = const SilentLogger()})
      : _logger = logger;

  final HomeDeliveryLogger _logger;
  final _playbackController =
      StreamController<CastPlaybackEvent>.broadcast(sync: true);
  StreamSubscription<cast.GoggleCastMediaStatus?>? _mediaSub;

  @override
  Stream<CastPlaybackEvent> get playbackEvents => _playbackController.stream;

  @override
  Future<List<CastReceiver>> discover({required Duration budget}) async {
    final hostsById = await _browseCastHosts(budget);
    final discovery = cast.GoogleCastDiscoveryManager.instance;
    try {
      await discovery.startDiscovery();
    } catch (e, st) {
      _logger.error(
        'Cast discovery start failed',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
      throw CastTargetMissingFailure('Discovery failed: $e');
    }

    final seen = <String, CastReceiver>{};
    final sub = discovery.devicesStream.listen((devices) {
      for (final d in devices) {
        final host = hostsById[d.deviceID];
        if (host == null) continue;
        seen[d.deviceID] = CastReceiver(
          deviceId: d.deviceID,
          friendlyName: d.friendlyName,
          host: host,
        );
      }
    });

    await Future<void>.delayed(budget);
    await sub.cancel();
    try {
      await discovery.stopDiscovery();
    } catch (_) {}

    // Also surface NSD-only sightings (SDK list may lag).
    for (final entry in hostsById.entries) {
      seen.putIfAbsent(
        entry.key,
        () => CastReceiver(
          deviceId: entry.key,
          friendlyName: entry.key,
          host: entry.value,
        ),
      );
    }
    return seen.values.toList(growable: false);
  }

  Future<Map<String, InternetAddress>> _browseCastHosts(Duration budget) async {
    final found = <String, InternetAddress>{};
    nsd.Discovery? discovery;
    try {
      discovery = await nsd.startDiscovery(
        '_googlecast._tcp',
        autoResolve: true,
        ipLookupType: nsd.IpLookupType.any,
      );
      discovery.addServiceListener((service, status) {
        if (status != nsd.ServiceStatus.found) return;
        final txt = service.txt;
        if (txt == null) return;
        final idBytes = txt['id'];
        if (idBytes == null) return;
        final id = String.fromCharCodes(idBytes);
        final addresses = service.addresses;
        InternetAddress? host;
        if (addresses != null) {
          for (final a in addresses) {
            if (a.type == InternetAddressType.IPv4 && !a.isLoopback) {
              host = a;
              break;
            }
          }
        }
        if (host != null) {
          found[id] = host;
        }
      });
      await Future<void>.delayed(budget);
    } catch (e, st) {
      _logger.warn(
        'NSD cast host browse failed',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (discovery != null) {
        try {
          await nsd.stopDiscovery(discovery);
        } catch (_) {}
      }
    }
    return found;
  }

  @override
  Future<void> connect(CastReceiver receiver) async {
    final devices = cast.GoogleCastDiscoveryManager.instance.devices;
    cast.GoogleCastDevice? match;
    for (final d in devices) {
      if (d.deviceID == receiver.deviceId) {
        match = d;
        break;
      }
    }
    if (match == null) {
      throw CastConnectFailure(
        'Device ${receiver.deviceId} vanished before connect',
      );
    }
    final ok = await cast.GoogleCastSessionManager.instance
        .startSessionWithDevice(match);
    if (!ok) {
      throw CastConnectFailure('startSessionWithDevice returned false');
    }
    await _mediaSub?.cancel();
    _mediaSub = cast.GoogleCastRemoteMediaClient.instance.mediaStatusStream
        .listen((status) {
      if (status == null) return;
      switch (status.playerState) {
        case cast.CastMediaPlayerState.idle:
          _playbackController.add(CastPlaybackEvent.idle);
        case cast.CastMediaPlayerState.playing:
          _playbackController.add(CastPlaybackEvent.playing);
        default:
          _playbackController.add(CastPlaybackEvent.other);
      }
    });
  }

  @override
  Future<double> getVolume() async {
    final session = cast.GoogleCastSessionManager.instance.currentSession;
    return session?.currentDeviceVolume ?? 0.5;
  }

  @override
  Future<void> setVolume(double volume) async {
    cast.GoogleCastSessionManager.instance.setDeviceVolume(volume);
  }

  @override
  Future<CastMediaSnapshot?> currentMedia() async {
    final status = cast.GoogleCastRemoteMediaClient.instance.mediaStatus;
    final info = status?.mediaInformation;
    if (status == null || info == null) return null;
    return CastMediaSnapshot(
      contentId: info.contentId,
      isPlaying: status.playerState == cast.CastMediaPlayerState.playing,
    );
  }

  @override
  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
  }) {
    final info = cast.GoogleCastMediaInformation(
      contentId: contentId,
      streamType: cast.CastMediaStreamType.buffered,
      contentType: contentType,
      contentUrl: contentUrl,
    );
    return cast.GoogleCastRemoteMediaClient.instance.loadMedia(info);
  }

  @override
  Future<void> endSession() async {
    await _mediaSub?.cancel();
    _mediaSub = null;
    await cast.GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }
}

final class CastTargetMissingFailure implements Exception, OutcomeException {
  CastTargetMissingFailure(this.message);
  final String message;
  @override
  Outcome get outcome => Outcome.failedNoTarget;
  @override
  String toString() => 'CastTargetMissingFailure: $message';
}

final class CastConnectFailure implements Exception, OutcomeException {
  CastConnectFailure(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  Outcome get outcome => Outcome.failedCastConnect;
  @override
  String toString() => 'CastConnectFailure: $message';
}

final class CastLoadMediaFailure implements Exception, OutcomeException {
  CastLoadMediaFailure(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  Outcome get outcome => Outcome.failedLoadMedia;
  @override
  String toString() => 'CastLoadMediaFailure: $message';
}

final class CastAlreadyPlayingFailure implements Exception, OutcomeException {
  CastAlreadyPlayingFailure(this.contentId);
  final String contentId;
  @override
  Outcome get outcome => Outcome.suppressedAlreadyPlaying;
  @override
  String toString() =>
      'CastAlreadyPlayingFailure: already playing $contentId';
}
