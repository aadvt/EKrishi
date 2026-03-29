import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      width: double.infinity,
      color: AppColors.amber,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        languageProvider.translate('offline_banner'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}
