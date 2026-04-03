import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/transaction_record.dart';
import 'farmer_service.dart';

class TransactionHistoryService {
  static final TransactionHistoryService _instance =
      TransactionHistoryService._internal();
  factory TransactionHistoryService() => _instance;
  TransactionHistoryService._internal();

  Future<List<TransactionRecord>> getHistory() async {
    final String? farmerPhone = FarmerService().getPhoneNumber();
    if (farmerPhone == null) {
      return <TransactionRecord>[];
    }

    final String backendUrl = dotenv.env['BACKEND_API_URL'] ?? '';
    if (backendUrl.isEmpty) {
      return <TransactionRecord>[];
    }

    try {
      final Uri uri = Uri.parse(
        '$backendUrl/api/transactions/history?farmer_phone=$farmerPhone&limit=50',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> txns =
            (data['transactions'] as List<dynamic>?) ?? <dynamic>[];
        return txns
            .map(
              (dynamic t) => TransactionRecord.fromJson(
                Map<String, dynamic>.from(t as Map),
              ),
            )
            .toList();
      }

      return <TransactionRecord>[];
    } catch (error) {
      debugPrint('Error fetching transaction history: $error');
      return <TransactionRecord>[];
    }
  }
}
