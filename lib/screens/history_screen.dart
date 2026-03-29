import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/scan_history.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
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
              style: const TextStyle(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailBottomSheet(ScanHistory history) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Hero(
                  tag: history.id,
                  child: Image.file(
                    File(history.imagePath),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 64, color: AppColors.textGrey),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.produceNameEnglish,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      history.produceNameKannada,
                      style: const TextStyle(fontSize: 18, color: AppColors.textGrey),
                    ),
                    const Divider(height: 32),
                    _buildDetailRow(Icons.location_on, '${lang.translate('location')}: ${history.district}'),
                    _buildDetailRow(Icons.calendar_today, DateFormat('dd MMM yyyy, hh:mm a').format(history.scannedAt)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildPriceRowSmall(lang.translate('min_price'), history.minPrice, Colors.green),
                          const Divider(),
                          _buildPriceRowSmall(lang.translate('fair_price'), history.fairPrice, AppColors.primaryGreen, isBold: true),
                          const Divider(),
                          _buildPriceRowSmall(lang.translate('max_price'), history.maxPrice, AppColors.errorRed),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CameraScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        lang.translate('scan_again'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRowSmall(String label, double price, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '₹${price.toStringAsFixed(0)}/kg',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textGrey),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16, color: AppColors.textDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    // Watch box for changes
    return ValueListenableBuilder(
      valueListenable: _historyBox.listenable(),
      builder: (context, Box box, _) {
        final List histories = box.values.toList();
        // Sort DESC
        histories.sort((a, b) {
          final historyA = a is ScanHistory ? a : ScanHistory.fromJson(Map<String, dynamic>.from(a));
          final historyB = b is ScanHistory ? b : ScanHistory.fromJson(Map<String, dynamic>.from(b));
          return historyB.scannedAt.compareTo(historyA.scannedAt);
        });

        return Scaffold(
          backgroundColor: AppColors.backgroundWhite,
          appBar: AppBar(
            title: Text(lang.translate('price_history')),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
            actions: [
              if (histories.isNotEmpty)
                TextButton(
                  onPressed: _confirmClear,
                  child: Text(
                    lang.translate('clear'),
                    style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          body: histories.isEmpty
              ? _buildEmptyState(lang)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: histories.length,
                  itemBuilder: (context, index) {
                    final dynamic data = histories[index];
                    final history = data is ScanHistory ? data : ScanHistory.fromJson(Map<String, dynamic>.from(data));
                    return _buildHistoryCard(history, lang);
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 80, color: AppColors.textGrey),
          const SizedBox(height: 16),
          Text(
            lang.translate('no_history'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            lang.translate('history_empty_subtitle'),
            style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ScanHistory history, LanguageProvider lang) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black12,
      child: ListTile(
        onTap: () => _showDetailBottomSheet(history),
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Hero(
            tag: history.id,
            child: Image.file(
              File(history.imagePath),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, color: AppColors.textGrey),
              ),
            ),
          ),
        ),
        title: Text(
          lang.isKannada ? history.produceNameKannada : history.produceNameEnglish,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(history.district, style: const TextStyle(fontSize: 12)),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(history.scannedAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ],
        ),
        trailing: Text(
          '₹${history.fairPrice.toStringAsFixed(0)}/kg',
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
