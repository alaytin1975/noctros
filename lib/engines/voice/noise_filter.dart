/// Lightweight offline noise / transcript cleanup for STT results.
class NoiseFilter {
  const NoiseFilter();

  /// Removes filler noise tokens and collapses whitespace.
  String cleanTranscript(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      return text;
    }

    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(
      RegExp(
        r'\b(um+|uh+|erm+|ah+|hmm+)\b',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// True when transcript looks like ambient noise / garbage.
  bool isLikelyNoise(String input, {double confidence = 1.0}) {
    final cleaned = cleanTranscript(input);
    if (cleaned.isEmpty) {
      return true;
    }
    if (confidence > 0 && confidence < 0.35 && cleaned.length < 4) {
      return true;
    }
    if (RegExp(r'^[^a-zA-Z0-9]+$').hasMatch(cleaned)) {
      return true;
    }
    return false;
  }
}
