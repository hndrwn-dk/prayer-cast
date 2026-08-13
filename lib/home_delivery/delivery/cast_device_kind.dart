/// Heuristics for Cast discovery: keep speakers / groups, hide TV-like targets.
library;

/// True when [friendlyName] looks like a TV or non-speaker Cast stick.
///
/// Keeps Chromecast Audio, Nest/speakers, and Google Home groups. Hides names
/// matching TV / Android TV / plain Chromecast (not audio).
bool looksLikeTvCastTarget(String friendlyName) {
  final n = friendlyName.toLowerCase().trim();
  if (n.isEmpty) return false;

  // Groups stay selectable for home speaker (multi-room / speaker group).
  if (RegExp(r'\bgroup\b').hasMatch(n)) {
    return false;
  }

  if (n.contains('television') ||
      n.contains('smart tv') ||
      n.contains('android tv') ||
      RegExp(r'\btv\b').hasMatch(n)) {
    return true;
  }

  if (n.contains('chromecast')) {
    final audioLike = n.contains('audio') ||
        n.contains('speaker') ||
        n.contains('nest mini') ||
        n.contains('nest audio');
    return !audioLike;
  }

  return false;
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
