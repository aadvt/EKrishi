import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'camera_screen.dart';
import 'home_screen.dart';
import '../models/produce_result.dart';
import '../models/location_result.dart';
import '../models/scan_history.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final ProduceResult produceResult;
  final LocationResult locationResult;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.produceResult,
    required this.locationResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    try {
      final historyBox = Hive.box('history');
      final entry = ScanHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        produceNameEnglish: widget.produceResult.nameEnglish,
        produceNameKannada: widget.produceResult.nameKannada,
        fairPrice: widget.produceResult.priceFairPerKg,
        minPrice: widget.produceResult.priceRecommendedMin,
        maxPrice: widget.produceResult.priceRecommendedMax,
        district: widget.locationResult.district,
        scannedAt: DateTime.now(),
        imagePath: widget.imageFile.path,
      );
      await historyBox.add(entry);
    } catch (e) {
      debugPrint('Failed to save history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isKn = languageProvider.isKannada;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(languageProvider.translate('price_estimate')),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // AI Info Banner
            Container(
              width: double.infinity,
              color: Colors.blueGrey.shade50,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                languageProvider.translate('ai_disclaimer'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Image Card
                  Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Stack(
                      children: [
                        Image.file(
                          widget.imageFile,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isKn ? widget.produceResult.ripeness : widget.produceResult.ripeness.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Produce Info
                  Text(
                    isKn ? widget.produceResult.nameKannada : widget.produceResult.nameEnglish,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  // Location Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        widget.locationResult.district,
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
                      ),
                      if (widget.locationResult.isManualOverride) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            languageProvider.translate('manual_tag'),
                            style: const TextStyle(fontSize: 10, color: Colors.amber),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Divider(height: 48),

                  // PRICE BREAKDOWN
                  _buildPriceSection(languageProvider),

                  const Divider(height: 48),

                  // Confidence Meter
                  _buildConfidenceSection(languageProvider),

                  const SizedBox(height: 40),

                  // Buttons
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const CameraScreen()),
                        (route) => route.isFirst,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      languageProvider.translate('scan_another'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: Text(isKn ? 'ಮುಖಪುಟಕ್ಕೆ ಮರಳಿ' : 'Back to Home'),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 * 255
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            lang.translate('fair_price'),
            style: const TextStyle(fontSize: 16, color: AppColors.textGrey),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${widget.produceResult.priceFairPerKg.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
          ),
          const Text('per kg', style: TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSmallPrice(lang.translate('min_price'), widget.produceResult.priceRecommendedMin, Colors.green),
              _buildSmallPrice(lang.translate('max_price'), widget.produceResult.priceRecommendedMax, AppColors.errorRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallPrice(String label, double price, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        Text(
          '₹${price.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildConfidenceSection(LanguageProvider lang) {
    final conf = widget.produceResult.confidence;
    final String msgKey = conf > 0.85 ? 'high_confidence_msg' : (conf > 0.7 ? 'medium_confidence_msg' : 'low_confidence_msg');
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lang.translate('confidence'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${(conf * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: conf,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: conf > 0.7 ? AppColors.primaryGreen : Colors.amber,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          lang.translate(msgKey),
          style: TextStyle(
            fontSize: 12, 
            color: conf < 0.7 ? AppColors.errorRed : AppColors.textGrey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
