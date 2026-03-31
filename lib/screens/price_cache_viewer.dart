import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/cached_price.dart';
import '../constants/app_colors.dart';

class PriceCacheViewer extends StatelessWidget {
  const PriceCacheViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Price Cache Debug'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('cached_prices').listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('No prices cached yet.'),
            );
          }

          final keys = box.keys.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final key = keys[index];
              final data = box.get(key);
              final cached = CachedPrice.fromJson(Map<String, dynamic>.from(data));

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${cached.cropNameEnglish.toUpperCase()} (${cached.cropNameKannada})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cached.isStale ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cached.isStale ? 'STALE' : 'FRESH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: cached.isStale ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Location: ${cached.district}, ${cached.state}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _PriceBit(label: 'Min', value: cached.priceMin),
                        _PriceBit(label: 'Fair', value: cached.priceFair, highlight: true),
                        _PriceBit(label: 'Max', value: cached.priceMax),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Synced: ${DateFormat('yyyy-MM-dd HH:mm').format(cached.syncedAt)}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PriceBit extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _PriceBit({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            color: highlight ? AppColors.accentGreen : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
