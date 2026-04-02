import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/location_result.dart';
import '../models/marketplace_listing.dart';
import '../models/marketplace_result.dart';
import '../models/produce_result.dart';

class MarketplaceService {
  static final MarketplaceService _instance = MarketplaceService._internal();

  factory MarketplaceService() => _instance;

  MarketplaceService._internal();

  Future<MarketplaceResult> pushListing(
    ProduceResult produceResult,
    LocationResult locationResult,
    String farmerPhone,
  ) async {
    final bool isCachedSource =
        produceResult.priceReasoning.contains('Cached');

    final MarketplaceListing listing = MarketplaceListing(
      id: const Uuid().v4(),
      farmerPhone: farmerPhone,
      cropNameEnglish: produceResult.nameEnglish,
      cropNameKannada: produceResult.nameKannada,
      priceFairPerKg: produceResult.priceFairPerKg,
      priceMinPerKg: produceResult.priceMinPerKg,
      priceMaxPerKg: produceResult.priceMaxPerKg,
      grade: produceResult.grade,
      ripeness: produceResult.ripeness,
      district: locationResult.district,
      state: locationResult.state,
      priceSource: isCachedSource ? 'cached' : 'gemini',
      listedAt: DateTime.now(),
      isOfflineListing: isCachedSource,
    );

    final String? neonApiUrl = dotenv.env['NEON_API_URL'];
    final String neonApiKey = dotenv.env['NEON_API_KEY'] ?? '';

    if (neonApiUrl == null || neonApiUrl.isEmpty) {
      return const MarketplaceResult(
        success: false,
        error: 'NEON_API_URL is not configured',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$neonApiUrl/listings'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $neonApiKey',
            },
            body: jsonEncode(listing.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return MarketplaceResult(success: true, listingId: listing.id);
      }

      return MarketplaceResult(
        success: false,
        error: 'Server error: ${response.statusCode}',
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
}
