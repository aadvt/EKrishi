import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/location_result.dart';

class LocationService {
  final _box = Hive.box('location');

  Future<LocationResult> getCurrentLocation() async {
    // 1. Check Cache
    final cachedData = _box.get('current_location');
    if (cachedData != null) {
      final cached = LocationResult.fromJson(Map<String, dynamic>.from(cachedData));
      final age = DateTime.now().difference(cached.fetchedAt);
      if (age.inHours < 1) {
        return cached;
      }
    }

    // 2. Request Permissions
    final status = await Permission.location.request();
    if (status.isDenied) {
      return _getManualOrFallback();
    }

    try {
      // 3. Get GPS Coordinates
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // 4. Reverse Geocode via OSM Nominatim
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'EKrishi-App/1.0 (ekrishi@gmail.com)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        // Hierarchical district parsing
        final String district = address['county'] ??
            address['state_district'] ??
            address['city_district'] ??
            'Unknown District';

        // City/Town/Village parsing
        final String city = address['city'] ??
            address['town'] ??
            address['village'] ??
            district;

        final result = LocationResult(
          country: address['country'] ?? 'India',
          state: address['state'] ?? 'Karnataka',
          district: district,
          city: city,
          latitude: position.latitude,
          longitude: position.longitude,
          isManualOverride: false,
          fetchedAt: DateTime.now(),
        );

        // 5. Cache and return
        await _box.put('current_location', result.toJson());
        return result;
      }
    } catch (e) {
      print('Error fetching location: $e');
    }

    return _getManualOrFallback();
  }

  LocationResult _getManualOrFallback() {
    final cachedData = _box.get('current_location');
    if (cachedData != null) {
      return LocationResult.fromJson(Map<String, dynamic>.from(cachedData));
    }

    return LocationResult(
      country: 'India',
      state: 'Karnataka',
      district: 'Tumkur',
      city: 'Tumkur',
      latitude: 13.3409,
      longitude: 77.1010,
      isManualOverride: true,
      fetchedAt: DateTime.now(),
    );
  }

  Future<void> setManualLocation(String district, String state) async {
    final result = LocationResult(
      country: 'India',
      state: state,
      district: district,
      city: district, // Use district as fallback for city
      latitude: 0.0,
      longitude: 0.0,
      isManualOverride: true,
      fetchedAt: DateTime.now(),
    );
    await _box.put('current_location', result.toJson());
  }

  Future<void> clearLocationCache() async {
    await _box.delete('current_location');
  }
}
