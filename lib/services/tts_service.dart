import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45); // Slightly slow - easier to understand
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });
  }

  // Keep summary short so it is usable while farmer is in the field.
  String buildSummary({
    required String cropName,
    required double fairPrice,
    required double minPrice,
    required double maxPrice,
    required String priceReasoning,
    required String language, // 'en' or 'kn'
  }) {
    final price = fairPrice.toStringAsFixed(0);
    final min = minPrice.toStringAsFixed(0);
    final max = maxPrice.toStringAsFixed(0);

    if (language == 'kn') {
      return '$cropName. ನ್ಯಾಯಯುತ ಬೆಲೆ ಪ್ರತಿ ಕಿಲೋಗ್ರಾಂಗೆ '
          '$price ರೂಪಾಯಿ. '
          'ಕನಿಷ್ಠ $min ರೂಪಾಯಿ, '
          'ಗರಿಷ್ಠ $max ರೂಪಾಯಿ. '
          '$priceReasoning';
    } else {
      return '$cropName. '
          'Fair price is $price rupees per kilogram. '
          'You can sell between $min '
          'and $max rupees. '
          '$priceReasoning';
    }
  }

  Future<void> speak({
    required String text,
    required String language, // 'en' or 'kn'
  }) async {
    await _tts.stop();

    if (language == 'kn') {
      await _tts.setLanguage('kn-IN');
    } else {
      await _tts.setLanguage('en-IN');
    }

    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
