import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../utils/language_provider.dart';
import 'settings_screen.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import '../services/price_sync_service.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    _triggerBackgroundSync();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _pulseController.dispose();
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
    if (connectivity.contains(ConnectivityResult.none) &&
        connectivity.length == 1) {
      return;
    }

    // Get location (uses cache — no extra API call)
    final location = await LocationService().getCurrentLocation();

    // Run sync in background — do not await, do not show UI
    PriceSyncService().syncPrices(location).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isOffline = _connectionStatus == ConnectivityResult.none;

    return Scaffold(
      backgroundColor: const Color(0xFFF2FAF5),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: -60,
            right: -60,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.1),
                      radius: 0.8,
                      colors: [
                        const Color(
                          0xFFB7E4C7,
                        ).withValues(alpha: 0.3 + _pulseAnimation.value * 0.1),
                        const Color(0xFFD8F3DC).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: -20,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.58,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final outerSide = lerpDouble(
                    320,
                    334,
                    _pulseAnimation.value,
                  )!;
                  final secondSide = lerpDouble(
                    255,
                    268,
                    _pulseAnimation.value,
                  )!;
                  final thirdSide = lerpDouble(
                    195,
                    205,
                    _pulseAnimation.value,
                  )!;
                  final innerSide = lerpDouble(
                    138,
                    145,
                    _pulseAnimation.value,
                  )!;
                  final iconSize = lerpDouble(48, 52, _pulseAnimation.value)!;

                  return SizedBox(
                    width: 340,
                    height: 340,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: outerSide,
                          height: outerSide,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFD8F3DC).withValues(alpha: 0.0),
                                const Color(0xFFD8F3DC).withValues(
                                  alpha: 0.25 + _pulseAnimation.value * 0.1,
                                ),
                                const Color(0xFFB7E4C7).withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.7, 1.0],
                            ),
                          ),
                        ),
                        Container(
                          width: secondSide,
                          height: secondSide,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(
                              color: const Color(0xFF74C69D).withValues(
                                alpha: 0.2 + _pulseAnimation.value * 0.15,
                              ),
                              width: 1.0,
                            ),
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFD8F3DC).withValues(alpha: 0.4),
                                const Color(0xFF95D5B2).withValues(alpha: 0.15),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: thirdSide,
                          height: thirdSide,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF52B788).withValues(
                                alpha: 0.3 + _pulseAnimation.value * 0.2,
                              ),
                              width: 1.0,
                            ),
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFB7E4C7).withValues(alpha: 0.6),
                                const Color(0xFF74C69D).withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: innerSide,
                          height: innerSide,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.2, -0.2),
                              colors: [
                                const Color(0xFF95D5B2).withValues(alpha: 0.95),
                                const Color(0xFF52B788).withValues(alpha: 0.9),
                                const Color(0xFF40916C).withValues(alpha: 0.85),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF52B788).withValues(
                                  alpha: 0.35 + _pulseAnimation.value * 0.15,
                                ),
                                blurRadius: 30,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFF74C69D,
                                ).withValues(alpha: 0.2),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.eco_rounded,
                          size: iconSize,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        Positioned(
                          top: 95,
                          left: 100,
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.tune_rounded,
                            color: const Color(
                              0xFF1A1A1A,
                            ).withValues(alpha: 0.5),
                            size: 22,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                        GestureDetector(
                          onTap: () => lang.toggleLanguage(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF1A1A1A,
                                ).withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              lang.currentLanguage == 'en' ? 'ಕನ್ನಡ' : 'EN',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(flex: 1, child: SizedBox()),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.translate('tagline'),
                          style: GoogleFonts.inter(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                            height: 1.15,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CameraScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1A1A1A,
                                  ).withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  lang.translate('scan'),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF1A1A1A,
                                ).withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  color: const Color(
                                    0xFF1A1A1A,
                                  ).withValues(alpha: 0.6),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lang.translate('history'),
                                  style: GoogleFonts.inter(
                                    color: const Color(
                                      0xFF1A1A1A,
                                    ).withValues(alpha: 0.7),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 140,
            left: 24,
            right: 24,
            child: AnimatedSlide(
              offset: isOffline ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isOffline ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang.translate('offline_banner'),
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
