import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../constants/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en';
  final Box _settingsBox = Hive.box('settings');

  String get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _loadLanguage();
  }

  void _loadLanguage() {
    _currentLanguage = _settingsBox.get('language', defaultValue: 'en');
    notifyListeners();
  }

  String translate(String key) {
    if (AppStrings.translations.containsKey(key)) {
      return AppStrings.translations[key]![_currentLanguage] ?? key;
    }
    return key;
  }

  Future<void> toggleLanguage() async {
    _currentLanguage = _currentLanguage == 'en' ? 'kn' : 'en';
    await _settingsBox.put('language', _currentLanguage);
    notifyListeners();
  }
}
