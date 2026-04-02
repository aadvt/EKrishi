class TfliteResult {
  final String label; // e.g. tomato
  final String displayName; // e.g. Tomato
  final double confidence; // 0.0 to 1.0
  final bool isHighConfidence; // true if confidence >= 0.65

  TfliteResult({required this.label, required this.confidence})
    : isHighConfidence = confidence >= 0.65,
      displayName = label
          .split('_')
          .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
          .join(' ');
}
