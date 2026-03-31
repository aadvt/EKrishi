import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/produce_result.dart';
import '../models/cached_price.dart';
import '../services/price_sync_service.dart';
import '../services/location_service.dart';
import '../constants/app_colors.dart';
import 'result_screen.dart';

class OfflineScanScreen extends StatefulWidget {
  final File imageFile;

  const OfflineScanScreen({super.key, required this.imageFile});

  @override
  State<OfflineScanScreen> createState() => _OfflineScanScreenState();
}

class _OfflineScanScreenState extends State<OfflineScanScreen> {
  Map<String, String>? _selectedCrop;
  
  final List<Map<String, String>> _crops = [
    {'en': 'tomato', 'kn': 'ಟೊಮೆಟೊ', 'display': 'Tomato'},
    {'en': 'onion', 'kn': 'ಈರುಳ್ಳಿ', 'display': 'Onion'},
    {'en': 'potato', 'kn': 'ಆಲೂಗಡ್ಡೆ', 'display': 'Potato'},
    {'en': 'brinjal', 'kn': 'ಬದನೆಕಾಯಿ', 'display': 'Brinjal'},
    {'en': 'okra', 'kn': 'ಬೆಂಡೆಕಾಯಿ', 'display': 'Okra'},
    {'en': 'cabbage', 'kn': 'ಎಲೆಕೋಸು', 'display': 'Cabbage'},
    {'en': 'cauliflower', 'kn': 'ಹೂಕೋಸು', 'display': 'Cauliflower'},
    {'en': 'carrot', 'kn': 'ಗಾಜರ', 'display': 'Carrot'},
    {'en': 'beans', 'kn': 'ಬೀನ್ಸ್', 'display': 'Beans'},
    {'en': 'green chilli', 'kn': 'ಹಸಿರು ಮೆಣಸಿನಕಾಯಿ', 'display': 'Green Chilli'},
    {'en': 'garlic', 'kn': 'ಬೆಳ್ಳುಳ್ಳಿ', 'display': 'ಬೆಳ್ಳುಳ್ಳಿ'},
    {'en': 'ginger', 'kn': 'ಶುಂಠಿ', 'display': 'Ginger'},
    {'en': 'banana', 'kn': 'ಬಾಳೆಹಣ್ಣು', 'display': 'Banana'},
    {'en': 'sapota', 'kn': 'ಸಪೋಟ', 'display': 'Sapota'},
    {'en': 'mango', 'kn': 'ಮಾವಿನಹಣ್ಣು', 'display': 'Mango'},
    {'en': 'papaya', 'kn': 'ಪಪ್ಪಾಯಿ', 'display': 'Papaya'},
    {'en': 'coconut', 'kn': 'ತೆಂಗಿನಕಾಯಿ', 'display': 'Coconut'},
    {'en': 'maize', 'kn': 'ಮೆಕ್ಕೆಜೋಳ', 'display': 'Maize'},
    {'en': 'groundnut', 'kn': 'ಶೇಂಗಾ', 'display': 'Groundnut'},
    {'en': 'ragi', 'kn': 'ರಾಗಿ', 'display': 'Ragi'},
    {'en': 'jowar', 'kn': 'ಜೋಳ', 'display': 'Jowar'},
  ];

  Future<void> _handleGetPrice() async {
    if (_selectedCrop == null) return;

    final location = await LocationService().getCurrentLocation();
    final CachedPrice? cachedData = PriceSyncService().getCachedPrice(
      _selectedCrop!['en']!, 
      location.district
    );

    if (cachedData != null) {
      final formattedDate = DateFormat('dd MMM yyyy').format(cachedData.syncedAt);
      
      final produceResult = ProduceResult(
        nameEnglish: _selectedCrop!['display']!,
        nameKannada: _selectedCrop!['kn']!,
        confidence: 1.0,
        category: 'vegetable', // DEFAULT
        ripeness: 'unknown',
        grade: 'B',
        gradeReasoning: 'Grade not available in offline mode',
        lowConfidence: false,
        priceMinPerKg: cachedData.priceMin,
        priceMaxPerKg: cachedData.priceMax,
        priceFairPerKg: cachedData.priceFair,
        priceRecommendedMin: cachedData.priceFair * 0.9,
        priceRecommendedMax: cachedData.priceFair * 1.1,
        priceReasoning: 'Cached price from last sync: $formattedDate',
        priceConfidence: cachedData.isStale ? 'low' : 'medium',
        isPriceEstimate: true,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              produceResult: produceResult,
              locationResult: location,
              imageFile: widget.imageFile,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No cached price for this crop. Connect to internet and reopen the app to sync prices.'
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSyncTime = PriceSyncService().lastSyncTime();
    final formattedSyncTime = lastSyncTime != null 
        ? DateFormat('dd MMM yyyy').format(lastSyncTime)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Offline Mode / ಆಫ್ಲೈನ್ ಮೋಡ್', 
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OFFLINE NOTICE CARD
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Color(0xFFF4A261), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No internet connection / ಇಂಟರ್ನೆಟ್ ಸಂಪರ್ಕ ಇಲ್ಲ',
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600, 
                            color: Color(0xFFF4A261),
                          ),
                        ),
                        Text(
                          'Using cached prices. Connect to internet for live AI analysis. / ಸಂಗ್ರಹಿಸಿದ ಬೆಲೆಗಳನ್ನು ಬಳಸಲಾಗುತ್ತಿದೆ.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // IMAGE PREVIEW
            Container(
              margin: const EdgeInsets.only(top: 16),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: FileImage(widget.imageFile),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // CROP SELECTOR
            const SizedBox(height: 24),
            const Text(
              'Select your crop / ನಿಮ್ಮ ಬೆಳೆ ಆಯ್ಕೆ ಮಾಡಿ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Map<String, String>>(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
              ),
              hint: const Text('Choose a crop'),
              initialValue: _selectedCrop,
              items: _crops.map((crop) {
                return DropdownMenuItem<Map<String, String>>(
                  value: crop,
                  child: Text('${crop['display']} (${crop['kn']})'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedCrop = val);
              },
            ),

            // GET PRICE BUTTON
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedCrop == null ? null : _handleGetPrice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Get Cached Price / ಸಂಗ್ರಹಿಸಿದ ಬೆಲೆ ತೋರಿಸಿ'),
              ),
            ),

            // CACHE STATUS
            const SizedBox(height: 12),
            Center(
              child: formattedSyncTime != null
                  ? Text(
                      'Prices last synced: $formattedSyncTime / ಕೊನೆಯ ಸಿಂಕ್: $formattedSyncTime',
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    )
                  : const Text(
                      'No price data cached yet. Connect to internet first.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE63946)),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
