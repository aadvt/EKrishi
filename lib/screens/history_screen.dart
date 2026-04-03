import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/transaction_record.dart';
import '../services/farmer_service.dart';
import '../services/transaction_history_service.dart';
import '../utils/language_provider.dart';
import '../widgets/error_widget.dart';
import 'settings_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TransactionRecord> _transactions = <TransactionRecord>[];
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasPhone = false;

  @override
  void initState() {
    super.initState();
    _hasPhone = FarmerService().hasPhoneNumber;
    if (_hasPhone) {
      _loadTransactions();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadTransactions() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final List<TransactionRecord> txns = await TransactionHistoryService()
          .getHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = txns;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const SettingsScreen(),
      ),
    );

    final bool hasPhoneNow = FarmerService().hasPhoneNumber;
    if (!mounted) {
      return;
    }

    setState(() {
      _hasPhone = hasPhoneNow;
    });

    if (hasPhoneNow) {
      await _loadTransactions();
    }
  }

  void _showDetailBottomSheet(TransactionRecord txn, bool isKn) {
    final String channelLabel = _channelLabel(txn, isKn);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  txn.commodityName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _detailRow(
                  isKn ? 'ಮೊತ್ತ' : 'Amount',
                  '₹${txn.totalAmount.toStringAsFixed(0)}',
                ),
                _detailRow(isKn ? 'ಖರೀದಿದಾರ' : 'Buyer', txn.buyerName),
                _detailRow(isKn ? 'ಚಾನೆಲ್' : 'Channel', channelLabel),
                _detailRow(
                  isKn ? 'ಜಿಲ್ಲೆ' : 'District',
                  txn.district.isEmpty ? '-' : txn.district,
                ),
                _detailRow(
                  isKn ? 'ದಿನಾಂಕ' : 'Date',
                  DateFormat('dd MMM yyyy, HH:mm').format(txn.createdAt),
                ),
                if ((txn.upiTxid ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            isKn ? 'ಯುಪಿಐ ಉಲ್ಲೇಖ' : 'UPI Ref',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            txn.upiTxid!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (txn.gnnFlagged)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFE63946),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isKn
                                ? 'ಈ ವಹಿವಾಟು ಅನುಮಾನಾಸ್ಪದ ಬೆಲೆಗಾಗಿ ಗುರುತಿಸಲಾಗಿದೆ.'
                                : 'This transaction is flagged for unusual pricing.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE63946),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanguageProvider lang = Provider.of<LanguageProvider>(context);
    final bool isKn = lang.isKannada;

    final double totalRevenue = _transactions.fold<double>(
      0,
      (double sum, TransactionRecord txn) => sum + txn.totalAmount,
    );
    final int smsCount = _transactions
        .where((TransactionRecord t) => t.isSmsSale)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isKn ? 'ವಹಿವಾಟುಗಳು' : 'Transactions'),
        actions: <Widget>[
          IconButton(
            onPressed: _hasPhone ? _loadTransactions : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(isKn, totalRevenue, smsCount),
    );
  }

  Widget _buildBody(bool isKn, double totalRevenue, int smsCount) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: AppColors.accentGreen),
            const SizedBox(height: 12),
            Text(
              isKn
                  ? 'ವಹಿವಾಟುಗಳನ್ನು ಲೋಡ್ ಮಾಡಲಾಗುತ್ತಿದೆ...'
                  : 'Loading transactions...',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasPhone) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.phone_rounded,
                  size: 64,
                  color: Color(0xFFE8E8E8),
                ),
                const SizedBox(height: 16),
                Text(
                  isKn ? 'ಫೋನ್ ಸಂಖ್ಯೆ ಹೊಂದಿಸಲಾಗಿಲ್ಲ' : 'No phone number set',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isKn
                      ? 'ನಿಮ್ಮ ವಹಿವಾಟು ಇತಿಹಾಸವನ್ನು ನೋಡಲು Settings ನಲ್ಲಿ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ಸೇರಿಸಿ'
                      : 'Add your phone number in Settings to see your transaction history',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _openSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isKn ? 'ಸೆಟ್ಟಿಂಗ್‌ಗಳಿಗೆ ಹೋಗಿ' : 'Go to Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return AppErrorWidget(
        message: isKn
            ? 'ವಹಿವಾಟುಗಳನ್ನು ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ'
            : 'Could not load transactions',
        subtitle: isKn ? 'ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ' : 'Please try again',
        icon: Icons.cloud_off_rounded,
        onRetry: _loadTransactions,
      );
    }

    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: Color(0xFFE8E8E8),
                ),
                const SizedBox(height: 16),
                Text(
                  isKn ? 'ಇನ್ನೂ ವಹಿವಾಟುಗಳಿಲ್ಲ' : 'No transactions yet',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isKn
                      ? 'ಪೂರ್ಣಗೊಂಡ ಮಾರಾಟಗಳು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ'
                      : 'Completed sales will appear here',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        _SummaryCard(
          totalCount: _transactions.length,
          totalRevenue: totalRevenue,
          smsCount: smsCount,
          isKn: isKn,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            itemCount: _transactions.length,
            itemBuilder: (BuildContext context, int index) {
              final TransactionRecord txn = _transactions[index];
              return _TransactionCard(
                transaction: txn,
                isKn: isKn,
                onTap: () => _showDetailBottomSheet(txn, isKn),
              );
            },
          ),
        ),
      ],
    );
  }

  String _channelLabel(TransactionRecord txn, bool isKn) {
    if (txn.isMarketplace) {
      return isKn ? 'ಮಾರ್ಕೆಟ್‌ಪ್ಲೇಸ್' : 'Marketplace';
    }
    if (txn.isSmsSale) {
      return isKn ? 'SMS ಮೂಲಕ' : 'Via SMS';
    }
    return txn.saleChannel;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalCount;
  final double totalRevenue;
  final int smsCount;
  final bool isKn;

  const _SummaryCard({
    required this.totalCount,
    required this.totalRevenue,
    required this.smsCount,
    required this.isKn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatColumn(
              value: '$totalCount',
              label: isKn ? 'ಒಟ್ಟು ಮಾರಾಟ' : 'Total Sales',
            ),
          ),
          const SizedBox(
            height: 36,
            child: VerticalDivider(width: 12, color: AppColors.border),
          ),
          Expanded(
            child: _StatColumn(
              value: '₹${totalRevenue.toStringAsFixed(0)}',
              label: isKn ? 'ಒಟ್ಟು ಆದಾಯ' : 'Total Revenue',
            ),
          ),
          const SizedBox(
            height: 36,
            child: VerticalDivider(width: 12, color: AppColors.border),
          ),
          Expanded(
            child: _StatColumn(
              value: '$smsCount',
              label: isKn ? 'SMS ಮೂಲಕ' : 'Via SMS',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionRecord transaction;
  final bool isKn;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.isKn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String dateText = DateFormat(
      'dd MMM · HH:mm',
    ).format(transaction.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        transaction.commodityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₹${transaction.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ChannelBadge(transaction: transaction, isKn: isKn),
                    if (transaction.gnnFlagged)
                      const _SimpleBadge(
                        label: 'Flagged',
                        icon: Icons.warning_amber_rounded,
                        background: Color(0xFFFFEBEE),
                        foreground: Color(0xFFE63946),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.person_rounded,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        transaction.buyerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelBadge extends StatelessWidget {
  final TransactionRecord transaction;
  final bool isKn;

  const _ChannelBadge({required this.transaction, required this.isKn});

  @override
  Widget build(BuildContext context) {
    if (transaction.isMarketplace) {
      return _SimpleBadge(
        label: isKn ? 'ಮಾರ್ಕೆಟ್‌ಪ್ಲೇಸ್' : 'Marketplace',
        icon: Icons.storefront_rounded,
        background: const Color(0xFFD8F3DC),
        foreground: const Color(0xFF2D6A4F),
      );
    }

    if (transaction.isSmsSale) {
      return _SimpleBadge(
        label: isKn ? 'SMS ಮೂಲಕ' : 'Via SMS',
        icon: Icons.sms_rounded,
        background: const Color(0xFFFFF3E0),
        foreground: const Color(0xFFF4A261),
      );
    }

    return _SimpleBadge(
      label: transaction.saleChannel,
      icon: Icons.swap_horiz_rounded,
      background: AppColors.surfaceAlt,
      foreground: AppColors.textSecondary,
    );
  }
}

class _SimpleBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _SimpleBadge({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
