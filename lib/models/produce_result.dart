class ProduceResult {
  // Identification fields
  final String nameEnglish;
  final String nameKannada;
  final double confidence;
  final String category; // 'vegetable' or 'fruit'
  final String ripeness; // 'fresh', 'ripe', 'overripe'
  final String grade; // 'A', 'B', or 'C'
  final String gradeReasoning; // what Gemini observed about the produce
  final bool lowConfidence; // true if confidence < 0.70

  // Pricing fields (from Gemini)
  final double priceMinPerKg;
  final double priceMaxPerKg;
  final double priceFairPerKg;
  final double priceRecommendedMin; // priceFairPerKg * 0.9
  final double priceRecommendedMax; // priceFairPerKg * 1.1
  final String priceReasoning; // e.g. "Peak season in Karnataka"
  final String priceConfidence; // 'high', 'medium', or 'low'
  final bool isPriceEstimate; // always true — shown in UI as disclaimer

  ProduceResult({
    required this.nameEnglish,
    required this.nameKannada,
    required this.confidence,
    required this.category,
    required this.ripeness,
    required this.grade,
    required this.gradeReasoning,
    required this.lowConfidence,
    required this.priceMinPerKg,
    required this.priceMaxPerKg,
    required this.priceFairPerKg,
    required this.priceRecommendedMin,
    required this.priceRecommendedMax,
    required this.priceReasoning,
    required this.priceConfidence,
    required this.isPriceEstimate,
  });

  factory ProduceResult.fromJson(Map<String, dynamic> json) {
    final double fairPrice = (json['price_fair_per_kg'] as num).toDouble();
    final double confidence = (json['confidence'] as num).toDouble();

    return ProduceResult(
      nameEnglish: json['name_english'] ?? 'Unknown',
      nameKannada: json['name_kannada'] ?? 'ತಿಳಿದಿಲ್ಲ',
      confidence: confidence,
      category: json['category'] ?? 'other',
      ripeness: json['ripeness'] ?? 'unknown',
      grade: json['grade'] ?? 'B',
      gradeReasoning: json['grade_reasoning'] ?? '',
      lowConfidence: confidence < 0.70,
      priceMinPerKg: (json['price_min_per_kg'] as num).toDouble(),
      priceMaxPerKg: (json['price_max_per_kg'] as num).toDouble(),
      priceFairPerKg: fairPrice,
      priceRecommendedMin: fairPrice * 0.9,
      priceRecommendedMax: fairPrice * 1.1,
      priceReasoning: json['price_reasoning'] ?? '',
      priceConfidence: json['price_confidence'] ?? 'medium',
      isPriceEstimate: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name_english': nameEnglish,
      'name_kannada': nameKannada,
      'confidence': confidence,
      'category': category,
      'ripeness': ripeness,
      'grade': grade,
      'grade_reasoning': gradeReasoning,
      'low_confidence': lowConfidence,
      'price_min_per_kg': priceMinPerKg,
      'price_max_per_kg': priceMaxPerKg,
      'price_fair_per_kg': priceFairPerKg,
      'price_recommended_min': priceRecommendedMin,
      'price_recommended_max': priceRecommendedMax,
      'price_reasoning': priceReasoning,
      'price_confidence': priceConfidence,
      'is_price_estimate': isPriceEstimate,
    };
  }

  ProduceResult copyWith({
    String? gradeReasoning,
    String? priceReasoning,
    String? priceConfidence,
  }) {
    return ProduceResult(
      nameEnglish: nameEnglish,
      nameKannada: nameKannada,
      confidence: confidence,
      category: category,
      ripeness: ripeness,
      grade: grade,
      gradeReasoning: gradeReasoning ?? this.gradeReasoning,
      lowConfidence: lowConfidence,
      priceMinPerKg: priceMinPerKg,
      priceMaxPerKg: priceMaxPerKg,
      priceFairPerKg: priceFairPerKg,
      priceRecommendedMin: priceRecommendedMin,
      priceRecommendedMax: priceRecommendedMax,
      priceReasoning: priceReasoning ?? this.priceReasoning,
      priceConfidence: priceConfidence ?? this.priceConfidence,
      isPriceEstimate: isPriceEstimate,
    );
  }
}
