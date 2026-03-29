import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/location_result.dart';
import '../models/produce_result.dart';
import '../models/scan_history.dart';
import '../utils/language_provider.dart';
import 'camera_screen.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isKn ? 'ಬೆಲೆ ಫಲಿತಾಂಶ' : 'Price Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _ProduceHeroCard(
              imageFile: widget.imageFile,
              ripeness: widget.produceResult.ripeness,
              produceName: widget.produceResult.nameEnglish,
              produceNameKannada: widget.produceResult.nameKannada,
            ),
            const SizedBox(height: 16),
            _AiEstimateChip(isKn: isKn),
            const SizedBox(height: 16),
            _LocationRow(
              district: widget.locationResult.district,
              state: widget.locationResult.state,
              isManual: widget.locationResult.isManualOverride,
              manualLabel: languageProvider.translate('manual_tag'),
            ),
            const SizedBox(height: 16),
            _PriceCard(
              minPrice: widget.produceResult.priceRecommendedMin,
              fairPrice: widget.produceResult.priceFairPerKg,
              maxPrice: widget.produceResult.priceRecommendedMax,
              isKn: isKn,
            ),
            const SizedBox(height: 12),
            _ReasoningCard(reasoning: widget.produceResult.priceReasoning),
            const SizedBox(height: 12),
            _ConfidenceRow(confidence: widget.produceResult.priceConfidence, isKn: isKn),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                  (route) => route.isFirst,
                );
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(languageProvider.translate('scan_another')),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ProduceHeroCard extends StatelessWidget {
  final File imageFile;
  final String ripeness;
  final String produceName;
  final String produceNameKannada;

  const _ProduceHeroCard({
    required this.imageFile,
    required this.ripeness,
    required this.produceName,
    required this.produceNameKannada,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _ripenessBadge(ripeness);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageFile, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badge.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badge.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    produceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    produceNameKannada,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _RipenessBadgeStyle _ripenessBadge(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'ripe') {
      return const _RipenessBadgeStyle(
        label: 'ripe',
        background: Color(0xFFFFF3E0),
        foreground: AppColors.warning,
      );
    }
    if (v == 'overripe') {
      return const _RipenessBadgeStyle(
        label: 'overripe',
        background: Color(0xFFFFEBEE),
        foreground: AppColors.error,
      );
    }
    return const _RipenessBadgeStyle(
      label: 'fresh',
      background: AppColors.softGreen,
      foreground: AppColors.accentGreen,
    );
  }
}

class _RipenessBadgeStyle {
  final String label;
  final Color background;
  final Color foreground;

  const _RipenessBadgeStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });
}

class _AiEstimateChip extends StatelessWidget {
  final bool isKn;

  const _AiEstimateChip({required this.isKn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isKn ? 'AI ಬೆಲೆ ಅಂದಾಜು · ಸ್ಥಳ ಮತ್ತು ಋತುವಿನ ಆಧಾರಿತ' : 'AI price estimate · Based on location & season',
              style: const TextStyle(fontSize: 13, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String district;
  final String state;
  final bool isManual;
  final String manualLabel;

  const _LocationRow({
    required this.district,
    required this.state,
    required this.isManual,
    required this.manualLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on_rounded, size: 16, color: AppColors.accentGreen),
        const SizedBox(width: 4),
        Text(
          '$district, $state',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isManual) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              manualLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  final double minPrice;
  final double fairPrice;
  final double maxPrice;
  final bool isKn;

  const _PriceCard({
    required this.minPrice,
    required this.fairPrice,
    required this.maxPrice,
    required this.isKn,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _PriceRow(
            dotColor: AppColors.accentGreen,
            label: lang.translate('min_price'),
            caption: null,
            price: minPrice,
          ),
          const Divider(height: 1),
          _PriceRow(
            dotColor: AppColors.warning,
            label: lang.translate('fair_price'),
            caption: isKn ? 'ಶಿಫಾರಸು ಮಾಡಿದ ಮಾರಾಟ ಬೆಲೆ' : 'Recommended selling price',
            price: fairPrice,
          ),
          const Divider(height: 1),
          _PriceRow(
            dotColor: AppColors.info,
            label: lang.translate('max_price'),
            caption: null,
            price: maxPrice,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String? caption;
  final double price;

  const _PriceRow({
    required this.dotColor,
    required this.label,
    required this.caption,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          Text(
            '₹${price.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          const Text('/kg', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  final String reasoning;

  const _ReasoningCard({required this.reasoning});

  @override
  Widget build(BuildContext context) {
    if (reasoning.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 6),
              Text(
                'Market insight',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reasoning,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  final String confidence;
  final bool isKn;

  const _ConfidenceRow({required this.confidence, required this.isKn});

  @override
  Widget build(BuildContext context) {
    final level = confidence.toLowerCase().trim();

    late final Color dotColor;
    late final String text;
    late final String chipText;

    if (level == 'high') {
      dotColor = AppColors.accentGreen;
      text = isKn ? 'ಉನ್ನತ ವಿಶ್ವಾಸ' : 'High confidence';
      chipText = isKn ? 'ಉತ್ತಮ' : 'High';
    } else if (level == 'low') {
      dotColor = AppColors.error;
      text = isKn ? 'ಸ್ಥಳೀಯ ಮಂಡಿಯಲ್ಲಿ ಪರಿಶೀಲಿಸಿ' : 'Verify at local mandi';
      chipText = isKn ? 'ಕಡಿಮೆ' : 'Low';
    } else {
      dotColor = AppColors.warning;
      text = isKn ? 'ಮಧ್ಯಮ ವಿಶ್ವಾಸ' : 'Medium confidence';
      chipText = isKn ? 'ಮಧ್ಯಮ' : 'Medium';
    }

    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            chipText,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
