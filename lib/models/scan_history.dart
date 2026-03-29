import 'package:hive/hive.dart';

class ScanHistory {
  final String id;
  final String produceNameEnglish;
  final String produceNameKannada;
  final double fairPrice;
  final double minPrice;
  final double maxPrice;
  final String district;
  final DateTime scannedAt;
  final String imagePath;

  ScanHistory({
    required this.id,
    required this.produceNameEnglish,
    required this.produceNameKannada,
    required this.fairPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.district,
    required this.scannedAt,
    required this.imagePath,
  });

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    return ScanHistory(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      produceNameEnglish: json['produce_name_english'] ?? '',
      produceNameKannada: json['produce_name_kannada'] ?? '',
      fairPrice: (json['fair_price'] as num).toDouble(),
      minPrice: (json['min_price'] as num? ?? 0.0).toDouble(),
      maxPrice: (json['max_price'] as num? ?? 0.0).toDouble(),
      district: json['district'] ?? '',
      scannedAt: DateTime.parse(json['scanned_at']),
      imagePath: json['image_path'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'produce_name_english': produceNameEnglish,
      'produce_name_kannada': produceNameKannada,
      'fair_price': fairPrice,
      'min_price': minPrice,
      'max_price': maxPrice,
      'district': district,
      'scanned_at': scannedAt.toIso8601String(),
      'image_path': imagePath,
    };
  }
}

class ScanHistoryAdapter extends TypeAdapter<ScanHistory> {
  @override
  final int typeId = 0;

  @override
  ScanHistory read(BinaryReader reader) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(reader.readMap());
    return ScanHistory.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, ScanHistory obj) {
    writer.writeMap(obj.toJson());
  }
}
