class CachedPrice {
  final String cropNameEnglish;
  final String cropNameKannada;
  final String district;
  final String state;
  final double priceMin;
  final double priceMax;
  final double priceFair;
  final DateTime syncedAt;

  CachedPrice({
    required this.cropNameEnglish,
    required this.cropNameKannada,
    required this.district,
    required this.state,
    required this.priceMin,
    required this.priceMax,
    required this.priceFair,
    required this.syncedAt,
  });

  bool get isStale => DateTime.now().difference(syncedAt).inDays > 7;

  factory CachedPrice.fromJson(Map<String, dynamic> json) {
    return CachedPrice(
      cropNameEnglish: json['cropNameEnglish'] as String,
      cropNameKannada: json['cropNameKannada'] as String,
      district: json['district'] as String,
      state: json['state'] as String,
      priceMin: (json['priceMin'] as num).toDouble(),
      priceMax: (json['priceMax'] as num).toDouble(),
      priceFair: (json['priceFair'] as num).toDouble(),
      syncedAt: DateTime.parse(json['syncedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cropNameEnglish': cropNameEnglish,
      'cropNameKannada': cropNameKannada,
      'district': district,
      'state': state,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'priceFair': priceFair,
      'syncedAt': syncedAt.toIso8601String(),
    };
  }
}
