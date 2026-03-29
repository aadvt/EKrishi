class ScanHistory {
  final String produceNameEnglish;
  final String produceNameKannada;
  final double fairPrice;
  final String district;
  final DateTime scannedAt;
  final String imagePath;

  ScanHistory({
    required this.produceNameEnglish,
    required this.produceNameKannada,
    required this.fairPrice,
    required this.district,
    required this.scannedAt,
    required this.imagePath,
  });

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    return ScanHistory(
      produceNameEnglish: json['produce_name_english'] ?? '',
      produceNameKannada: json['produce_name_kannada'] ?? '',
      fairPrice: (json['fair_price'] as num).toDouble(),
      district: json['district'] ?? '',
      scannedAt: DateTime.parse(json['scanned_at']),
      imagePath: json['image_path'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'produce_name_english': produceNameEnglish,
      'produce_name_kannada': produceNameKannada,
      'fair_price': fairPrice,
      'district': district,
      'scanned_at': scannedAt.toIso8601String(),
      'image_path': imagePath,
    };
  }
}
