import 'package:flutter/material.dart';
import '../../../services/user/wallet_service.dart';

class PaymentSuccessPage extends StatefulWidget {
  final String? sessionId;
  final String? uid;
  final int? credits;

  const PaymentSuccessPage({
    super.key,
    this.sessionId,
    this.uid,
    this.credits,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final WalletService _walletService = WalletService();
  bool _isProcessing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  Future<void> _processPayment() async {
    if (widget.sessionId == null || widget.credits == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Missing payment information';
      });
      return;
    }

    try {
      // Verify and credit the wallet in Firestore
      await _walletService.creditFromStripeSession(
        sessionId: widget.sessionId!,
        credits: widget.credits!,
      );
      
      // Give Firestore a moment to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Success'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Processing your payment...',
                  style: TextStyle(fontSize: 18),
                ),
              ] else if (_errorMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  'Payment Verification Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ] else ...[
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.credits != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${widget.credits} credits have been added to your wallet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

