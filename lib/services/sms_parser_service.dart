class ParsedPaymentSms {
  final double amount;
  final String buyerName;
  final String upiReference;
  final String rawSms;
  final DateTime receivedAt;

  ParsedPaymentSms({
    required this.amount,
    required this.buyerName,
    required this.upiReference,
    required this.rawSms,
    required this.receivedAt,
  });
}

class SmsParserService {
  static final SmsParserService _instance = SmsParserService._internal();
  factory SmsParserService() => _instance;
  SmsParserService._internal();

  ParsedPaymentSms? parseSms(String smsBody) {
    if (smsBody.isEmpty) {
      return null;
    }

    final String compactSms = smsBody.replaceAll(RegExp(r'\s+'), ' ').trim();
    final String lower = compactSms.toLowerCase();

    final bool isDebit =
        lower.contains('debited') ||
        lower.contains('debit for') ||
        lower.contains('withdrawn') ||
        lower.contains('sent to') ||
        RegExp(r'\bdr\b', caseSensitive: false).hasMatch(lower);

    final bool isCredit =
        lower.contains('credited with') ||
        lower.contains('is credited') ||
        lower.contains('has been credited') ||
        lower.contains('credit of') ||
        lower.contains('received from') ||
        lower.contains('credited to') ||
        lower.contains('deposited') ||
        RegExp(r'\bcr\b', caseSensitive: false).hasMatch(lower);

    if (isDebit && !isCredit) {
      return null;
    }
    if (!isCredit) {
      return null;
    }

    if (lower.contains('otp') ||
        lower.contains('password') ||
        lower.contains('pin') ||
        lower.contains('block') ||
        lower.contains('cvv')) {
      return null;
    }

    double? amount;
    final List<RegExp> amountPatterns = <RegExp>[
      RegExp(
        r'(?:rs|inr)\.?\s*[:\-]?\s*(\d[\d,]*(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(r'₹\s*[:\-]?\s*(\d[\d,]*(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)\s*(?:rs|inr)\b', caseSensitive: false),
      RegExp(
        r'amount\s*(?:of)?\s*(?:rs|inr|₹)?\s*(\d[\d,]*(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
    ];

    for (final RegExp pattern in amountPatterns) {
      final RegExpMatch? match = pattern.firstMatch(compactSms);
      if (match == null) {
        continue;
      }
      final String raw = (match.group(1) ?? '').replaceAll(',', '').trim();
      amount = double.tryParse(raw);
      if (amount != null && amount > 0) {
        break;
      }
    }

    if (amount == null || amount <= 0) {
      return null;
    }
    // TODO: add minimum Rs 100 filter after demo day.

    String buyerName = 'Unknown Buyer';
    final List<RegExp> buyerPatterns = <RegExp>[
      RegExp(
        r'from\s+([A-Za-z0-9][A-Za-z0-9\s&\.\-@]{1,80}?)(?:\s+(?:on|via|through|upi|utr|ref|info|at)\b|[\.;,]|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'by\s+([A-Za-z0-9][A-Za-z0-9\s&\.\-@]{1,80}?)(?:\s+(?:via|upi|utr|ref)\b|[\.;,]|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:sender|remitter)[:\s]+([A-Za-z0-9][A-Za-z0-9\s&\.\-@]{1,80}?)(?:\s+(?:via|upi|utr|ref)\b|[\.;,]|$)',
        caseSensitive: false,
      ),
      RegExp(r'vpa[:\s]+([A-Za-z0-9._\-]{3,})@', caseSensitive: false),
    ];

    for (final RegExp pattern in buyerPatterns) {
      final RegExpMatch? match = pattern.firstMatch(compactSms);
      if (match == null) {
        continue;
      }

      String cleaned = (match.group(1) ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.contains('@')) {
        cleaned = cleaned.split('@').first;
      }
      cleaned = cleaned.replaceAll(RegExp(r'[_\-\.]+'), ' ').trim();

      const List<String> bankSuffixes = <String>[
        '-ICICI Bank',
        '-HDFC Bank',
        '-SBI',
        '-AXIS Bank',
        '-Kotak',
        ' Bank',
        'ICICI',
        'HDFC',
        'Axis',
        'Kotak',
        'SBI',
      ];
      for (final String suffix in bankSuffixes) {
        if (cleaned.toLowerCase().endsWith(suffix.toLowerCase())) {
          cleaned = cleaned.substring(0, cleaned.length - suffix.length).trim();
        }
      }

      cleaned = cleaned.replaceAll(RegExp(r'[.,;:\s]+$'), '').trim();
      if (cleaned.isEmpty) {
        continue;
      }

      const Set<String> nonBuyerTokens = <String>{
        'upi',
        'neft',
        'imps',
        'rtgs',
        'bank',
        'account',
        'transfer',
        'payment',
        'credited',
        'received',
        'deposited',
        'icici',
        'hdfc',
        'sbi',
        'axis',
        'kotak',
      };
      if (nonBuyerTokens.contains(cleaned.toLowerCase())) {
        continue;
      }

      buyerName = cleaned;
      break;
    }

    String upiRef = '';
    final List<RegExp> upiPatterns = <RegExp>[
      RegExp(r'UPI[:\s]+(\d{10,20})', caseSensitive: false),
      RegExp(r'UPI[\s:#-]*([A-Z0-9\-]{8,30})', caseSensitive: false),
      RegExp(r'Ref[\s:]+([A-Z0-9]{8,20})', caseSensitive: false),
      RegExp(r'Txn[\s:]+([A-Z0-9]{8,20})', caseSensitive: false),
      RegExp(r'UTR[\s:]+([A-Z0-9]{8,30})', caseSensitive: false),
    ];

    for (final RegExp pattern in upiPatterns) {
      final RegExpMatch? match = pattern.firstMatch(compactSms);
      if (match == null) {
        continue;
      }

      upiRef = (match.group(1) ?? '').trim();
      if (upiRef.contains('-')) {
        upiRef = upiRef.split('-').first;
      }
      upiRef = upiRef.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      if (upiRef.isNotEmpty) {
        break;
      }
    }

    // ignore: avoid_print
    print('SMS PARSED: amount=₹$amount buyer=$buyerName upiRef=$upiRef');

    return ParsedPaymentSms(
      amount: amount,
      buyerName: buyerName,
      upiReference: upiRef,
      rawSms: smsBody,
      receivedAt: DateTime.now(),
    );
  }
}
