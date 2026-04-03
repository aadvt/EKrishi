import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/location_result.dart';
import '../models/marketplace_result.dart';
import '../models/produce_result.dart';
import 'farmer_service.dart';

class MarketplaceService {
  static final MarketplaceService _instance = MarketplaceService._internal();

  factory MarketplaceService() => _instance;

  MarketplaceService._internal();

  Future<MarketplaceResult> pushListing(
    ProduceResult produceResult,
    LocationResult locationResult,
    String farmerPhone,
    double quantityKg,
  ) async {
    final String? neonApiUrl = dotenv.env['NEON_API_URL'];

    if (neonApiUrl == null || neonApiUrl.isEmpty) {
      return const MarketplaceResult(
        success: false,
        error: 'NEON_API_URL is not configured',
      );
    }

    try {
      final farmerFullName = FarmerService().getFullName()?.trim();
      if (farmerFullName == null || farmerFullName.isEmpty) {
        return const MarketplaceResult(
          success: false,
          error: 'Please set your name before listing',
        );
      }

      final upsertFarmerResponse = await http
          .post(
            Uri.parse('$neonApiUrl/farmers/upsert'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone_number': farmerPhone,
              'full_name': farmerFullName,
              'district': locationResult.district,
              'taluk': locationResult.city,
              'latitude': locationResult.latitude,
              'longitude': locationResult.longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (upsertFarmerResponse.statusCode != 200 &&
          upsertFarmerResponse.statusCode != 201) {
        return MarketplaceResult(
          success: false,
          error:
              _extractBackendError(upsertFarmerResponse.body) ??
              'Server error: ${upsertFarmerResponse.statusCode}',
        );
      }

      final listingResponse = await http
          .post(
            Uri.parse('$neonApiUrl/listings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'farmer_phone': farmerPhone,
              'produce_name': produceResult.nameEnglish,
              'produce_name_local': produceResult.nameKannada,
              'quantity_kg': quantityKg,
              'price_per_kg': produceResult.priceFairPerKg,
              'price_min_per_kg': produceResult.priceMinPerKg,
              'price_max_per_kg': produceResult.priceMaxPerKg,
              'grade': produceResult.grade,
              'location_district': locationResult.district,
              'location_taluk': locationResult.city,
              'latitude': locationResult.latitude,
              'longitude': locationResult.longitude,
              'source_channel': 'mobile_app',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (listingResponse.statusCode == 200 ||
          listingResponse.statusCode == 201) {
        final body = jsonDecode(listingResponse.body) as Map<String, dynamic>;
        final listingId = body['listing_id']?.toString();
        if (listingId == null || listingId.isEmpty) {
          return const MarketplaceResult(
            success: false,
            error: 'Invalid listing response from server',
          );
        }

        return MarketplaceResult(success: true, listingId: listingId);
      }

      return MarketplaceResult(
        success: false,
        error:
            _extractBackendError(listingResponse.body) ??
            'Server error: ${listingResponse.statusCode}',
      );
    } on TimeoutException {
      return const MarketplaceResult(
        success: false,
        error: 'No internet connection',
      );
    } on SocketException {
      return const MarketplaceResult(
        success: false,
        error: 'No internet connection',
      );
    } on http.ClientException {
      return const MarketplaceResult(
        success: false,
        error: 'No internet connection',
      );
    } catch (_) {
      return const MarketplaceResult(
        success: false,
        error: 'No internet connection',
      );
    }
  }

  String? _extractBackendError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
