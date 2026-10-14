/// Single dhikr/duaa content with Arabic text, translation, and repetition count.
final class AdhkarContent {
  const AdhkarContent({
    required this.arabic,
    required this.translation,
    required this.count,
    this.transliteration,
  });

  final String arabic;
  final String translation;
  final int count;
  final String? transliteration;
}
