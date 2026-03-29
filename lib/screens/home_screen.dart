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
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
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
      _connectionStatus = result.isEmpty ? ConnectivityResult.none : result.first;
    });
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

                // TOP SECTION
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isKn ? 'ರೈತ ಬೆಲೆ ಮಾರ್ಗದರ್ಶಿ' : 'Farmer Price Guide',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isKn ? 'ನಿಮ್ಮ' : 'Know your',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                    height: 1.05,
                  ),
                ),
                Text(
                  isKn ? 'ನ್ಯಾಯಬೆಲೆ.' : 'fair price.',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isKn
                      ? 'ಯಾವುದೇ ಬೆಳೆ ಮೇಲೆ ಕ್ಯಾಮೆರಾ ತೋರಿಸಿ — ತಕ್ಷಣ ನ್ಯಾಯಯುತ ಮಾರುಕಟ್ಟೆ ಬೆಲೆಯ ಅಂದಾಜು ಪಡೆಯಿರಿ.'
                      : 'Point your camera at any produce to get an instant fair market price estimate.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
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
                            MaterialPageRoute(builder: (context) => const CameraScreen()),
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
                              const Icon(Icons.camera_alt_rounded, size: 48, color: AppColors.accentGreen),
                              const SizedBox(height: 12),
                              Text(
                                isKn ? 'ಬೆಳೆ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ' : 'Tap to scan produce',
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                            MaterialPageRoute(builder: (context) => const CameraScreen()),
                          );
                        },
                        child: Text(languageProvider.translate('scan_produce')),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HistoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.history_rounded),
                        label: Text(languageProvider.translate('view_history')),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // STATS ROW
                const Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.verified_rounded,
                        value: '247+',
                        label: 'Crops',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.location_on_rounded,
                        value: 'Live',
                        label: 'Pricing',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.cloud_off_rounded,
                        value: 'Offline',
                        label: 'Ready',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    isKn ? 'AI ಮಾರುಕಟ್ಟೆ ವಿಶ್ಲೇಷಣೆಯಿಂದ ಬೆಲೆಗಳು' : 'Prices sourced from AI market analysis',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
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

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentGreen, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
