import 'package:flutter/material.dart';

class AddCreditDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final double currentBalance;
  final Future<void> Function(String userId, double amount, String reason, String userName) onAddCredit;

  const AddCreditDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.currentBalance,
    required this.onAddCredit,
  });

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required String userName,
    required double currentBalance,
    required Future<void> Function(String userId, double amount, String reason, String userName) onAddCredit,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCreditDialog(
        userId: userId,
        userName: userName,
        currentBalance: currentBalance,
        onAddCredit: onAddCredit,
      ),
    );
  }

  @override
  State<AddCreditDialog> createState() => _AddCreditDialogState();
}

class _AddCreditDialogState extends State<AddCreditDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleAddCredit() async {
    
    _amountError = null;
    setState(() {});

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() {
        _amountError = 'Please enter an amount';
      });
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid amount greater than 0';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Navigator.pop(context);

    await widget.onAddCredit(
      widget.userId,
      amount,
      _reasonController.text.trim(),
      widget.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Credit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.userName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Balance:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                          Text(
                            '${widget.currentBalance.toStringAsFixed(0)} credits',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    TextField(
                      controller: _amountController,
                      enabled: !_isLoading,
                      onChanged: (value) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount (credits) *',
                        hintText: 'Enter amount to add',
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: _amountError != null ? Colors.red : Colors.green,
                        ),
                        errorText: _amountError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _amountError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _amountError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _amountError != null ? Colors.red : Colors.green,
                            width: 2,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: _amountError != null ? Colors.red[50] : Colors.grey[50],
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _reasonController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Reason (Optional)',
                        hintText: 'Enter reason for adding credit',
                        prefixIcon: const Icon(Icons.note, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.green, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAddCredit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Add Credit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
  }
}

class DeductCreditDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final double currentBalance;
  final double heldCredits;
  final double availableBalance;
  final Future<void> Function(String userId, double amount, String reason) onDeductCredit;

  const DeductCreditDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.currentBalance,
    required this.heldCredits,
    required this.availableBalance,
    required this.onDeductCredit,
  });

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required String userName,
    required double currentBalance,
    required double heldCredits,
    required double availableBalance,
    required Future<void> Function(String userId, double amount, String reason) onDeductCredit,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeductCreditDialog(
        userId: userId,
        userName: userName,
        currentBalance: currentBalance,
        heldCredits: heldCredits,
        availableBalance: availableBalance,
        onDeductCredit: onDeductCredit,
      ),
    );
  }

  @override
  State<DeductCreditDialog> createState() => _DeductCreditDialogState();
}

class _DeductCreditDialogState extends State<DeductCreditDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _amountError;
  String? _reasonError;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleDeductCredit() async {
    
    _amountError = null;
    _reasonError = null;
    setState(() {});

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() {
        _amountError = 'Please enter an amount';
      });
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid amount greater than 0';
      });
      return;
    }

    if (amount > widget.availableBalance) {
      setState(() {
        _amountError = 'Cant deduct more than available balance';
      });
      return;
    }

    final reasonText = _reasonController.text.trim();
    if (reasonText.isEmpty) {
      setState(() {
        _reasonError = 'Please enter a reason';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Navigator.pop(context);

    await widget.onDeductCredit(
      widget.userId,
      amount,
      reasonText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deduct Credit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.userName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Balance Information',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Balance:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${widget.currentBalance.toStringAsFixed(0)} credits',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                          if (widget.heldCredits > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Held Credits:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '${widget.heldCredits.toStringAsFixed(0)} credits',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Available Balance:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                              Text(
                                '${widget.availableBalance.toStringAsFixed(0)} credits',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: widget.availableBalance >= 0 ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.availableBalance < 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'User has negative available balance',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    TextField(
                      controller: _amountController,
                      enabled: !_isLoading,
                      onChanged: (value) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount (credits) *',
                        hintText: 'Enter amount to deduct',
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: _amountError != null ? Colors.red : Colors.red,
                        ),
                        errorText: _amountError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _amountError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _amountError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _amountError != null ? Colors.red : Colors.red,
                            width: 2,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: _amountError != null ? Colors.red[50] : Colors.grey[50],
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _reasonController,
                      enabled: !_isLoading,
                      onChanged: (value) {
                        if (_reasonError != null) {
                          setState(() => _reasonError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Reason (Required) *',
                        hintText: 'Enter reason for deducting credit',
                        prefixIcon: Icon(
                          Icons.note,
                          color: _reasonError != null ? Colors.red : Colors.red,
                        ),
                        errorText: _reasonError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _reasonError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _reasonError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _reasonError != null ? Colors.red : Colors.red,
                            width: 2,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: _reasonError != null ? Colors.red[50] : Colors.grey[50],
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleDeductCredit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_circle, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Deduct Credit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
  }
}
