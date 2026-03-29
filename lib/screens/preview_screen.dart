import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
import '../services/produce_service.dart';
import '../services/location_service.dart';
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

class _PreviewScreenState extends State<PreviewScreen> with SingleTickerProviderStateMixin {
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
    setState(() => _isAnalyzing = true);

    try {
      // 1. Get current location for regional pricing context
      final LocationResult location = await _locationService.getCurrentLocation();

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
    
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          languageProvider.isKannada ? 'ಫೋಟೋ ಪರಿಶೀಲಿಸಿ' : 'Review Photo',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        languageProvider.isKannada ? 'ಬೆಳೆ ಸ್ಪಷ್ಟವಾಗಿ ಕಾಣಿಸುತ್ತಿದೆಯೇ?' : 'Is the produce clearly visible?',
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
                        onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          foregroundColor: AppColors.textSecondary,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
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
                      final t = Curves.easeInOut.transform(_pulseController.value);
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
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
