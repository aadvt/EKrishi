import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'sms_parser_service.dart';
import 'transaction_log_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permission on Android 13+.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final bool? granted = await androidPlugin
          .requestNotificationsPermission();
      debugPrint('Notification permission granted: $granted');
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'payment_detected',
      'Payment Detected',
      description: 'Alerts when a payment SMS is detected',
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showPaymentDetectedNotification({
    required ParsedPaymentSms parsedSms,
    required String cropName,
    required String cropNameKannada,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final String pendingKey = parsedSms.receivedAt.millisecondsSinceEpoch
        .toString();
    final Map<String, dynamic> pendingData = <String, dynamic>{
      'amount': parsedSms.amount,
      'buyer_name': parsedSms.buyerName,
      'upi_reference': parsedSms.upiReference,
      'raw_sms': parsedSms.rawSms,
      'crop_name': cropName,
      'crop_name_kannada': cropNameKannada,
      'received_at': parsedSms.receivedAt.toIso8601String(),
      'key': pendingKey,
    };

    final box = Hive.box('pending_sms_payments');
    await box.put(pendingKey, pendingData);

    final String amount = parsedSms.amount.toStringAsFixed(0);
    final String buyer = parsedSms.buyerName;
    final String title = '₹$amount received from $buyer';
    final String body = 'Was this for your $cropName? Tap to log it.';

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'payment_detected',
      'Payment Detected',
      channelDescription: 'Alerts when a payment SMS is detected',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Payment detected',
      fullScreenIntent: false,
      channelShowBadge: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        'Was this for your $cropName ($cropNameKannada)? Buyer: ${parsedSms.buyerName} · Amount: ₹${parsedSms.amount.toStringAsFixed(0)}',
        htmlFormatBigText: false,
        contentTitle:
            '₹${parsedSms.amount.toStringAsFixed(0)} received from ${parsedSms.buyerName}',
        htmlFormatContentTitle: false,
      ),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'confirm_yes',
          'Yes, log it ✓',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction('confirm_no', 'No', cancelNotification: true),
      ],
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      pendingKey.hashCode,
      title,
      body,
      notificationDetails,
      payload: pendingKey,
    );
  }

  Future<void> _onNotificationTap(NotificationResponse response) async {
    final String? pendingKey = response.payload;
    if (pendingKey == null) {
      return;
    }

    final box = Hive.box('pending_sms_payments');
    final dynamic pendingData = box.get(pendingKey);
    if (pendingData == null) {
      return;
    }

    if (response.actionId == 'confirm_no') {
      await box.delete(pendingKey);
      return;
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      pendingData as Map,
    );
    final bool logged = await TransactionLogService().logSmsTransaction(
      payload,
    );
    if (logged) {
      await box.delete(pendingKey);
      debugPrint('Notification confirmed and transaction logged: $pendingKey');
    } else {
      debugPrint('Notification confirmed but backend log failed: $pendingKey');
    }
  }
}
