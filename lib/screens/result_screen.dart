import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/location_result.dart';
import '../models/produce_result.dart';
import '../models/scan_history.dart';
import '../services/farmer_service.dart';
import '../services/marketplace_service.dart';
import '../services/produce_service.dart';
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
  bool _isPushingToMarket = false;
  bool _hasListedToMarket = false;
  bool _hasInternet = false;
  bool _isLoadingInsight = false;
  bool _hasRequestedInsight = false;
  late ProduceResult _displayProduceResult;

  bool get _isTfliteResult =>
      _displayProduceResult.gradeReasoning.startsWith('Identified on-device');

  String _uiPriceReasoning(String rawReasoning) {
    final lines = rawReasoning.split('\n').where((line) {
      final lower = line.toLowerCase();
      return !lower.contains('cached') && !lower.contains('offline mode');
    }).toList();

    return lines.join('\n').trim();
  }

  @override
  void initState() {
    super.initState();
    _displayProduceResult = widget.produceResult;
    _checkInternet();
    _saveToHistory();
  }

  Future<void> _checkInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet =
        !connectivityResult.contains(ConnectivityResult.none) ||
        connectivityResult.length > 1;
    if (!mounted) return;
    setState(() => _hasInternet = hasInternet);
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

  Future<void> _pushToMarketplace() async {
    final hasPhone = FarmerService().hasPhoneNumber;

    if (!hasPhone) {
      await _showPhoneNumberSheet();
      if (!mounted) {
        return;
      }
      if (!FarmerService().hasPhoneNumber) {
        return;
      }
    }

    final phone = FarmerService().getPhoneNumber()!;
    final quantityKg = await _showQuantitySheet();

    if (quantityKg == null || !mounted) {
      return;
    }

    setState(() => _isPushingToMarket = true);

    final result = await MarketplaceService().pushListing(
      _displayProduceResult,
      widget.locationResult,
      phone,
      quantityKg,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isPushingToMarket = false);

    if (result.success) {
      setState(() => _hasListedToMarket = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to list. Please try again.'),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _loadAiMarketInsight() async {
    setState(() => _isLoadingInsight = true);

    try {
      final insight = await ProduceService().generateMarketInsight(
        produceName: _displayProduceResult.nameEnglish,
        produceNameKannada: _displayProduceResult.nameKannada,
        district: widget.locationResult.district,
        state: widget.locationResult.state,
      );

      if (!mounted) return;

      setState(() {
        _hasRequestedInsight = true;
        _displayProduceResult = _displayProduceResult.copyWith(
          priceReasoning:
              '${_displayProduceResult.priceReasoning}\n\nAI Market Insight:\n$insight',
          priceConfidence: 'high',
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch AI market insight right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingInsight = false);
      }
    }
  }

  Future<void> _showPhoneNumberSheet() async {
    final controller = TextEditingController();
    final parentContext = context;

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.storefront_rounded,
              size: 32,
              color: Color(0xFF2D6A4F),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your phone number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buyers will contact you on this number. You only need to enter this once.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B6B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91 ',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2D6A4F),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  final phone = controller.text.trim();
                  if (phone.length != 10 || int.tryParse(phone) == null) {
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid 10-digit number'),
                        backgroundColor: Color(0xFF1A1A1A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  await FarmerService().savePhoneNumber(phone);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: const Text(
                  'Save & Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<double?> _showQuantitySheet() async {
    final controller = TextEditingController();
    String? errorText;

    final quantityKg = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            var isClosing = false;

            void submit() {
              final raw = controller.text.trim().replaceAll(',', '.');
              final parsed = double.tryParse(raw);

              if (parsed == null || parsed <= 0) {
                setDialogState(() {
                  errorText = 'Please enter a valid quantity in kg';
                });
                return;
              }

              if (isClosing) {
                return;
              }
              isClosing = true;

              FocusManager.instance.primaryFocus?.unfocus();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              });
            }

            return AlertDialog(
              title: const Text('Enter quantity to list'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How many kilograms are you selling?'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Quantity in kg',
                      suffixText: 'kg',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submit,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return quantityKg;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isKn = languageProvider.isKannada;
    final produceResult = _displayProduceResult;

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
            icon: const Icon(
              Icons.share_rounded,
              color: AppColors.textSecondary,
            ),
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
              ripeness: produceResult.ripeness,
              grade: produceResult.grade,
              produceName: produceResult.nameEnglish,
              produceNameKannada: produceResult.nameKannada,
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
              minPrice: produceResult.priceRecommendedMin,
              fairPrice: produceResult.priceFairPerKg,
              maxPrice: produceResult.priceRecommendedMax,
              isKn: isKn,
            ),
            const SizedBox(height: 12),
            _ReasoningCard(
              priceReasoning: _uiPriceReasoning(produceResult.priceReasoning),
              gradeReasoning: produceResult.gradeReasoning,
            ),
            const SizedBox(height: 12),
            _ConfidenceRow(
              confidence: produceResult.priceConfidence,
              isKn: isKn,
            ),
            if (_isTfliteResult && _hasInternet && !_hasRequestedInsight) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingInsight ? null : _loadAiMarketInsight,
                  icon: _isLoadingInsight
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.insights_rounded, size: 20),
                  label: Text(
                    _isLoadingInsight
                        ? 'Getting AI market insight...'
                        : 'Get AI Market Insight',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFF1A1A1A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _hasListedToMarket
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8F3DC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF52B788)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2D6A4F),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Listed to marketplace!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Buyers in your area can now see this listing',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF52B788),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isPushingToMarket ? null : _pushToMarketplace,
                      child: _isPushingToMarket
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Listing...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.storefront_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Push to Marketplace',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
            const SizedBox(height: 12),
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
  final String grade;
  final String produceName;
  final String produceNameKannada;

  const _ProduceHeroCard({
    required this.imageFile,
    required this.ripeness,
    required this.grade,
    required this.produceName,
    required this.produceNameKannada,
  });

  @override
  Widget build(BuildContext context) {
    final ripenessBadge = _ripenessBadge(ripeness);
    final gradeBadge = _gradeBadge(grade);

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gradeBadge.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          gradeBadge.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: gradeBadge.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ripenessBadge.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ripenessBadge.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ripenessBadge.foreground,
                          ),
                        ),
                      ),
                    ],
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

  _BadgeStyle _gradeBadge(String value) {
    final v = value.toUpperCase().trim();
    switch (v) {
      case 'A':
        return const _BadgeStyle(
          label: 'Grade A',
          background: Color(0xFFD8F3DC),
          foreground: Color(0xFF2D6A4F),
        );
      case 'B':
        return const _BadgeStyle(
          label: 'Grade B',
          background: Color(0xFFFFF3E0),
          foreground: Color(0xFFF4A261),
        );
      case 'C':
        return const _BadgeStyle(
          label: 'Grade C',
          background: Color(0xFFFFEBEE),
          foreground: Color(0xFFE63946),
        );
      default:
        return const _BadgeStyle(
          label: 'Grade B',
          background: Color(0xFFFFF3E0),
          foreground: Color(0xFFF4A261),
        );
    }
  }

  _BadgeStyle _ripenessBadge(String value) {
    final ripeness = value.toLowerCase().trim();

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (ripeness) {
      case 'fresh':
        badgeBg = const Color(0xFFD8F3DC);
        badgeText = const Color(0xFF2D6A4F);
        badgeLabel = 'Fresh';
        break;
      case 'ripe':
        badgeBg = const Color(0xFFFFF3E0);
        badgeText = const Color(0xFFF4A261);
        badgeLabel = 'Ripe';
        break;
      case 'overripe':
        badgeBg = const Color(0xFFFFEBEE);
        badgeText = const Color(0xFFE63946);
        badgeLabel = 'Overripe';
        break;
      case 'unknown':
      default:
        badgeBg = const Color(0xFFF5F5F5);
        badgeText = const Color(0xFF6B6B6B);
        badgeLabel = 'Standard';
        break;
    }

    return _BadgeStyle(
      label: badgeLabel,
      background: badgeBg,
      foreground: badgeText,
    );
  }
}

class _BadgeStyle {
  final String label;
  final Color background;
  final Color foreground;

  const _BadgeStyle({
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
          const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isKn
                  ? 'AI ಬೆಲೆ ಅಂದಾಜು · ಸ್ಥಳ ಮತ್ತು ಋತುವಿನ ಆಧಾರಿತ'
                  : 'Smart price estimate · Based on location & season',
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
        const Icon(
          Icons.location_on_rounded,
          size: 16,
          color: AppColors.accentGreen,
        ),
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
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
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
            caption: isKn
                ? 'ಶಿಫಾರಸು ಮಾಡಿದ ಮಾರಾಟ ಬೆಲೆ'
                : 'Recommended selling price',
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '₹${price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '/kg',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  final String priceReasoning;
  final String gradeReasoning;

  const _ReasoningCard({
    required this.priceReasoning,
    required this.gradeReasoning,
  });

  ({List<String> english, List<String> kannada})? _parseBilingualInsight(
    String raw,
  ) {
    final match = RegExp(
      r'English\s*:\s*([\s\S]*?)\s*Kannada\s*:\s*([\s\S]*)',
      caseSensitive: false,
    ).firstMatch(raw);

    if (match == null) return null;

    final english = _normalizeLines(match.group(1) ?? '');
    final kannada = _normalizeLines(match.group(2) ?? '');

    if (english.isEmpty && kannada.isEmpty) return null;
    return (english: english, kannada: kannada);
  }

  List<String> _normalizeLines(String block) {
    return block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-•\d.)\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightLine(String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightPanel({required Widget header, required List<String> lines}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 10),
          ...lines.map(_insightLine),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPriceRea = priceReasoning.trim().isNotEmpty;
    final hasGradeRea = gradeReasoning.trim().isNotEmpty;
    final parsedBilingual = hasPriceRea
        ? _parseBilingualInsight(priceReasoning)
        : null;

    if (!hasPriceRea && !hasGradeRea) return const SizedBox.shrink();

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
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              SizedBox(width: 6),
              Text(
                'Quality & Market Insight',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasGradeRea) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '🔍 $gradeReasoning',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (hasPriceRea && parsedBilingual != null) ...[
            _insightPanel(
              header: _sectionHeader(
                icon: Icons.translate_rounded,
                label: 'English',
                bg: const Color(0xFFEAF3FF),
                fg: const Color(0xFF1F5FA8),
              ),
              lines: parsedBilingual.english,
            ),
            const SizedBox(height: 10),
            _insightPanel(
              header: _sectionHeader(
                icon: Icons.language_rounded,
                label: 'Kannada',
                bg: const Color(0xFFEAF8EF),
                fg: const Color(0xFF216E3A),
              ),
              lines: parsedBilingual.kannada,
            ),
          ] else if (hasPriceRea)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '📈 $priceReasoning',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
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
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
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
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
