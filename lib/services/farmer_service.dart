import 'package:hive_flutter/hive_flutter.dart';

class FarmerService {
  static final FarmerService _instance = FarmerService._internal();
  factory FarmerService() => _instance;
  FarmerService._internal();

  static const String _boxName = 'farmer_profile';
  static const String _phoneKey = 'phone_number';

  // Returns null if farmer has never entered their number.
  String? getPhoneNumber() {
    final box = Hive.box(_boxName);
    return box.get(_phoneKey) as String?;
  }

  Future<void> savePhoneNumber(String phone) async {
    final box = Hive.box(_boxName);
    await box.put(_phoneKey, phone);
  }

  Future<void> clearPhoneNumber() async {
    final box = Hive.box(_boxName);
    await box.delete(_phoneKey);
  }

  bool get hasPhoneNumber => getPhoneNumber() != null;
}
