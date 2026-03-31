import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../models/location_result.dart';
import '../services/location_service.dart';
import '../services/price_sync_service.dart';
import '../utils/language_provider.dart';
import 'price_cache_viewer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService _locationService = LocationService();
  final TextEditingController _districtController = TextEditingController();
  String _selectedState = 'Karnataka';
  LocationResult? _currentLocation;

  final List<String> _indianStates = [
    'Karnataka',
    'Tamil Nadu',
    'Andhra Pradesh',
    'Maharashtra',
    'Kerala',
    'Telangana',
    'Uttar Pradesh',
    'Gujarat',
    'Rajasthan',
    'Madhya Pradesh',
    'Bihar',
    'West Bengal',
    'Punjab',
    'Haryana',
    'Odisha',
    'Assam',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = location;
        _districtController.text = location.district;
        _selectedState = _indianStates.contains(location.state) ? location.state : 'Karnataka';
      });
    }
  }

  Future<void> _saveManualLocation() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    await _locationService.setManualLocation(_districtController.text, _selectedState);
    await _loadCurrentLocation();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('location_saved'))),
      );
    }
  }

  Future<void> _resetToGps(LanguageProvider lang) async {
    await _locationService.clearLocationCache();
    await _loadCurrentLocation();
  }

  Future<void> _clearPriceCache(LanguageProvider lang) async {
    await Hive.box('prices').clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('cache_cleared'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isKn = lang.isKannada;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(lang.translate('settings')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(text: 'PRICE SYNC'),
            _CardContainer(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 20, color: AppColors.accentGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isKn ? 'ಕೊನೆಯ ಬೆಲೆ ಸಿಂಕ್' : 'Last Price Sync',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                PriceSyncService().lastSyncTime() == null
                                    ? (isKn ? 'ಇನ್ನೂ ಸಿಂಕ್ ಆಗಿಲ್ಲ' : 'Never synced')
                                    : DateFormat('MMM d, hh:mm a').format(PriceSyncService().lastSyncTime()!),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final location = await _locationService.getCurrentLocation();
                            // To force sync, we clear the meta first
                            await Hive.box('price_sync_meta').clear();
                            await PriceSyncService().syncPrices(location);
                            if (mounted) setState(() {});
                          },
                          child: Text(isKn ? 'ಈಗ ಸಿಂಕ್ ಮಾಡಿ' : 'Sync Now'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PriceCacheViewer()),
                      );
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.textTertiary),
                          const SizedBox(width: 10),
                          Text(
                            isKn ? 'ಕ್ಯಾಶ್ ಮಾಡಲಾದ ಬೆಲೆಗಳನ್ನು ವೀಕ್ಷಿಸಿ' : 'View Cached Prices',
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel(text: 'LANGUAGE'),
            _CardContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, size: 20, color: AppColors.accentGreen),
                    const SizedBox(width: 10),
                    Text(
                      isKn ? 'ಭಾಷೆ' : 'Language',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    _LanguageSegmentedControl(isEnglish: lang.currentLanguage == 'en', onToggle: lang.toggleLanguage),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel(text: 'LOCATION'),
            _CardContainer(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 20, color: AppColors.accentGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isKn ? 'ಪ್ರಸ್ತುತ ಸ್ಥಳ' : 'Current Location',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentLocation == null
                                    ? '—'
                                    : '${_currentLocation!.district}, ${_currentLocation!.state}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (_currentLocation?.isManualOverride == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              isKn ? 'ಕೈಯಾರೆ' : 'Manual',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: lang.translate('district'),
                            child: TextField(
                              controller: _districtController,
                              decoration: const InputDecoration(hintText: ''),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledField(
                            label: lang.translate('state'),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedState,
                              items: _indianStates
                                  .map((state) => DropdownMenuItem<String>(value: state, child: Text(state)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedState = val);
                              },
                              decoration: const InputDecoration(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveManualLocation,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(lang.translate('save_location')),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => _resetToGps(lang),
                          style: TextButton.styleFrom(foregroundColor: AppColors.accentGreen),
                          child: Text(lang.translate('reset_to_gps')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel(text: 'DATA'),
            _CardContainer(
              child: InkWell(
                onTap: () => _clearPriceCache(lang),
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.black.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.cached_rounded, size: 20, color: AppColors.accentGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isKn ? 'ಬೆಲೆ ಕ್ಯಾಶ್ ತೆರವುಗೊಳಿಸಿ' : 'Clear Price Cache',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang.translate('cache_info'),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel(text: 'ABOUT'),
            _CardContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 20, color: AppColors.accentGreen),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'E-Krishi',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'v1.0.0 · Module 1',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _LanguageSegmentedControl extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onToggle;

  const _LanguageSegmentedControl({required this.isEnglish, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    Widget option({
      required String text,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.black.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 140,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          option(
            text: 'EN',
            isActive: isEnglish,
            onTap: () {
              if (!isEnglish) onToggle();
            },
          ),
          option(
            text: 'ಕನ್ನಡ',
            isActive: !isEnglish,
            onTap: () {
              if (isEnglish) onToggle();
            },
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

