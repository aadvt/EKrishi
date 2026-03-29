import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final message = languageProvider.isKannada
        ? 'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲ — ಕ್ಯಾಶ್ ಮಾಡಿದ ಡೇಟಾ ಮಾತ್ರ'
        : 'No internet — cached data only';

    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        ignoring: !isOffline,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          offset: isOffline ? Offset.zero : const Offset(0, 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 24),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isOffline ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
