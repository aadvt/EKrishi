class TransactionRecord {
  final String transactionId;
  final String commodityName;
  final double quantityKg;
  final double pricePerKg;
  final double totalAmount;
  final String saleChannel;
  final String paymentStatus;
  final String buyerName;
  final String district;
  final String? upiTxid;
  final DateTime createdAt;
  final bool gnnFlagged;
  final double? priceRatio;

  TransactionRecord({
    required this.transactionId,
    required this.commodityName,
    required this.quantityKg,
    required this.pricePerKg,
    required this.totalAmount,
    required this.saleChannel,
    required this.paymentStatus,
    required this.buyerName,
    required this.district,
    required this.upiTxid,
    required this.createdAt,
    required this.gnnFlagged,
    required this.priceRatio,
  });

  bool get isSmsSale => saleChannel == 'sms_detected';
  bool get isMarketplace => saleChannel == 'marketplace';

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      transactionId: (json['transaction_id'] ?? '').toString(),
      commodityName: (json['commodity_name'] ?? 'Unknown').toString(),
      quantityKg: _asDouble(json['quantity_kg']),
      pricePerKg: _asDouble(json['price_per_kg']),
      totalAmount: _asDouble(json['total_amount']),
      saleChannel: (json['sale_channel'] ?? 'unknown').toString(),
      paymentStatus: (json['payment_status'] ?? 'unknown').toString(),
      buyerName: (json['buyer_name_offline'] ?? 'Unknown buyer').toString(),
      district: (json['district'] ?? '').toString(),
      upiTxid: json['upi_txid']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      gnnFlagged: json['gnn_flagged'] == true,
      priceRatio: _asNullableDouble(json['price_ratio']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
