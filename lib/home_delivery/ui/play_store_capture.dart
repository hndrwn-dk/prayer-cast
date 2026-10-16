import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/play_store_caption_bar.dart';
import 'package:prayer_cast/prayer_times/ui/prayer_settings_page.dart';

/// Capture-only Play Store framing. Enable with
/// `--dart-define=PLAY_STORE_CAPTURE=true`. Reads
/// `play_store_shot.txt` in app documents (`01-en` … `04-id`).
abstract final class PlayStoreCapture {
  static const enabled = bool.fromEnvironment('PLAY_STORE_CAPTURE');

  static const _captions = <String, String>{
    '01-en': 'Adhan at the right time, even when the phone sleeps.',
    '01-id': 'Adzan di waktunya, termasuk saat HP tidur.',
    '02-en': 'Adhan on the speaker at home.',
    '02-id': 'Adzan di speaker rumah.',
    '03-en': 'No speaker? Play adhan or a beep on the phone.',
    '03-id': 'Tanpa speaker? Adzan atau beep di HP.',
    '04-en': 'Nudge before azan, and again at iqamah.',
    '04-id': 'Pengingat sebelum azan, dan lagi saat iqamah.',
  };

  static Future<String?> readShotId() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'play_store_shot.txt'));
    if (!await file.exists()) return null;
    final raw = (await file.readAsString()).trim().toLowerCase();
    return _captions.containsKey(raw) ? raw : null;
  }

  static String? captionFor(String shotId) => _captions[shotId];
}

/// Root navigator key used only while [PlayStoreCapture.enabled].
final GlobalKey<NavigatorState> playStoreNavigatorKey =
    GlobalKey<NavigatorState>();

/// Overlays [PlayStoreCaptionBar] and opens the shot route once.
class PlayStoreCaptureLayer extends StatefulWidget {
  const PlayStoreCaptureLayer({super.key, required this.child});

  final Widget child;

  @override
  State<PlayStoreCaptureLayer> createState() => _PlayStoreCaptureLayerState();
}

class _PlayStoreCaptureLayerState extends State<PlayStoreCaptureLayer> {
  String? _caption;
  var _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final shotId = await PlayStoreCapture.readShotId();
    if (!mounted || shotId == null) return;
    setState(() => _caption = PlayStoreCapture.captionFor(shotId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openShot(shotId);
    });
  }

  Future<void> _openShot(String shotId) async {
    if (_navigated) return;
    _navigated = true;
    // Let OnboardingGate resolve and home paint first.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final nav = playStoreNavigatorKey.currentState;
    if (nav == null || !mounted) return;
    final stem = shotId.substring(0, 2);
    // 01 + 02 stay on home (02 sells the speaker band / Living Room line).
    switch (stem) {
      case '03':
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const PrayerSettingsPage(focus: PrayerSettingsFocus.delivery),
          ),
        );
      case '04':
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const PrayerSettingsPage(focus: PrayerSettingsFocus.reminders),
          ),
        );
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _caption;
    if (caption == null || caption.isEmpty) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        PlayStoreCaptionBar(text: caption),
      ],
    );
  }
}
