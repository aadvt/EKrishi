import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
import '../services/produce_service.dart';
import '../services/location_service.dart';
import '../models/produce_result.dart';
import '../models/location_result.dart';
import '../utils/exceptions.dart';
import '../widgets/loading_widget.dart';
import 'result_screen.dart';

class PreviewScreen extends StatefulWidget {
  final File imageFile;

  const PreviewScreen({super.key, required this.imageFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isAnalyzing = false;
  final ProduceService _produceService = ProduceService();
  final LocationService _locationService = LocationService();

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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              // TOP HALF: Captured Image
              SizedBox(
                height: size.height * 0.55,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              // BOTTOM HALF: Action Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.backgroundWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.translate('analyse_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        languageProvider.translate('analyse_subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const Spacer(),
                      
                      // Action Buttons
                      Column(
                        children: [
                          OutlinedButton(
                            onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              side: const BorderSide(color: AppColors.primaryGreen),
                              foregroundColor: AppColors.primaryGreen,
                            ),
                            child: Text(languageProvider.translate('retake')),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isAnalyzing ? null : _analyseProduce,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(languageProvider.translate('analyse')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // LOADING OVERLAY
          if (_isAnalyzing)
            Container(
              color: Colors.black.withAlpha(153), // 0.6 * 255
              width: double.infinity,
              height: size.height * 0.55,
              child: LoadingWidget(
                message: languageProvider.translate('identifying'),
              ),
            ),
            
          // Close button overlay for convenience
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
