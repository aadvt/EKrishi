import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:telephony/telephony.dart';

import '../models/scan_history.dart';
import 'notification_service.dart';
import 'sms_parser_service.dart';

class SmsMonitorService {
  static final SmsMonitorService _instance = SmsMonitorService._internal();
  factory SmsMonitorService() => _instance;
  SmsMonitorService._internal();

  final Telephony _telephony = Telephony.instance;
  bool _isListening = false;

  Future<void> requestPermissionsAndStart() async {
    if (_isListening) {
      return;
    }

    final bool? permissionsGranted =
        await _telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != true) {
      return;
    }

    await NotificationService().initialize();

    _telephony.listenIncomingSms(
      onNewMessage: _onSmsReceived,
      listenInBackground: false,
    );

    _isListening = true;
    debugPrint('SMS monitoring started');
  }

  Future<void> _onSmsReceived(SmsMessage message) async {
    final String body = message.body ?? '';
    // ignore: avoid_print
    print('━━━ SMS RECEIVED ━━━');
    // ignore: avoid_print
    print('From: ${message.address}');
    // ignore: avoid_print
    print('Body: $body');
    // ignore: avoid_print
    print('Length: ${body.length}');

    if (body.isEmpty) {
      // ignore: avoid_print
      print('SMS body empty - ignoring');
      return;
    }

    final ParsedPaymentSms? parsed = SmsParserService().parseSms(body);

    if (parsed == null) {
      // ignore: avoid_print
      print('SMS not a payment - ignoring');
      return;
    }

    // ignore: avoid_print
    print(
      'Payment detected! Amount: ₹${parsed.amount} Buyer: ${parsed.buyerName}',
    );

    String cropName = 'produce';
    String cropNameKannada = 'ಬೆಳೆ';

    try {
      final Box historyBox = Hive.box('history');
      if (historyBox.isNotEmpty) {
        final List<dynamic> keys = historyBox.keys.toList();
        final dynamic lastKey = keys.last;
        final dynamic lastEntry = historyBox.get(lastKey);
        if (lastEntry != null) {
          if (lastEntry is ScanHistory) {
            cropName = lastEntry.produceNameEnglish;
            cropNameKannada = lastEntry.produceNameKannada;
          } else if (lastEntry is Map) {
            cropName =
                (lastEntry['produceNameEnglish'] ??
                        lastEntry['produce_name_english'] ??
                        'produce')
                    .toString();
            cropNameKannada =
                (lastEntry['produceNameKannada'] ??
                        lastEntry['produce_name_kannada'] ??
                        'ಬೆಳೆ')
                    .toString();
          }
          // ignore: avoid_print
          print('Correlated with crop: $cropName');
        }
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error getting last scan: $error - using default');
    }

    // ignore: avoid_print
    print('Showing notification...');
    try {
      await NotificationService().showPaymentDetectedNotification(
        parsedSms: parsed,
        cropName: cropName,
        cropNameKannada: cropNameKannada,
      );
      // ignore: avoid_print
      print('Notification shown successfully');
    } catch (error) {
      // ignore: avoid_print
      print('ERROR showing notification: $error');
    }
  }
}

@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ScanHistoryAdapter());
  }
  if (!Hive.isBoxOpen('history')) {
    await Hive.openBox('history');
  }
  if (!Hive.isBoxOpen('pending_sms_payments')) {
    await Hive.openBox('pending_sms_payments');
  }

  final ParsedPaymentSms? parsed = SmsParserService().parseSms(
    message.body ?? '',
  );
  if (parsed == null) {
    return;
  }

  await NotificationService().initialize();
  await NotificationService().showPaymentDetectedNotification(
    parsedSms: parsed,
    cropName: 'produce',
    cropNameKannada: 'ಬೆಳೆ',
  );
}
