import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/produce_result.dart';
import '../models/location_result.dart';
import '../models/scan_history.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';

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
        produceNameEnglish: widget.produceResult.nameEnglish,
        produceNameKannada: widget.produceResult.nameKannada,
        fairPrice: widget.produceResult.priceFairPerKg,
        district: widget.locationResult.district,
        scannedAt: DateTime.now(),
        imagePath: widget.imageFile.path,
      );
      await historyBox.add(entry.toJson());
    } catch (e) {
      debugPrint('Error saving to history: $e');
    }
  }

  Color _getRipenessColor(String ripeness) {
    switch (ripeness.toLowerCase()) {
      case 'fresh':
        return AppColors.successGreen;
      case 'ripe':
        return AppColors.amber;
      case 'overripe':
        return AppColors.errorRed;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(languageProvider.translate('price_estimate')),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI DISCLAIMER BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.blue.shade50,
              child: Text(
                languageProvider.translate('ai_disclaimer'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PRODUCE CARD
                  _buildProduceCard(languageProvider),
                  const SizedBox(height: 24),

                  // LOCATION ROW
                  _buildLocationRow(languageProvider),
                  const SizedBox(height: 16),

                  // PRICE CARD
                  _buildPriceCard(languageProvider),
                  const SizedBox(height: 12),

                  // REASONING
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      widget.produceResult.priceReasoning,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CONFIDENCE INDICATOR
                  _buildConfidenceIndicator(languageProvider),
                  const SizedBox(height: 32),

                  // SCAN ANOTHER BUTTON
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      languageProvider.translate('scan_another'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProduceCard(LanguageProvider lang) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: FileImage(widget.imageFile),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.4),
            BlendMode.darken,
          ),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.produceResult.nameEnglish,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.produceResult.nameKannada,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // Ripeness Badge
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getRipenessColor(widget.produceResult.ripeness),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.produceResult.ripeness.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Low Confidence Warning
          if (widget.produceResult.lowConfidence)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      lang.translate('low_confidence_warning'),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(LanguageProvider lang) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${lang.translate('prices_for')}: ${widget.locationResult.district}, ${widget.locationResult.state}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
        if (widget.locationResult.isManualOverride)
          Text(
            lang.translate('manual_tag'),
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
      ],
    );
  }

  Widget _buildPriceCard(LanguageProvider lang) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildPriceRow(
              dotColor: Colors.green,
              label: lang.translate('min_price'),
              price: widget.produceResult.priceRecommendedMin,
              isFair: false,
            ),
            const Divider(height: 24),
            _buildPriceRow(
              dotColor: AppColors.amber,
              label: lang.translate('fair_price'),
              price: widget.produceResult.priceFairPerKg,
              isFair: true,
            ),
            const Divider(height: 24),
            _buildPriceRow(
              dotColor: AppColors.errorRed,
              label: lang.translate('max_price'),
              price: widget.produceResult.priceRecommendedMax,
              isFair: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow({
    required Color dotColor,
    required String label,
    required double price,
    required bool isFair,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: isFair ? 18 : 16,
            fontWeight: isFair ? FontWeight.bold : FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        Text(
          '₹${price.toStringAsFixed(0)}/kg',
          style: TextStyle(
            fontSize: isFair ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: isFair ? AppColors.primaryGreen : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceIndicator(LanguageProvider lang) {
    Color color;
    String messageKey;
    IconData icon;

    switch (widget.produceResult.priceConfidence.toLowerCase()) {
      case 'high':
        color = AppColors.successGreen;
        messageKey = 'high_confidence_msg';
        icon = Icons.check_circle;
        break;
      case 'medium':
        color = AppColors.amber;
        messageKey = 'medium_confidence_msg';
        icon = Icons.info_outline;
        break;
      default:
        color = AppColors.errorRed;
        messageKey = 'low_confidence_msg';
        icon = Icons.warning_amber;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang.translate(messageKey),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
