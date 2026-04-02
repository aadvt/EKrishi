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
    'apple',
    'banana',
    'beetroot',
    'bell_pepper',
    'cabbage',
    'capsicum',
    'carrot',
    'cauliflower',
    'chilli_pepper',
    'corn',
    'cucumber',
    'eggplant',
    'garlic',
    'ginger',
    'grapes',
    'jalepeno',
    'kiwi',
    'lemon',
    'lettuce',
    'mango',
    'onion',
    'orange',
    'paprika',
    'pear',
    'peas',
    'pineapple',
    'pomegranate',
    'potato',
    'raddish',
    'soy_beans',
    'spinach',
    'sweetcorn',
    'sweetpotato',
    'tomato',
    'turnip',
    'watermelon',
  ];

  Future<void> syncPrices(LocationResult location) async {
    try {
      final metaBox = Hive.box('price_sync_meta');
      final lastSyncStr = metaBox.get('last_sync');

      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        if (DateTime.now().difference(lastSync).inHours < 24) {
          // Already synced in the last 24 hours
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

      final String prompt =
          '''
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
    "apple":        {"min": 0, "max": 0, "fair": 0, "kannada": "Apple"},
    "banana":       {"min": 0, "max": 0, "fair": 0, "kannada": "Banana"},
    "beetroot":     {"min": 0, "max": 0, "fair": 0, "kannada": "Beetroot"},
    "bell_pepper":  {"min": 0, "max": 0, "fair": 0, "kannada": "Bell Pepper"},
    "cabbage":      {"min": 0, "max": 0, "fair": 0, "kannada": "Cabbage"},
    "capsicum":     {"min": 0, "max": 0, "fair": 0, "kannada": "Capsicum"},
    "carrot":       {"min": 0, "max": 0, "fair": 0, "kannada": "Carrot"},
    "cauliflower":  {"min": 0, "max": 0, "fair": 0, "kannada": "Cauliflower"},
    "chilli_pepper": {"min": 0, "max": 0, "fair": 0, "kannada": "Chilli Pepper"},
    "corn":         {"min": 0, "max": 0, "fair": 0, "kannada": "Corn"},
    "cucumber":     {"min": 0, "max": 0, "fair": 0, "kannada": "Cucumber"},
    "eggplant":     {"min": 0, "max": 0, "fair": 0, "kannada": "Eggplant"},
    "garlic":       {"min": 0, "max": 0, "fair": 0, "kannada": "Garlic"},
    "ginger":       {"min": 0, "max": 0, "fair": 0, "kannada": "Ginger"},
    "grapes":       {"min": 0, "max": 0, "fair": 0, "kannada": "Grapes"},
    "jalepeno":     {"min": 0, "max": 0, "fair": 0, "kannada": "Jalepeno"},
    "kiwi":         {"min": 0, "max": 0, "fair": 0, "kannada": "Kiwi"},
    "lemon":        {"min": 0, "max": 0, "fair": 0, "kannada": "Lemon"},
    "lettuce":      {"min": 0, "max": 0, "fair": 0, "kannada": "Lettuce"},
    "mango":        {"min": 0, "max": 0, "fair": 0, "kannada": "Mango"},
    "onion":        {"min": 0, "max": 0, "fair": 0, "kannada": "Onion"},
    "orange":       {"min": 0, "max": 0, "fair": 0, "kannada": "Orange"},
    "paprika":      {"min": 0, "max": 0, "fair": 0, "kannada": "Paprika"},
    "pear":         {"min": 0, "max": 0, "fair": 0, "kannada": "Pear"},
    "peas":         {"min": 0, "max": 0, "fair": 0, "kannada": "Peas"},
    "pineapple":    {"min": 0, "max": 0, "fair": 0, "kannada": "Pineapple"},
    "pomegranate":  {"min": 0, "max": 0, "fair": 0, "kannada": "Pomegranate"},
    "potato":       {"min": 0, "max": 0, "fair": 0, "kannada": "Potato"},
    "raddish":      {"min": 0, "max": 0, "fair": 0, "kannada": "Raddish"},
    "soy_beans":    {"min": 0, "max": 0, "fair": 0, "kannada": "Soy Beans"},
    "spinach":      {"min": 0, "max": 0, "fair": 0, "kannada": "Spinach"},
    "sweetcorn":    {"min": 0, "max": 0, "fair": 0, "kannada": "Sweetcorn"},
    "sweetpotato":  {"min": 0, "max": 0, "fair": 0, "kannada": "Sweetpotato"},
    "tomato":       {"min": 0, "max": 0, "fair": 0, "kannada": "Tomato"},
    "turnip":       {"min": 0, "max": 0, "fair": 0, "kannada": "Turnip"},
    "watermelon":   {"min": 0, "max": 0, "fair": 0, "kannada": "Watermelon"}
  }
}
''';

      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));

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
