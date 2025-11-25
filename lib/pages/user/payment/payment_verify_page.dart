import 'package:flutter/material.dart';
import '../../../services/user/wallet_service.dart';

/// This page can be opened manually or via deep link to verify and credit a payment
class PaymentVerifyPage extends StatefulWidget {
  final String? sessionId;
  final String? credits;

  const PaymentVerifyPage({
    super.key,
    this.sessionId,
    this.credits,
  });

  @override
  State<PaymentVerifyPage> createState() => _PaymentVerifyPageState();
}

class _PaymentVerifyPageState extends State<PaymentVerifyPage> {
  final WalletService _walletService = WalletService();
  bool _isProcessing = true;
  String? _errorMessage;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null && widget.credits != null) {
      _verifyAndCredit();
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Missing payment information';
      });
    }
  }

  Future<void> _verifyAndCredit() async {
    try {
      final credits = int.parse(widget.credits!);
      await _walletService.creditFromStripeSession(
        sessionId: widget.sessionId!,
        credits: credits,
      );
      
      setState(() {
        _isProcessing = false;
        _success = true;
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
        title: const Text('Verify Payment'),
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
                const Text('Verifying payment...'),
              ] else if (_errorMessage != null) ...[
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 24),
                Text(
                  'Verification Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                ),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ] else if (_success) ...[
                Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                const SizedBox(height: 24),
                const Text(
                  'Payment Verified!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (widget.credits != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${widget.credits} credits have been added',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}




