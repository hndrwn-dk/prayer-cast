import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart' as cast;
import 'package:nsd/nsd.dart' as nsd;

import '../common/logger.dart';
import '../logging/outcome.dart';
import 'cast_init.dart';

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
    this.title,
  });

  /// Receiver contentId — often the HTTP URL after Xiaomi/loadAdzan.
  final String contentId;

  /// Music metadata title — still `adzan:$sessionId:$voiceId` on load.
  final String? title;
  final bool isPlaying;
}

/// Port over the Cast SDK so unit tests never touch real hardware.
abstract interface class CastPlatform {
  /// Discover devices for up to [budget]; return current sightings.
  ///
  /// When [matchId] is set, return as soon as that Cast id has a LAN address
  /// instead of waiting out the full budget (scheduled prepare cannot afford
  /// a fixed 8–12s stall).
  Future<List<CastReceiver>> discover({
    required Duration budget,
    String? matchId,
  });

  Future<void> connect(CastReceiver receiver);

  /// Load CastContext / MediaRouter before startSession.
  ///
  /// First CastSession after GMS Dynamite module load can exceed the
  /// T-20 prepare wait if this is skipped. Call at wake (T-120).
  Future<void> warmUp();

  Future<double> getVolume();

  Future<void> setVolume(double volume);

  Future<CastMediaSnapshot?> currentMedia();

  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
    String? title,
  });

  /// Wait until the Cast session can accept loadMedia.
  ///
  /// Native `startSessionWithDevice` returns true as soon as the route is
  /// selected; session `connected` can fire before `RemoteMediaClient` exists
  /// (Home group speakers). `RemoteMediaClient.load` is a silent no-op until
  /// that client is non-null. Callers must wait here or loadMedia is dropped.
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 20),
  });

  /// Emits when the receiver reports IDLE/FINISHED after loadMedia.
  Stream<CastPlaybackEvent> get playbackEvents;

  Future<void> endSession();
}

enum CastPlaybackEvent { idle, finished, playing, error, other }

/// Discovery policy: NSD `_googlecast._tcp` is unauthenticated.
///
/// A guest can re-advertise the saved Cast id with a poison A-record.
/// Early-exit and interface selection must not treat that as a hit.
final class CastDiscoveryPolicy {
  /// True when the Cast SDK has sighted [matchId]. NSD-only is not enough.
  static bool sdkConfirmedMatch({
    required String? matchId,
    required Iterable<String> sdkDeviceIds,
  }) {
    if (matchId == null || matchId.isEmpty) return false;
    for (final id in sdkDeviceIds) {
      if (id == matchId) return true;
    }
    return false;
  }
}

/// Cast SDK id → friendly name.
///
/// [GoogleCastDiscoveryManager.devicesStream] does not replay the current
/// list. After [warmUp] starts discovery at T−120, connect at T−20 must
/// seed from the snapshot or it waits the full budget for an emission
/// that never comes (Isha 2026-09-03 FAILED_NO_TARGET while Home / NSD
/// still showed the saved speaker).
abstract final class CastSdkDeviceMap {
  static void put(
    Map<String, String> into, {
    required String deviceId,
    required String friendlyName,
  }) {
    if (deviceId.isEmpty) return;
    into[deviceId] = friendlyName;
  }
}

/// MediaRouter can lag NSD at cold wake. Fajr 2026-08-14: mDNS had the
/// Bedroom speaker (Signal A HOME) but `devices` was empty at connect.
/// Fajr 2026-09-05: discover returned an NSD-only id, then connect threw
/// "vanished before connect" — refresh discovery while waiting.
final class CastSdkDeviceWait {
  static const Duration timeout = Duration(seconds: 12);
  static const Duration poll = Duration(milliseconds: 250);
  static const Duration refreshEvery = Duration(seconds: 2);

  static Future<T> untilPresent<T>({
    required String deviceId,
    required Iterable<T> Function() devices,
    required String Function(T device) idOf,
    Duration timeout = CastSdkDeviceWait.timeout,
    Duration poll = CastSdkDeviceWait.poll,
    DateTime Function()? now,
    Future<void> Function(Duration delay)? delay,
    Future<void> Function()? refresh,
  }) async {
    final clock = now ?? DateTime.now;
    final sleep = delay ?? Future<void>.delayed;
    final deadline = clock().add(timeout);
    var lastRefresh = clock().subtract(refreshEvery);
    while (true) {
      for (final device in devices()) {
        if (idOf(device) == deviceId) return device;
      }
      if (!clock().isBefore(deadline)) {
        throw CastConnectFailure(
          'Device $deviceId vanished before connect',
        );
      }
      if (refresh != null &&
          !clock().isBefore(lastRefresh.add(refreshEvery))) {
        lastRefresh = clock();
        try {
          await refresh();
        } catch (_) {}
      }
      await sleep(poll);
    }
  }
}

/// Whether native `RemoteMediaClient.load` will actually run.
///
/// Session-connected (route selected) is not enough — Isha 2026-08-13
/// loaded 0 bytes because load ran before the media client existed.
final class CastLoadReadiness {
  static bool isLoadable({
    required bool sessionConnected,
    required bool mediaClientReady,
  }) =>
      sessionConnected && mediaClientReady;
}

/// Native startSession returns true on MediaRouter.selectRoute. The Cast
/// session often has not connected yet — CastSession.<init> plus GMS
/// DynamiteModulesC load (group speakers / cold Fajr) can take longer than
/// one short wait. Retry startSession once without ending the in-flight
/// session; second wait is longer for Dynamite.
final class CastSessionConnect {
  static const Duration firstWait = Duration(seconds: 20);
  static const Duration retryWait = Duration(seconds: 40);

  static Future<void> run({
    required Future<bool> Function() startSession,
    required Future<void> Function(Duration timeout) waitUntilReady,
    required Future<bool> Function() sessionConnected,
    void Function(String message)? log,
  }) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      final connected = await sessionConnected();
      if (attempt == 1 || !connected) {
        final ok = await startSession();
        if (!ok) {
          throw CastConnectFailure('startSessionWithDevice returned false');
        }
      }
      final wait = attempt == 1 ? firstWait : retryWait;
      try {
        await waitUntilReady(wait);
        return;
      } on CastConnectFailure {
        if (attempt == 2) rethrow;
        if (await sessionConnected()) {
          log?.call(
            'Cast session connected but not loadable after '
            '${wait.inSeconds}s; waiting longer (no restart)',
          );
        } else {
          log?.call(
            'Cast session not connected after ${wait.inSeconds}s; '
            'retrying startSession (GMS Dynamite / session init)',
          );
        }
      }
    }
  }
}

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
  double? _playbackVolume;
  CastReceiver? _connected;

  CastReceiver? get connected => _connected;

  Future<void> warmUp() => _platform.warmUp();

  /// Discover and connect to the saved Cast [deviceId].
  ///
  /// Retries once after [warmUp] when MediaRouter drops the device between
  /// discover and startSession (Fajr 2026-09-05: "vanished before connect"
  /// while Dhuhr later PLAYED).
  Future<CastReceiver> connectById(
    String deviceId, {
    Duration budget = const Duration(seconds: 12),
  }) async {
    CastConnectFailure? lastConnect;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        _logger.warn(
          'connectById retry after MediaRouter miss for $deviceId',
          tag: 'CastClient',
        );
        await warmUp();
      }
      final found = await _platform.discover(
        budget: attempt == 0 ? budget : budget + const Duration(seconds: 8),
        matchId: deviceId,
      );
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
        _connected = match;
        return match;
      } on CastConnectFailure catch (e, st) {
        lastConnect = e;
        _logger.warn(
          'Cast connect attempt ${attempt + 1} failed: $e',
          tag: 'CastClient',
          error: e,
          stackTrace: st,
        );
      } catch (e, st) {
        _logger.error(
          'Cast connect failed',
          tag: 'CastClient',
          error: e,
          stackTrace: st,
        );
        throw CastConnectFailure('Connect failed: $e', cause: e);
      }
    }
    throw lastConnect!;
  }

  /// Keep the speaker's current volume when it is already audible.
  ///
  /// [playbackVolume] is only applied if the receiver is muted (0). The
  /// 00:41 dry-run logged `0.18 → 0.7` because we always forced the
  /// hardcoded default — the user's 18% became a loud adhan.
  ///
  /// Waits for the media client first — setVolume on a group before
  /// RemoteMediaClient exists is a no-op.
  Future<void> applyPlaybackVolume(double playbackVolume) async {
    await _platform.waitUntilReady();
    final current = await _platform.getVolume();
    _savedVolume = current;
    if (current > 0.0) {
      _playbackVolume = current.clamp(0.0, 1.0);
      _logger.info(
        'Volume keep $current (skip boost to $playbackVolume)',
        tag: 'CastClient',
      );
      return;
    }
    _playbackVolume = playbackVolume.clamp(0.0, 1.0);
    await _platform.setVolume(_playbackVolume!);
    _logger.info(
      'Volume $current → $_playbackVolume (was muted)',
      tag: 'CastClient',
    );
  }

  /// Restore volume saved by [applyPlaybackVolume], if any.
  ///
  /// Never restore 0. Maghrib/Isha 2026-08-13: getVolume returned 0 (muted
  /// leftover or unread session), we set 0.7, then restored 0 — speaker
  /// blipped and went silent. A saved 0 is not a user preference.
  Future<void> restoreVolume() async {
    final saved = _savedVolume;
    if (saved == null) return;
    if (saved <= 0.0) {
      _logger.info(
        'Skip restore of volume 0 (would mute speaker)',
        tag: 'CastClient',
      );
      _savedVolume = null;
      return;
    }
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

  /// §4.8 — abort if the receiver is already playing this session's adzan.
  ///
  /// loadAdzan puts the HTTP URL in Cast `contentId` (Xiaomi fetches that
  /// field). The logical `adzan:$sessionId:$voiceId` is the metadata title.
  Future<void> assertNotAlreadyPlaying(String contentId) async {
    final status = await _platform.currentMedia();
    if (status != null &&
        status.isPlaying &&
        isSameAdzan(logicalId: contentId, status: status)) {
      throw CastAlreadyPlayingFailure(contentId);
    }
  }

  /// True when [status] is this session's adzan (URL contentId or title).
  static bool isSameAdzan({
    required String logicalId,
    required CastMediaSnapshot status,
  }) {
    if (status.contentId == logicalId) return true;
    final title = status.title;
    if (title != null && title.isNotEmpty && title == logicalId) {
      return true;
    }
    return false;
  }

  /// loadMedia with buffered stream type (§5.3).
  ///
  /// [contentId] is kept for duplicate checks / logging. The Cast SDK is given
  /// the HTTP [contentUrl] as both `contentId` and `contentUrl` — some
  /// receivers (incl. Xiaomi Cast) ignore `contentUrl` and fetch `contentId`.
  Future<void> loadAdzan({
    required String contentId,
    required Uri contentUrl,
    String contentType = 'audio/mpeg',
    String? title,
  }) async {
    try {
      await _platform.waitUntilReady();
      final volume = _playbackVolume;
      if (volume != null) {
        await _platform.setVolume(volume);
      }
      await _platform.loadMedia(
        contentId: contentUrl.toString(),
        contentUrl: contentUrl,
        contentType: contentType,
        title: title ?? contentId,
      );
    } catch (e, st) {
      if (e is CastLoadMediaFailure || e is CastConnectFailure) rethrow;
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
  FlutterCastPlatform({
    HomeDeliveryLogger logger = const SilentLogger(),
    MethodChannel? mediaReadyChannel,
  })  : _logger = logger,
        _mediaReadyChannel = mediaReadyChannel ??
            const MethodChannel('prayer_cast/cast_ready');

  final HomeDeliveryLogger _logger;
  final MethodChannel _mediaReadyChannel;
  final _playbackController =
      StreamController<CastPlaybackEvent>.broadcast(sync: true);
  StreamSubscription<cast.GoggleCastMediaStatus?>? _mediaSub;

  @override
  Stream<CastPlaybackEvent> get playbackEvents => _playbackController.stream;

  @override
  Future<List<CastReceiver>> discover({
    required Duration budget,
    String? matchId,
  }) async {
    await _ensureCastContext();
    final hostsById = <String, InternetAddress>{};
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

    final sdkDevices = <String, String>{};
    void ingestSdk(Iterable devices) {
      for (final d in devices) {
        CastSdkDeviceMap.put(
          sdkDevices,
          deviceId: d.deviceID,
          friendlyName: d.friendlyName,
        );
      }
    }

    ingestSdk(discovery.devices);
    final sub = discovery.devicesStream.listen(ingestSdk);

    nsd.Discovery? nsdDiscovery;
    try {
      nsdDiscovery = await nsd.startDiscovery(
        '_googlecast._tcp',
        autoResolve: true,
        ipLookupType: nsd.IpLookupType.any,
      );
      nsdDiscovery.addServiceListener((service, status) {
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
          hostsById[id] = host;
        }
      });
    } catch (e, st) {
      _logger.warn(
        'NSD cast host browse failed',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
    }

    // NSD + SDK in parallel. Re-read discovery.devices every tick — the
    // stream does not always emit when MediaRouter updates in place
    // (Dhuhr 2026-09-04). Early-exit when the Cast SDK has sighted
    // [matchId] — an NSD TXT/A-record alone can be spoofed on the LAN.
    final deadline = DateTime.now().add(budget);
    var restartedForNsdHit = false;
    while (DateTime.now().isBefore(deadline)) {
      ingestSdk(discovery.devices);
      if (CastDiscoveryPolicy.sdkConfirmedMatch(
        matchId: matchId,
        sdkDeviceIds: sdkDevices.keys,
      )) {
        break;
      }
      // NSD already sees the saved id but SDK is empty — kick MediaRouter
      // once and keep waiting until the original deadline.
      if (!restartedForNsdHit &&
          matchId != null &&
          matchId.isNotEmpty &&
          hostsById.containsKey(matchId) &&
          !sdkDevices.containsKey(matchId)) {
        restartedForNsdHit = true;
        _logger.warn(
          'NSD saw $matchId but Cast SDK empty — restarting discovery',
          tag: 'FlutterCastPlatform',
        );
        try {
          await discovery.startDiscovery();
        } catch (_) {}
        ingestSdk(discovery.devices);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    await sub.cancel();
    // Leave Cast MediaRouter discovery running. stopDiscovery() removes the
    // callback that selectRoute/startSession needs; scheduled group connect
    // then dies after CastSession.<init> + Dynamite load.
    if (nsdDiscovery != null) {
      try {
        await nsd.stopDiscovery(nsdDiscovery);
      } catch (_) {}
    }

    ingestSdk(discovery.devices);
    final seen = <String, CastReceiver>{};
    for (final entry in sdkDevices.entries) {
      // NSD host is a hint only — InterfaceSelector must not fail closed
      // if it is a poison off-subnet A-record.
      final host = hostsById[entry.key] ?? InternetAddress.anyIPv4;
      seen[entry.key] = CastReceiver(
        deviceId: entry.key,
        friendlyName: entry.value,
        host: host,
      );
    }
    // Speaker-scan UI may still list NSD-only sightings.
    if (matchId == null) {
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
    } else if (!seen.containsKey(matchId) && hostsById.containsKey(matchId)) {
      // Scheduled connect: do not fail CLOSED before CastSdkDeviceWait —
      // HOME/Signal A already trusted this id on NSD; give connect() more
      // time for MediaRouter to catch up.
      _logger.warn(
        'Returning NSD-only sighting for $matchId so connect can wait on SDK',
        tag: 'FlutterCastPlatform',
      );
      seen[matchId] = CastReceiver(
        deviceId: matchId,
        friendlyName: matchId,
        host: hostsById[matchId]!,
      );
    }
    return seen.values.toList(growable: false);
  }

  @override
  Future<void> warmUp() async {
    await _ensureCastContext();
    try {
      await cast.GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (e, st) {
      _logger.warn(
        'Cast warm-up discovery failed',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> connect(CastReceiver receiver) async {
    await _ensureCastContext();
    try {
      await cast.GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (_) {}

    final discovery = cast.GoogleCastDiscoveryManager.instance;
    // Cold Fajr: NSD may have returned the id while MediaRouter is still
    // empty — keep restarting discovery until the SDK lists the device.
    final match = await CastSdkDeviceWait.untilPresent(
      deviceId: receiver.deviceId,
      devices: () => discovery.devices,
      idOf: (d) => d.deviceID,
      timeout: const Duration(seconds: 40),
      refresh: () async {
        try {
          await discovery.startDiscovery();
        } catch (_) {}
      },
    );
    final mgr = cast.GoogleCastSessionManager.instance;
    await CastSessionConnect.run(
      startSession: () => mgr.startSessionWithDevice(match),
      waitUntilReady: (timeout) => waitUntilReady(timeout: timeout),
      sessionConnected: () async =>
          mgr.hasConnectedSession || await _isSessionConnected(),
      log: (msg) => _logger.warn(msg, tag: 'FlutterCastPlatform'),
    );
    await _mediaSub?.cancel();
    _mediaSub = cast.GoogleCastRemoteMediaClient.instance.mediaStatusStream
        .listen((status) {
      if (status == null) return;
      switch (status.playerState) {
        case cast.CastMediaPlayerState.idle:
          final reason = status.idleReason;
          if (reason == cast.GoogleCastMediaIdleReason.finished) {
            _playbackController.add(CastPlaybackEvent.finished);
          } else if (reason == cast.GoogleCastMediaIdleReason.error) {
            _logger.warn(
              'Cast media idle with ERROR reason',
              tag: 'FlutterCastPlatform',
            );
            _playbackController.add(CastPlaybackEvent.error);
          } else {
            _playbackController.add(CastPlaybackEvent.idle);
          }
        case cast.CastMediaPlayerState.playing:
          _playbackController.add(CastPlaybackEvent.playing);
        default:
          _playbackController.add(CastPlaybackEvent.other);
      }
    });
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final mgr = cast.GoogleCastSessionManager.instance;
    var loggedConnected = false;
    // Poll Dart stream state and native CastSession.isConnected. Waiting
    // only on currentSessionStream misses connects that land during GMS
    // Dynamite load after CastSession.<init>.
    while (DateTime.now().isBefore(deadline)) {
      final sessionOk =
          mgr.hasConnectedSession || await _isSessionConnected();
      if (sessionOk && !loggedConnected) {
        _logger.info('Cast session connected', tag: 'FlutterCastPlatform');
        loggedConnected = true;
      }
      if (sessionOk && await _isMediaClientReady()) {
        _logger.info(
          'Cast media client ready',
          tag: 'FlutterCastPlatform',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final sessionOk =
        mgr.hasConnectedSession || await _isSessionConnected();
    if (!sessionOk) {
      throw CastConnectFailure(
        'Cast session not connected within ${timeout.inSeconds}s',
      );
    }
    throw CastConnectFailure(
      'Cast RemoteMediaClient not ready within ${timeout.inSeconds}s '
      '(session connected is not enough; load is a no-op until then)',
    );
  }

  Future<void> _ensureCastContext() async {
    // Native getSharedInstance warms GMS Dynamite off the UI isolate.
    // Do not skip Dart setSharedInstanceWithOptions when native succeeds:
    // the plugin's devicesStream is empty until the Dart Cast context exists
    // (Isha 2026-09-03 after Kotlin warm-up returned true first).
    try {
      await _mediaReadyChannel
          .invokeMethod<bool>('ensureCastContext')
          .timeout(const Duration(seconds: 8));
    } on MissingPluginException {
      // Tests / iOS.
    } on TimeoutException catch (e, st) {
      _logger.warn(
        'ensureCastContext timed out',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'ensureCastContext failed',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
    }
    try {
      await initGoogleCast().timeout(const Duration(seconds: 4));
    } catch (e, st) {
      _logger.warn(
        'initGoogleCast during connect failed',
        tag: 'FlutterCastPlatform',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> _isSessionConnected() async {
    try {
      final connected =
          await _mediaReadyChannel.invokeMethod<bool>('isSessionConnected');
      return connected ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _isMediaClientReady() async {
    try {
      final ready =
          await _mediaReadyChannel.invokeMethod<bool>('isMediaClientReady');
      return ready ?? false;
    } on MissingPluginException {
      // iOS / tests without the Android probe — session connected is the
      // best signal the plugin exposes.
      return true;
    } on PlatformException {
      return false;
    }
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
    String? title;
    final meta = info.metadata;
    if (meta is cast.GoogleCastMusicMediaMetadata) {
      title = meta.title;
    }
    return CastMediaSnapshot(
      contentId: info.contentId,
      title: title,
      isPlaying: status.playerState == cast.CastMediaPlayerState.playing,
    );
  }

  @override
  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
    String? title,
  }) async {
    await waitUntilReady();
    final info = cast.GoogleCastMediaInformation(
      contentId: contentId,
      streamType: cast.CastMediaStreamType.buffered,
      contentType: contentType,
      contentUrl: contentUrl,
      metadata: cast.GoogleCastMusicMediaMetadata(
        title: title ?? 'Adzan',
        artist: 'Prayer Cast',
      ),
    );
    _logger.info(
      'loadMedia contentId=$contentId url=$contentUrl type=$contentType',
      tag: 'FlutterCastPlatform',
    );
    return cast.GoogleCastRemoteMediaClient.instance.loadMedia(
      info,
      autoPlay: true,
    );
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
