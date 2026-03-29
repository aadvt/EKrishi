class LocationResult {
  final String country;
  final String state;
  final String district;
  final String city;
  final double latitude;
  final double longitude;
  final bool isManualOverride;
  final DateTime fetchedAt;

  LocationResult({
    required this.country,
    required this.state,
    required this.district,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.isManualOverride,
    required this.fetchedAt,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      country: json['country'] ?? 'India',
      state: json['state'] ?? 'Karnataka',
      district: json['district'] ?? 'Tumkur',
      city: json['city'] ?? 'Tumkur',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isManualOverride: json['is_manual_override'] ?? false,
      fetchedAt: DateTime.parse(json['fetched_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'state': state,
      'district': district,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'is_manual_override': isManualOverride,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }

  LocationResult copyWith({
    String? country,
    String? state,
    String? district,
    String? city,
    double? latitude,
    double? longitude,
    bool? isManualOverride,
    DateTime? fetchedAt,
  }) {
    return LocationResult(
      country: country ?? this.country,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
