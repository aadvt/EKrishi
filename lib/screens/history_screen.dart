import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/scan_history.dart';
import '../utils/language_provider.dart';
import 'camera_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box _historyBox;

  @override
  void initState() {
    super.initState();
    _historyBox = Hive.box('history');
  }

  void _confirmClear() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('confirm_clear_title')),
        content: Text(lang.translate('confirm_clear_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _historyBox.clear();
              });
              Navigator.pop(context);
            },
            child: Text(
              lang.translate('clear'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailBottomSheet(ScanHistory history) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isKn = lang.isKannada;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Image.file(
                      File(history.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.softGreen,
                        alignment: Alignment.center,
                        child: const Icon(Icons.eco_rounded, size: 40, color: AppColors.accentGreen),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  history.produceNameEnglish,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  history.produceNameKannada,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _PriceDetailsCard(
                  minPrice: history.minPrice,
                  fairPrice: history.fairPrice,
                  maxPrice: history.maxPrice,
                  isKn: isKn,
                  minLabel: lang.translate('min_price'),
                  fairLabel: lang.translate('fair_price'),
                  maxLabel: lang.translate('max_price'),
                ),
                const SizedBox(height: 16),
                Text(
                  '${history.district} · ${DateFormat('dd MMM, hh:mm a').format(history.scannedAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CameraScreen()),
                    );
                  },
                  child: Text(lang.translate('scan_again')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return ValueListenableBuilder(
      valueListenable: _historyBox.listenable(),
      builder: (context, Box box, _) {
        final List histories = box.values.toList();
        histories.sort((a, b) {
          final historyA = a is ScanHistory ? a : ScanHistory.fromJson(Map<String, dynamic>.from(a));
          final historyB = b is ScanHistory ? b : ScanHistory.fromJson(Map<String, dynamic>.from(b));
          return historyB.scannedAt.compareTo(historyA.scannedAt);
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(lang.isKannada ? 'ಇತಿಹಾಸ' : 'History'),
            actions: [
              if (histories.isNotEmpty)
                TextButton(
                  onPressed: _confirmClear,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  child: Text(lang.translate('clear')),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: histories.isEmpty
              ? _EmptyHistoryState(subtitle: lang.translate('history_empty_subtitle'), title: lang.translate('no_history'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: histories.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final today = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          today,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }

                    final dynamic data = histories[index - 1];
                    final history = data is ScanHistory ? data : ScanHistory.fromJson(Map<String, dynamic>.from(data));
                    return _HistoryCard(
                      history: history,
                      isKn: lang.isKannada,
                      onTap: () => _showDetailBottomSheet(history),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyHistoryState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 64, color: AppColors.border),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanHistory history;
  final bool isKn;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.history,
    required this.isKn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd MMM, hh:mm a').format(history.scannedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.black.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.file(
                    File(history.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.softGreen,
                      alignment: Alignment.center,
                      child: const Icon(Icons.eco_rounded, color: AppColors.accentGreen),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKn ? history.produceNameKannada : history.produceNameEnglish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${history.district} · $dateText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${history.fairPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('/kg', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceDetailsCard extends StatelessWidget {
  final String minLabel;
  final String fairLabel;
  final String maxLabel;
  final double minPrice;
  final double fairPrice;
  final double maxPrice;
  final bool isKn;

  const _PriceDetailsCard({
    required this.minLabel,
    required this.fairLabel,
    required this.maxLabel,
    required this.minPrice,
    required this.fairPrice,
    required this.maxPrice,
    required this.isKn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _PriceRow(dotColor: AppColors.accentGreen, label: minLabel, caption: null, price: minPrice),
          const Divider(height: 1),
          _PriceRow(
            dotColor: AppColors.warning,
            label: fairLabel,
            caption: isKn ? 'ಶಿಫಾರಸು ಮಾಡಿದ ಮಾರಾಟ ಬೆಲೆ' : 'Recommended selling price',
            price: fairPrice,
          ),
          const Divider(height: 1),
          _PriceRow(dotColor: AppColors.info, label: maxLabel, caption: null, price: maxPrice),
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
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
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

