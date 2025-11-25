import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/user/wallet_service.dart';
import '../../../../utils/user/dialog_utils.dart';
import '../../../../utils/user/button_styles.dart';

/// Dialog for adding credits to wallet
/// Shows credit packages and handles top-up checkout
class AddCreditsDialog extends StatelessWidget {
  final WalletService walletService;
  final VoidCallback? onTopUpStarted;

  const AddCreditsDialog({
    super.key,
    required this.walletService,
    this.onTopUpStarted,
  });

  /// Shows the add credits dialog
  static Future<void> show({
    required BuildContext context,
    required WalletService walletService,
    VoidCallback? onTopUpStarted,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AddCreditsDialog(
        walletService: walletService,
        onTopUpStarted: onTopUpStarted,
      ),
    );
  }

  Future<void> _startTopUp(BuildContext context, {required int credits, required int amountInCents}) async {
    // Check for pending payments first
    final hasPending = await walletService.hasPendingPayments();
    if (hasPending) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'You have a pending payment. Please complete it before starting a new top-up.',
      );
      return;
    }

    try {
      final url = await walletService.createTopUpCheckoutSession(
        credits: credits,
        amountInCents: amountInCents,
      );
      if (!context.mounted) return;
      
      Navigator.pop(context); // Close dialog first
      onTopUpStarted?.call();
      
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Could not open checkout',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Top-up failed: $e',
      );
    }
  }

  Widget _buildCreditOption(BuildContext context, {
    required int credits,
    required String price,
    required String description,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? const Color(0xFF00C8A0) : Colors.grey[300]!,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF00C8A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                credits.toString(),
                style: const TextStyle(
                  color: Color(0xFF00C8A0),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                'credits',
                style: TextStyle(
                  color: const Color(0xFF00C8A0),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            if (isPopular) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8A0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF00C8A0),
        ),
        onTap: () {
          _startTopUp(
            context,
            credits: credits,
            amountInCents: credits == 100 ? 999 : credits == 500 ? 4499 : 7999,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF00C8A0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_score,
                size: 30,
                color: Color(0xFF00C8A0),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Credits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a credit package',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _buildCreditOption(
              context,
              credits: 100,
              price: '\$9.99',
              description: 'Perfect for trying out the platform',
            ),
            const SizedBox(height: 12),
            _buildCreditOption(
              context,
              credits: 500,
              price: '\$44.99',
              description: 'Best value - 10% discount',
              isPopular: true,
            ),
            const SizedBox(height: 12),
            _buildCreditOption(
              context,
              credits: 1000,
              price: '\$79.99',
              description: 'Maximum savings - 20% discount',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ButtonStyles.primaryOutlined(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

