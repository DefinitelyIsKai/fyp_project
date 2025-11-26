import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/user/wallet_service.dart';
import '../../../../utils/user/dialog_utils.dart';
import '../../../../utils/user/button_styles.dart';

/// Dialog for adding credits to wallet
/// Shows credit packages and handles top-up checkout
class AddCreditsDialog extends StatefulWidget {
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

  @override
  State<AddCreditsDialog> createState() => _AddCreditsDialogState();
}

class _AddCreditsDialogState extends State<AddCreditsDialog> {
  bool _isLoading = false;

  Future<void> _startTopUp({required int credits, required int amountInCents}) async {
    if (_isLoading) return; // Prevent multiple clicks
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check for pending payments first
      final hasPending = await widget.walletService.hasPendingPayments();
      if (hasPending) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        DialogUtils.showWarningMessage(
          context: context,
          message: 'You have a pending payment. Please complete it before starting a new top-up.',
        );
        return;
      }

      final url = await widget.walletService.createTopUpCheckoutSession(
        credits: credits,
        amountInCents: amountInCents,
      );
      if (!mounted) return;
      
      Navigator.pop(context); // Close dialog first
      widget.onTopUpStarted?.call();
      
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Could not open checkout',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Top-up failed: $e',
      );
    }
  }

  Widget _buildCreditOption({
    required int credits,
    required String price,
    required String description,
  }) {
    return Opacity(
      opacity: _isLoading ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
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
          title: Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          trailing: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00C8A0),
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF00C8A0),
                ),
          onTap: _isLoading
              ? null
              : () {
                  _startTopUp(
                    credits: credits,
                    amountInCents: credits == 100 ? 999 : credits == 500 ? 4499 : 7999,
                  );
                },
        ),
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
              credits: 100,
              price: 'RM9.99',
              description: 'Perfect for trying out the platform',
            ),
            const SizedBox(height: 12),
            _buildCreditOption(
              credits: 500,
              price: 'RM44.99',
              description: 'Best value - 10% discount',
            ),
            const SizedBox(height: 12),
            _buildCreditOption(
              credits: 1000,
              price: 'RM79.99',
              description: 'Maximum savings - 20% discount',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
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

