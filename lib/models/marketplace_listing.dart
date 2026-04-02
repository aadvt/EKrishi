class MarketplaceListing {
  final String id;
  final String farmerPhone;
  final String cropNameEnglish;
  final String cropNameKannada;
  final double priceFairPerKg;
  final double priceMinPerKg;
  final double priceMaxPerKg;
  final String grade;
  final String ripeness;
  final String district;
  final String state;
  final String priceSource;
  final DateTime listedAt;
  final bool isOfflineListing;

  const MarketplaceListing({
    required this.id,
    required this.farmerPhone,
    required this.cropNameEnglish,
    required this.cropNameKannada,
    required this.priceFairPerKg,
    required this.priceMinPerKg,
    required this.priceMaxPerKg,
    required this.grade,
    required this.ripeness,
    required this.district,
    required this.state,
    required this.priceSource,
    required this.listedAt,
    required this.isOfflineListing,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmer_phone': farmerPhone,
      'crop_name_english': cropNameEnglish,
      'crop_name_kannada': cropNameKannada,
      'price_fair_per_kg': priceFairPerKg,
      'price_min_per_kg': priceMinPerKg,
      'price_max_per_kg': priceMaxPerKg,
      'grade': grade,
      'ripeness': ripeness,
      'district': district,
      'state': state,
      'price_source': priceSource,
      'listed_at': listedAt.toIso8601String(),
      'is_offline_listing': isOfflineListing,
    };
  }
}
