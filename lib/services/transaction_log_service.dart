import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'farmer_service.dart';
import 'location_service.dart';

class TransactionLogService {
  static final TransactionLogService _instance =
      TransactionLogService._internal();
  factory TransactionLogService() => _instance;
  TransactionLogService._internal();

  Future<bool> logSmsTransaction(Map<String, dynamic> pendingData) async {
    final String? farmerPhoneRaw = FarmerService().getPhoneNumber();
    final String? farmerPhone = _normalizePhone(farmerPhoneRaw);
    if (farmerPhone == null) {
      debugPrint(
        'SMS log skipped: farmer phone missing/invalid ($farmerPhoneRaw)',
      );
      return false;
    }

    final location = await LocationService().getCurrentLocation();
    final String backendUrl = dotenv.env['BACKEND_API_URL'] ?? '';
    if (backendUrl.isEmpty) {
      debugPrint('SMS log skipped: BACKEND_API_URL missing');
      return false;
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'farmer_phone': farmerPhone,
      'buyer_name': pendingData['buyer_name'] ?? 'Unknown',
      'commodity_name': pendingData['crop_name'] ?? 'Unknown',
      'commodity_name_kannada': pendingData['crop_name_kannada'] ?? '',
      'amount': pendingData['amount'] ?? 0.0,
      'price_per_kg': null,
      'upi_txid': pendingData['upi_reference'] ?? '',
      'district': location.district,
      'state': location.state,
      'sms_raw': pendingData['raw_sms'] ?? '',
    };

    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/api/transactions/sms-log'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('SMS transaction logged successfully');
        return true;
      }

      debugPrint('Backend error: ${response.statusCode} ${response.body}');
      return false;
    } catch (error) {
      debugPrint('Network error logging transaction: $error');
      return false;
    }
  }

  String? _normalizePhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return null;
    }
    return digits.substring(digits.length - 10);
  }
}
