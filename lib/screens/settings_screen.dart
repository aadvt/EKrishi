import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/language_provider.dart';
import '../services/location_service.dart';
import '../models/location_result.dart';
import '../constants/app_colors.dart';

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
    'Karnataka', 'Tamil Nadu', 'Andhra Pradesh', 'Maharashtra', 'Kerala',
    'Telangana', 'Uttar Pradesh', 'Gujarat', 'Rajasthan', 'Madhya Pradesh',
    'Bihar', 'West Bengal', 'Punjab', 'Haryana', 'Odisha', 'Assam',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
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

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(lang.translate('settings')),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LANGUAGE SECTION
            _buildSectionHeader(lang.translate('language')),
            const SizedBox(height: 16),
            _buildLanguageToggle(lang),
            const Divider(height: 48),

            // LOCATION SECTION
            _buildSectionHeader(lang.translate('your_location')),
            const SizedBox(height: 16),
            if (_currentLocation != null)
              _buildCurrentLocationDisplay(lang),
            const SizedBox(height: 20),
            _buildLocationForm(lang),
            const SizedBox(height: 16),
            _buildResetLocationButton(lang),
            const Divider(height: 48),

            // CACHE SECTION
            _buildSectionHeader(lang.translate('cached_data')),
            const SizedBox(height: 12),
            Text(
              lang.translate('cache_info'),
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            _buildClearCacheButton(lang),

            const SizedBox(height: 60),

            // FOOTER
            _buildFooter(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildLanguageToggle(LanguageProvider lang) {
    final isEn = lang.currentLanguage == 'en';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageChip('English', isEn, () {
            if (!isEn) lang.toggleLanguage();
          }),
          _buildLanguageChip('ಕನ್ನಡ', !isEn, () {
            if (isEn) lang.toggleLanguage();
          }),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? AppColors.primaryGreen : AppColors.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLocationDisplay(LanguageProvider lang) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          '${_currentLocation!.city}, ${_currentLocation!.state}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        if (_currentLocation!.isManualOverride)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Chip(
              label: Text(lang.translate('manual_tag'), style: const TextStyle(fontSize: 10)),
              backgroundColor: Colors.grey.shade200,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildLocationForm(LanguageProvider lang) {
    return Column(
      children: [
        TextField(
          controller: _districtController,
          decoration: InputDecoration(
            labelText: lang.translate('district'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownMenu<String>(
          initialSelection: _selectedState,
          label: Text(lang.translate('state')),
          width: double.infinity,
          dropdownMenuEntries: _indianStates.map((state) {
            return DropdownMenuEntry<String>(value: state, label: state);
          }).toList(),
          onSelected: (val) {
            if (val != null) setState(() => _selectedState = val);
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saveManualLocation,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: Text(lang.translate('save_location')),
        ),
      ],
    );
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

  Widget _buildResetLocationButton(LanguageProvider lang) {
    return TextButton.icon(
      onPressed: () async {
        await _locationService.clearLocationCache();
        await _loadCurrentLocation();
      },
      icon: const Icon(Icons.gps_fixed, size: 18),
      label: Text(lang.translate('reset_to_gps')),
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
    );
  }

  Widget _buildClearCacheButton(LanguageProvider lang) {
    return TextButton.icon(
      onPressed: () async {
        await Hive.box('prices').clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.translate('cache_cleared'))),
          );
        }
      },
      icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.errorRed),
      label: Text(
        lang.translate('clear_price_cache'),
        style: const TextStyle(color: AppColors.errorRed),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text(
            'v1.0.0 — E-Krishi Module 1',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Prices sourced from Agmarknet, Government of India',
            style: TextStyle(color: AppColors.textGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
