/// Single dhikr/duaa: Arabic text, Latin transliteration, translation,
/// how many times to read it, and where it is narrated.
final class AdhkarContent {
  const AdhkarContent({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.count,
    required this.source,
  });

  /// Stable key, also used for the per-item reading counter.
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final int count;

  /// Narration reference, e.g. "HR. Muslim".
  final String source;
}
