import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
import 'settings_screen.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import '../widgets/offline_banner.dart';
import '../services/price_sync_service.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    _triggerBackgroundSync();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      _connectionStatus = result.isEmpty
          ? ConnectivityResult.none
          : result.first;
    });
  }

  Future<void> _triggerBackgroundSync() async {
    // Only run if we have internet
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) && connectivity.length == 1) return;

    // Get location (uses cache — no extra API call)
    final location = await LocationService().getCurrentLocation();

    // Run sync in background — do not await, do not show UI
    PriceSyncService().syncPrices(location).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isOffline = _connectionStatus == ConnectivityResult.none;
    final isKn = languageProvider.isKannada;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.black.withValues(alpha: 0.04),
              onTap: () => languageProvider.toggleLanguage(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  languageProvider.currentLanguage == 'en' ? 'ಕನ್ನಡ' : 'EN',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                const Icon(
                  Icons.eco_rounded,
                  size: 32,
                  color: Color(0xFF52B788),
                ),
                const SizedBox(height: 16),
                Text(
                  isKn ? 'ನಿಮ್ಮ ನ್ಯಾಯಬೆಲೆ ತಿಳಿಯಿರಿ.' : 'Know your fair price.',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isKn
                      ? 'ಯಾವುದೇ ಬೆಳೆ ಮೇಲೆ ಕ್ಯಾಮೆರಾ ತೋರಿಸಿ — ತಕ್ಷಣ ನ್ಯಾಯಯುತ ಮಾರುಕಟ್ಟೆ ಬೆಲೆಯ ಅಂದಾಜು ಪಡೆಯಿರಿ.'
                      : 'Point your camera at any produce to get an instant fair market price estimate.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B6B6B),
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // MAIN CARD
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        splashColor: Colors.black.withValues(alpha: 0.04),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CameraScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.softGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.camera_alt_rounded,
                                size: 48,
                                color: AppColors.accentGreen,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isKn
                                    ? 'ಬೆಳೆ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'
                                    : 'Tap to scan produce',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CameraScreen(),
                            ),
                          );
                        },
                        child: Text(languageProvider.translate('scan_produce')),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded),
                        label: Text(languageProvider.translate('view_history')),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    isKn
                        ? 'AI ಮಾರುಕಟ್ಟೆ ವಿಶ್ಲೇಷಣೆಯಿಂದ ಬೆಲೆಗಳು'
                        : 'Prices sourced from AI market analysis',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // OFFLINE BANNER (floating, iOS-style)
          OfflineBanner(isOffline: isOffline),
        ],
      ),
    );
  }
}
