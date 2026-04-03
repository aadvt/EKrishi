import 'package:hive_flutter/hive_flutter.dart';

class FarmerService {
  static final FarmerService _instance = FarmerService._internal();
  factory FarmerService() => _instance;
  FarmerService._internal();

  static const String _boxName = 'farmer_profile';
  static const String _phoneKey = 'phone_number';
  static const String _fullNameKey = 'full_name';

  // Returns null if farmer has never entered their number.
  String? getPhoneNumber() {
    final box = Hive.box(_boxName);
    return box.get(_phoneKey) as String?;
  }

  Future<void> savePhoneNumber(String phone) async {
    final box = Hive.box(_boxName);
    await box.put(_phoneKey, phone);
  }

  String? getFullName() {
    final box = Hive.box(_boxName);
    return box.get(_fullNameKey) as String?;
  }

  Future<void> saveFullName(String name) async {
    final box = Hive.box(_boxName);
    await box.put(_fullNameKey, name.trim());
  }

  Future<void> clearPhoneNumber() async {
    final box = Hive.box(_boxName);
    await box.delete(_phoneKey);
  }

  Future<void> clearFullName() async {
    final box = Hive.box(_boxName);
    await box.delete(_fullNameKey);
  }

  bool get hasPhoneNumber => getPhoneNumber() != null;

  bool get hasFullName {
    final name = getFullName();
    return name != null && name.trim().isNotEmpty;
  }
}
