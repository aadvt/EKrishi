import 'dart:io';

import 'package:flutter/material.dart';

import '../models/cached_price.dart';
import '../models/produce_result.dart';
import '../models/tflite_result.dart';
import '../services/location_service.dart';
import '../services/price_sync_service.dart';
import '../services/tflite_service.dart';
import 'result_screen.dart';

class OfflineScanScreen extends StatefulWidget {
  final File imageFile;

  const OfflineScanScreen({super.key, required this.imageFile});

  @override
  State<OfflineScanScreen> createState() => _OfflineScanScreenState();
}

class _OfflineScanScreenState extends State<OfflineScanScreen> {
  bool _isIdentifying = true;
  TfliteResult? _tfliteResult;
  Map<String, String>? _selectedCrop;
  bool _isLoadingPrice = false;
  DateTime? _lastSyncTime;

  final List<Map<String, String>> _crops = [
    {'label': 'apple', 'display': 'Apple', 'kn': 'ಸೇಬು'},
    {'label': 'banana', 'display': 'Banana', 'kn': 'ಬಾಳೆಹಣ್ಣು'},
    {'label': 'beetroot', 'display': 'Beetroot', 'kn': 'ಬೀಟ್‌ರೂಟ್'},
    {
      'label': 'bell_pepper',
      'display': 'Bell Pepper',
      'kn': 'ದೊಡ್ಡ ಮೆಣಸಿನಕಾಯಿ',
    },
    {'label': 'cabbage', 'display': 'Cabbage', 'kn': 'ಎಲೆಕೋಸು'},
    {'label': 'capsicum', 'display': 'Capsicum', 'kn': 'ಕ್ಯಾಪ್ಸಿಕಂ'},
    {'label': 'carrot', 'display': 'Carrot', 'kn': 'ಗಾಜರ'},
    {'label': 'cauliflower', 'display': 'Cauliflower', 'kn': 'ಹೂಕೋಸು'},
    {
      'label': 'chilli_pepper',
      'display': 'Green Chilli',
      'kn': 'ಹಸಿರು ಮೆಣಸಿನಕಾಯಿ',
    },
    {'label': 'corn', 'display': 'Maize', 'kn': 'ಮೆಕ್ಕೆಜೋಳ'},
    {'label': 'cucumber', 'display': 'Cucumber', 'kn': 'ಸೌತೆಕಾಯಿ'},
    {'label': 'eggplant', 'display': 'Brinjal', 'kn': 'ಬದನೆಕಾಯಿ'},
    {'label': 'garlic', 'display': 'Garlic', 'kn': 'ಬೆಳ್ಳುಳ್ಳಿ'},
    {'label': 'ginger', 'display': 'Ginger', 'kn': 'ಶುಂಠಿ'},
    {'label': 'grapes', 'display': 'Grapes', 'kn': 'ದ್ರಾಕ್ಷಿ'},
    {'label': 'jalepeno', 'display': 'Jalapeno', 'kn': 'ಮೆಣಸಿನಕಾಯಿ'},
    {'label': 'kiwi', 'display': 'Kiwi', 'kn': 'ಕಿವಿ'},
    {'label': 'lemon', 'display': 'Lemon', 'kn': 'ನಿಂಬೆ'},
    {'label': 'lettuce', 'display': 'Lettuce', 'kn': 'ಲೆಟ್ಯೂಸ್'},
    {'label': 'mango', 'display': 'Mango', 'kn': 'ಮಾವಿನಹಣ್ಣು'},
    {'label': 'onion', 'display': 'Onion', 'kn': 'ಈರುಳ್ಳಿ'},
    {'label': 'orange', 'display': 'Orange', 'kn': 'ಕಿತ್ತಳೆ'},
    {'label': 'paprika', 'display': 'Paprika', 'kn': 'ಪಪ್ರಿಕಾ'},
    {'label': 'pear', 'display': 'Pear', 'kn': 'ಪಿಯರ್'},
    {'label': 'peas', 'display': 'Peas', 'kn': 'ಅವರೆಕಾಳು'},
    {'label': 'pineapple', 'display': 'Pineapple', 'kn': 'ಅನಾನಸ್'},
    {'label': 'pomegranate', 'display': 'Pomegranate', 'kn': 'ದಾಳಿಂಬೆ'},
    {'label': 'potato', 'display': 'Potato', 'kn': 'ಆಲೂಗಡ್ಡೆ'},
    {'label': 'raddish', 'display': 'Radish', 'kn': 'ಮೂಲಂಗಿ'},
    {'label': 'soy_beans', 'display': 'Soy Beans', 'kn': 'ಸೋಯಾ ಬೀನ್ಸ್'},
    {'label': 'spinach', 'display': 'Spinach', 'kn': 'ಪಾಲಕ್'},
    {'label': 'sweetcorn', 'display': 'Sweet Corn', 'kn': 'ಸಿಹಿ ಜೋಳ'},
    {'label': 'sweetpotato', 'display': 'Sweet Potato', 'kn': 'ಸಿಹಿ ಗೆಣಸು'},
    {'label': 'tomato', 'display': 'Tomato', 'kn': 'ಟೊಮೆಟೊ'},
    {'label': 'turnip', 'display': 'Turnip', 'kn': 'ಶಲಗಂ'},
    {'label': 'watermelon', 'display': 'Watermelon', 'kn': 'ಕಲ್ಲಂಗಡಿ'},
  ];

  @override
  void initState() {
    super.initState();
    _runTfliteIdentification();
    _loadSyncTime();
  }

  Future<void> _loadSyncTime() async {
    final lastSync = PriceSyncService().lastSyncTime();
    if (!mounted) {
      return;
    }
    setState(() => _lastSyncTime = lastSync);
  }

  Future<void> _runTfliteIdentification() async {
    setState(() => _isIdentifying = true);

    final result = await TfliteService().classifyImage(widget.imageFile);
    if (!mounted) {
      return;
    }

    if (result != null && result.isHighConfidence) {
      final matchingCrop = _crops.cast<Map<String, String>?>().firstWhere(
        (crop) => crop?['label'] == result.label,
        orElse: () => null,
      );

      if (matchingCrop != null) {
        setState(() {
          _tfliteResult = result;
          _selectedCrop = matchingCrop;
          _isIdentifying = false;
        });
        return;
      }
    }

    setState(() => _isIdentifying = false);
  }

  Future<void> _getCachedPrice() async {
    if (_selectedCrop == null) {
      return;
    }
    setState(() => _isLoadingPrice = true);

    try {
      final location = await LocationService().getCurrentLocation();
      final CachedPrice? cachedPrice = PriceSyncService().getCachedPrice(
        _selectedCrop!['label']!,
        location.district,
      );

      if (cachedPrice != null) {
        final produceResult = ProduceResult(
          nameEnglish: _selectedCrop!['display']!,
          nameKannada: _selectedCrop!['kn']!,
          confidence: _tfliteResult?.confidence ?? 1.0,
          category: 'vegetable',
          ripeness: 'unknown',
          grade: 'B',
          gradeReasoning: _tfliteResult != null
              ? 'Identified on-device with '
                    '${(_tfliteResult!.confidence * 100).toStringAsFixed(0)}% '
                    'confidence. Grade not available offline.'
              : 'Manually selected crop. Grade not available offline.',
          priceMinPerKg: cachedPrice.priceMin,
          priceMaxPerKg: cachedPrice.priceMax,
          priceFairPerKg: cachedPrice.priceFair,
          priceRecommendedMin: cachedPrice.priceFair * 0.9,
          priceRecommendedMax: cachedPrice.priceFair * 1.1,
          priceReasoning:
              'Cached price · Last synced: '
              '${_formatDate(cachedPrice.syncedAt)}',
          priceConfidence: cachedPrice.isStale ? 'low' : 'medium',
          isPriceEstimate: true,
          lowConfidence: (_tfliteResult?.confidence ?? 1.0) < 0.65,
        );

        if (!mounted) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imageFile: widget.imageFile,
              produceResult: produceResult,
              locationResult: location,
            ),
          ),
        );
      } else {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No cached price for ${_selectedCrop!['display']} '
              'in ${location.district}. '
              'Connect to internet to sync prices.',
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrice = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Offline Mode / ಆಫ್‌ಲೈನ್ ಮೋಡ್',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFF4A261),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Using on-device AI + cached prices',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                widget.imageFile,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            if (_isIdentifying)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF52B788),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Identifying crop... / ಬೆಳೆ ಗುರುತಿಸಲಾಗುತ್ತಿದೆ...',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ],
              )
            else if (_tfliteResult != null && _tfliteResult!.isHighConfidence)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8F3DC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF52B788)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF2D6A4F),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identified: ${_selectedCrop!['display']}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D6A4F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_tfliteResult!.confidence * 100).toStringAsFixed(0)}% confidence · Change below if incorrect',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF52B788),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFFAAAAAA),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not identify automatically. Select your crop below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'YOUR CROP / ನಿಮ್ಮ ಬೆಳೆ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Color(0xFFAAAAAA),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Map<String, String>>(
              initialValue: _selectedCrop,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              hint: const Text('Select a crop / ಬೆಳೆ ಆಯ್ಕೆ ಮಾಡಿ'),
              items: _crops
                  .map(
                    (crop) => DropdownMenuItem<Map<String, String>>(
                      value: crop,
                      child: Text(
                        '${crop['display']} · ${crop['kn']}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCrop = value),
            ),
            const SizedBox(height: 12),
            if (_lastSyncTime != null)
              Row(
                children: [
                  const Icon(
                    Icons.update_rounded,
                    color: Color(0xFFAAAAAA),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Prices synced: ${_formatDate(_lastSyncTime!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                ],
              )
            else
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE63946),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'No cached prices. Connect to internet first.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE63946)),
                  ),
                ],
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedCrop != null ? _getCachedPrice : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedCrop != null
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFE8E8E8),
                  foregroundColor: _selectedCrop != null
                      ? Colors.white
                      : const Color(0xFFAAAAAA),
                  disabledForegroundColor: const Color(0xFFAAAAAA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoadingPrice
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Get Price / ಬೆಲೆ ತೋರಿಸಿ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
