/// Heuristics for Cast discovery: keep speakers / groups, hide TV-like targets.
library;

final _groupWord = RegExp(r'\bgroup\b');

final _tvPlatform = RegExp(
  r'smart\s*tv|android\s*tv|google\s*tv|google\s*streamer|'
  r'roku(\s*tv)?|fire\s*tv|firestick|fire\s*stick|webos|tizen|vidaa|'
  r'chromecast\s+with\s+google\s+tv|chromecast\s*(hd|4k|ultra)|'
  r'(tv|android)\s*box|onn\s*google',
);

final _tvWord = RegExp(r'\btv\b|television');

/// Nest Hub / Hub Max and similar Cast speakers with a screen — not TVs.
final _nestHubSpeaker = RegExp(
  r'nest\s*hub|\bhub max\b|google\s*nest\s*hub|'
  r'smart\s*display|lenovo\s*smart\s*display',
);

final _panelTech = RegExp(
  r'\b(oled|qled|neo\s*qled|mini[\s-]?led|uhd|4k|8k|hdr)\b',
);

final _tvBrand = RegExp(
  r'\b(bravia|hisense|vizio|aquos|toshiba|skyworth|changhong|konka|'
  r'nvidia\s*shield|shield\s*tv|mi\s*(box|tv)|xiaomi\s*tv|redmi\s*tv|'
  r'realme\s*tv|oneplus\s*tv|philips\s*tv|panasonic\s*tv|samsung\s*tv|'
  r'lg\s*(tv|oled|nano|qned)|sony\s*tv|tcl\s*(tv|qled|c\d)|'
  r'sharp\s*tv|element\s*tv|insignia|westinghouse|prism)\b',
);

/// Typical TV SKUs: Samsung QN55 / AU8000, LG OLED55, Sony XR-55,
/// Hisense/TCL Q55U, TCL 55C745, Philips PUS8507, The Frame.
final _tvSku = RegExp(
  r'\b(qn|un|au|tu|qe|ua)\d{2,4}'
  r'|\boled\d{2}'
  r'|\b(xr|kd|kdl|xbr)[-_]?\d{2}'
  r'|\b(nano|qned|uq|up|uk|sk|sm)\d{2,4}'
  r'|\bq\d{2}[a-z]?\b'
  r'|\bu[6-8]\d?[a-z]\b'
  r'|\ba[6-8][a-z]\b'
  r'|\b(32|40|43|49|50|55|58|65|70|75|77|83|85|86|98)[- ]?(inch|in|")\b'
  r'|\b(32|40|43|50|55|65|75)[a-z]\d{2,4}\b'
  r'|\b(32|40|43|50|55|65|75)(nano|qned|oled|uq|un|up|uk)'
  r'|\bpus\d{4}|\b(tx|th)[-_]\d{2}|\b4t-c\d{2}|\bl\d{2}m\d'
  r'|\bthe frame\b|\bthe serif\b|\bthe preview\b|\bcrystal\s*uhd\b',
);

/// True when [friendlyName] looks like a TV or Cast stick.
///
/// Keeps Chromecast Audio, Nest Hub, Nest speakers, soundbars, and groups.
bool looksLikeTvCastTarget(String friendlyName) {
  final n = friendlyName.toLowerCase().trim();
  if (n.isEmpty) return false;

  if (_groupWord.hasMatch(n)) {
    return false;
  }

  if (_nestHubSpeaker.hasMatch(n)) {
    return false;
  }

  final speakerLike = n.contains('speaker') ||
      n.contains('soundbar') ||
      n.contains('sound bar') ||
      n.contains('streambar') ||
      n.contains('nest mini') ||
      n.contains('nest audio') ||
      n.contains('chromecast audio') ||
      n.contains('google home mini');
  // "TV speaker" / soundbar names stay. Bare TV / display names do not.
  if (speakerLike && !n.contains('chromecast')) {
    return false;
  }

  if (_tvPlatform.hasMatch(n) ||
      _tvWord.hasMatch(n) ||
      _panelTech.hasMatch(n) ||
      _tvBrand.hasMatch(n) ||
      _tvSku.hasMatch(n)) {
    return true;
  }

  if (n.contains('chromecast')) {
    return !n.contains('audio') && !n.contains('speaker');
  }

  return false;
}

/// True when [friendlyName] looks like a Google Home / Cast speaker group.
bool looksLikeCastGroup(String friendlyName) {
  final n = friendlyName.toLowerCase().trim();
  if (n.isEmpty) return false;
  return _groupWord.hasMatch(n);
}

/// Speakers / groups suitable for home adhan delivery.
List<T> filterSpeakerCastTargets<T>(
  Iterable<T> devices,
  String Function(T) friendlyNameOf,
) {
  return devices
      .where((d) => !looksLikeTvCastTarget(friendlyNameOf(d)))
      .toList(growable: false);
}
