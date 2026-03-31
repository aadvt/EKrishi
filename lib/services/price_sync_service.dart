import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/cached_price.dart';
import '../models/location_result.dart';

class PriceSyncService {
  static final List<String> crops = [
    'tomato', 'onion', 'potato', 'brinjal', 'okra', 'cabbage', 
    'cauliflower', 'carrot', 'beans', 'green chilli', 'garlic', 'ginger', 
    'banana', 'mango', 'papaya', 'coconut', 'maize', 'groundnut', 
    'ragi', 'jowar', 'sapota'
  ];

  Future<void> syncPrices(LocationResult location) async {
    try {
      final metaBox = Hive.box('price_sync_meta');
      final lastSyncStr = metaBox.get('last_sync');
      
      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        if (DateTime.now().difference(lastSync).inHours < 6) {
          // Already synced in the last 6 hours
          return;
        }
      }

      final String? apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return;

      final now = DateTime.now();
      final currentMonth = DateFormat('MMMM').format(now);
      final currentYear = now.year.toString();
      final district = location.district;
      final state = location.state;

      final String prompt = '''
You are an agricultural pricing expert for Indian markets.

Provide current wholesale mandi prices for the following crops 
in $district, $state, India for $currentMonth $currentYear.

Base prices on:
- Typical APMC mandi rates for this region and season
- Current supply and demand patterns for $currentMonth
- These are wholesale prices farmers receive, NOT retail prices

Crops: ${crops.join(', ')}

Respond ONLY with this exact JSON. No markdown. No explanation.
All prices in Indian Rupees per kg.

{
  "district": "$district",
  "state": "$state",
  "month": "$currentMonth",
  "prices": {
    "tomato":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಟೊಮೆಟೊ"},
    "onion":       {"min": 0, "max": 0, "fair": 0, "kannada": "ಈರುಳ್ಳಿ"},
    "potato":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಆಲೂಗಡ್ಡೆ"},
    "brinjal":     {"min": 0, "max": 0, "fair": 0, "kannada": "ಬದನೆಕಾಯಿ"},
    "okra":        {"min": 0, "max": 0, "fair": 0, "kannada": "ಬೆಂಡೆಕಾಯಿ"},
    "cabbage":     {"min": 0, "max": 0, "fair": 0, "kannada": "ಎಲೆಕೋಸು"},
    "cauliflower": {"min": 0, "max": 0, "fair": 0, "kannada": "ಹೂಕೋಸು"},
    "carrot":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಗಾಜರ"},
    "beans":       {"min": 0, "max": 0, "fair": 0, "kannada": "ಬೀನ್ಸ್"},
    "green chilli":{"min": 0, "max": 0, "fair": 0, "kannada": "ಹಸಿರು ಮೆಣಸಿನಕಾಯಿ"},
    "garlic":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಬೆಳ್ಳುಳ್ಳಿ"},
    "ginger":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಶುಂಠಿ"},
    "banana":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಬಾಳೆಹಣ್ಣು"},
    "sapota":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಸಪೋಟ"},
    "mango":       {"min": 0, "max": 0, "fair": 0, "kannada": "ಮಾವಿನಹಣ್ಣು"},
    "papaya":      {"min": 0, "max": 0, "fair": 0, "kannada": "ಪಪ್ಪಾಯಿ"},
    "coconut":     {"min": 0, "max": 0, "fair": 0, "kannada": "ತೆಂಗಿನಕಾಯಿ"},
    "maize":       {"min": 0, "max": 0, "fair": 0, "kannada": "ಮೆಕ್ಕೆಜೋಳ"},
    "groundnut":   {"min": 0, "max": 0, "fair": 0, "kannada": "ಶೇಂಗಾ"},
    "ragi":        {"min": 0, "max": 0, "fair": 0, "kannada": "ರಾಗಿ"},
    "jowar":       {"min": 0, "max": 0, "fair": 0, "kannada": "ಜೋಳ"}
  }
}
''';

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) return;

      final Map<String, dynamic> data = jsonDecode(response.body);
      String text = data['candidates'][0]['content']['parts'][0]['text'];

      // Strip markdown backticks if present
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> resultJson = jsonDecode(text);

      if (!resultJson.containsKey('prices')) return;

      final Map<String, dynamic> pricesMap = resultJson['prices'];
      final priceBox = Hive.box('cached_prices');

      pricesMap.forEach((cropName, priceData) {
        final cachedPrice = CachedPrice(
          cropNameEnglish: cropName,
          cropNameKannada: priceData['kannada'] ?? '',
          district: district,
          state: state,
          priceMin: (priceData['min'] as num).toDouble(),
          priceMax: (priceData['max'] as num).toDouble(),
          priceFair: (priceData['fair'] as num).toDouble(),
          syncedAt: DateTime.now(),
        );

        final key = '${cropName}_$district'.toLowerCase();
        priceBox.put(key, cachedPrice.toJson());
      });

      // Save sync metadata
      metaBox.put('last_sync', DateTime.now().toIso8601String());
      metaBox.put('last_sync_district', district);

    } catch (e) {
      // Catch silently - log to console but DO NOT throw
      debugPrint('Price sync failed: $e');
    }
  }

  CachedPrice? getCachedPrice(String cropName, String district) {
    try {
      final key = '${cropName}_$district'.toLowerCase();
      final priceBox = Hive.box('cached_prices');
      final data = priceBox.get(key);
      
      if (data != null) {
        return CachedPrice.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  bool hasFreshCache(String district) {
    try {
      final metaBox = Hive.box('price_sync_meta');
      final lastSyncStr = metaBox.get('last_sync');
      final lastDistrict = metaBox.get('last_sync_district');

      if (lastSyncStr != null && lastDistrict == district) {
        final lastSync = DateTime.parse(lastSyncStr);
        if (DateTime.now().difference(lastSync).inDays < 7) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  DateTime? lastSyncTime() {
    try {
      final metaBox = Hive.box('price_sync_meta');
      final lastSyncStr = metaBox.get('last_sync');
      if (lastSyncStr != null) {
        return DateTime.parse(lastSyncStr);
      }
    } catch (_) {}
    return null;
  }
}
