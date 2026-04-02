import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
import '../services/produce_service.dart';
import '../services/location_service.dart';
import '../services/price_sync_service.dart';
import '../services/tflite_service.dart';
import '../models/produce_result.dart';
import '../models/location_result.dart';
import '../utils/exceptions.dart';
import 'result_screen.dart';

class PreviewScreen extends StatefulWidget {
  final File imageFile;

  const PreviewScreen({super.key, required this.imageFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = false;
  final ProduceService _produceService = ProduceService();
  final LocationService _locationService = LocationService();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _analyseProduce() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline =
        connectivityResult.contains(ConnectivityResult.none) &&
        connectivityResult.length == 1;

    if (isOffline) {
      // Show loading overlay - TFLite takes 1-2 seconds.
      setState(() => _isAnalyzing = true);

      try {
        // Run TFLite identification on device.
        final tfliteResult = await TfliteService().classifyImage(
          widget.imageFile,
        );

        // Get location from cache.
        final location = await _locationService.getCurrentLocation();

        if (tfliteResult == null || !tfliteResult.isHighConfidence) {
          // Could not identify - show error and stay.
          setState(() => _isAnalyzing = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not identify this produce offline. Try in better lighting or connect to internet.',
              ),
              backgroundColor: const Color(0xFF1A1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        // Look up the crop details from the master list to get Kannada name.
        final cropMap = _getOfflineCropDetails(tfliteResult.label);

        // Look up cached price.
        final cachedPrice = PriceSyncService().getCachedPrice(
          tfliteResult.label,
          location.district,
        );

        if (cachedPrice == null) {
          setState(() => _isAnalyzing = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No cached price for ${cropMap['display']} in ${location.district}. Connect to internet to sync prices first.',
              ),
              backgroundColor: const Color(0xFF1A1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        // Build ProduceResult from TFLite + cache data.
        final produceResult = ProduceResult(
          nameEnglish: cropMap['display']!,
          nameKannada: cropMap['kn']!,
          confidence: tfliteResult.confidence,
          category: 'vegetable',
          ripeness: 'unknown',
          grade: 'B',
          gradeReasoning:
              'Identified on-device with '
              '${(tfliteResult.confidence * 100).toStringAsFixed(0)}% confidence. '
              'Grade not available offline.',
          priceMinPerKg: cachedPrice.priceMin,
          priceMaxPerKg: cachedPrice.priceMax,
          priceFairPerKg: cachedPrice.priceFair,
          priceRecommendedMin: cachedPrice.priceFair * 0.9,
          priceRecommendedMax: cachedPrice.priceFair * 1.1,
          priceReasoning:
              'Cached price · Last synced: ${_formatDate(cachedPrice.syncedAt)}',
          priceConfidence: cachedPrice.isStale ? 'low' : 'medium',
          isPriceEstimate: true,
          lowConfidence: tfliteResult.confidence < 0.65,
        );

        setState(() => _isAnalyzing = false);
        if (!mounted) return;

        // Go directly to ResultScreen - no intermediate screen.
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
      } catch (e) {
        setState(() => _isAnalyzing = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline identification failed. Please try again.'),
            backgroundColor: Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // 1. Get current location for regional pricing context
      final LocationResult location = await _locationService
          .getCurrentLocation();

      // 2. Identify and price produce via Gemini
      final ProduceResult produceResult = await _produceService.identifyProduce(
        widget.imageFile,
        location.district,
        location.state,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              imageFile: widget.imageFile,
              produceResult: produceResult,
              locationResult: location,
            ),
          ),
        );
      }
    } on NotProduceException {
      _showErrorSnackBar('error_not_produce');
    } on NetworkException {
      _showErrorSnackBar('error_network');
    } catch (e) {
      debugPrint('Error during analysis: $e');
      _showErrorSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showErrorSnackBar(String messageKeyOrDirectMessage) {
    if (!mounted) return;

    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String message;
    try {
      message = languageProvider.translate(messageKeyOrDirectMessage);
    } catch (e) {
      message = messageKeyOrDirectMessage;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Maps TFLite label to display name + Kannada.
  Map<String, String> _getOfflineCropDetails(String label) {
    const crops = {
      'tomato': {'display': 'Tomato', 'kn': 'ಟೊಮೆಟೊ'},
      'onion': {'display': 'Onion', 'kn': 'ಈರುಳ್ಳಿ'},
      'potato': {'display': 'Potato', 'kn': 'ಆಲೂಗಡ್ಡೆ'},
      'eggplant': {'display': 'Brinjal', 'kn': 'ಬದನೆಕಾಯಿ'},
      'cabbage': {'display': 'Cabbage', 'kn': 'ಎಲೆಕೋಸು'},
      'cauliflower': {'display': 'Cauliflower', 'kn': 'ಹೂಕೋಸು'},
      'carrot': {'display': 'Carrot', 'kn': 'ಗಾಜರ'},
      'beans': {'display': 'Beans', 'kn': 'ಬೀನ್ಸ್'},
      'capsicum': {'display': 'Green Chilli', 'kn': 'ಹಸಿರು ಮೆಣಸಿನಕಾಯಿ'},
      'chilli': {'display': 'Green Chilli', 'kn': 'ಹಸಿರು ಮೆಣಸಿನಕಾಯಿ'},
      'banana': {'display': 'Banana', 'kn': 'ಬಾಳೆಹಣ್ಣು'},
      'mango': {'display': 'Mango', 'kn': 'ಮಾವಿನಹಣ್ಣು'},
      'papaya': {'display': 'Papaya', 'kn': 'ಪಪ್ಪಾಯಿ'},
      'pineapple': {'display': 'Pineapple', 'kn': 'ಅನಾನಸ್'},
      'watermelon': {'display': 'Watermelon', 'kn': 'ಕಲ್ಲಂಗಡಿ'},
      'corn': {'display': 'Maize', 'kn': 'ಮೆಕ್ಕೆಜೋಳ'},
      'ginger': {'display': 'Ginger', 'kn': 'ಶುಂಠಿ'},
      'garlic': {'display': 'Garlic', 'kn': 'ಬೆಳ್ಳುಳ್ಳಿ'},
      'pomegranate': {'display': 'Pomegranate', 'kn': 'ದಾಳಿಂಬೆ'},
      'beetroot': {'display': 'Beetroot', 'kn': 'ಬೀಟ್‌ರೂಟ್'},
      'radish': {'display': 'Radish', 'kn': 'ಮೂಲಂಗಿ'},
      'peas': {'display': 'Peas', 'kn': 'ಅವರೆಕಾಳು'},
      'cucumber': {'display': 'Cucumber', 'kn': 'ಸೌತೆಕಾಯಿ'},
      'spinach': {'display': 'Spinach', 'kn': 'ಪಾಲಕ್'},
      'grapes': {'display': 'Grapes', 'kn': 'ದ್ರಾಕ್ಷಿ'},
      'apple': {'display': 'Apple', 'kn': 'ಸೇಬು'},
      'orange': {'display': 'Orange', 'kn': 'ಕಿತ್ತಳೆ'},
      'lemon': {'display': 'Lemon', 'kn': 'ನಿಂಬೆ'},
      'coconut': {'display': 'Coconut', 'kn': 'ತೆಂಗಿನಕಾಯಿ'},
      'kiwi': {'display': 'Kiwi', 'kn': 'ಕಿವಿ'},
      'pear': {'display': 'Pear', 'kn': 'ಪಿಯರ್'},
    };

    final found = crops[label.toLowerCase()];
    if (found != null) {
      return {'display': found['display']!, 'kn': found['kn']!};
    }

    if (label.isEmpty) {
      return {'display': 'Unknown', 'kn': 'unknown'};
    }

    // Fallback: capitalize the label itself.
    return {
      'display': label[0].toUpperCase() + label.substring(1),
      'kn': label,
    };
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
    final languageProvider = Provider.of<LanguageProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // TOP: Captured Image (60%)
              SizedBox(
                height: size.height * 0.60,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      child: Image.file(widget.imageFile, fit: BoxFit.cover),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // BOTTOM PANEL (40%)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          languageProvider.isKannada
                              ? 'ಫೋಟೋ ಪರಿಶೀಲಿಸಿ'
                              : 'Review Photo',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        languageProvider.isKannada
                            ? 'ಬೆಳೆ ಸ್ಪಷ್ಟವಾಗಿ ಕಾಣಿಸುತ್ತಿದೆಯೇ?'
                            : 'Is the produce clearly visible?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        languageProvider.isKannada
                            ? 'ಉತ್ತಮ ಫಲಿತಾಂಶಕ್ಕಾಗಿ, ಬೆಳೆ ಚಿತ್ರದಲ್ಲಿ ಹೆಚ್ಚಿನ ಭಾಗವನ್ನು ತುಂಬುವಂತೆ ನೋಡಿಕೊಳ್ಳಿ.'
                            : 'Make sure the item fills most of the frame for the best result.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isAnalyzing ? null : _analyseProduce,
                        child: Text(languageProvider.translate('analyse')),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isAnalyzing
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          foregroundColor: AppColors.textSecondary,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: Text(languageProvider.translate('retake')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Close button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.22),
                  child: InkWell(
                    onTap: _isAnalyzing ? null : () => Navigator.pop(context),
                    splashColor: Colors.white.withValues(alpha: 0.10),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // LOADING OVERLAY (frosted glass)
          if (_isAnalyzing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.85),
                  alignment: Alignment.center,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(
                        _pulseController.value,
                      );
                      final outerScale = 0.95 + (0.08 * t);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: outerScale,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: AppColors.softGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            languageProvider.translate('identifying'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            languageProvider.isKannada
                                ? 'ಪ್ರಸ್ತುತ ಮಾರುಕಟ್ಟೆ ಬೆಲೆಗಳನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...'
                                : 'Checking current market prices...',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
