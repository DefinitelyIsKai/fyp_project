import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import '../../../../services/admin/reward_service.dart';
import '../../../../services/user/notification_service.dart';
import '../../../../utils/admin/app_colors.dart';
import 'reward_preview_dialog.dart';

class RewardSystemDialog extends StatefulWidget {
  final RewardService rewardService;
  final NotificationService notificationService;

  const RewardSystemDialog({
    super.key,
    required this.rewardService,
    required this.notificationService,
  });

  static Future<void> show({
    required BuildContext context,
    required RewardService rewardService,
    required NotificationService notificationService,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RewardSystemDialog(
        rewardService: rewardService,
        notificationService: notificationService,
      ),
    );
  }

  @override
  State<RewardSystemDialog> createState() => _RewardSystemDialogState();
}

class _RewardSystemDialogState extends State<RewardSystemDialog> {
  final TextEditingController _minRatingController = TextEditingController(text: '4.0');
  final TextEditingController _minTasksController = TextEditingController(text: '3');
  final TextEditingController _rewardAmountController = TextEditingController(text: '100');
  bool _isCalculating = false;
  int _selectedTab = 0; 
  String? _ratingError;
  String? _tasksError;
  String? _amountError;

  @override
  void dispose() {
    _minRatingController.dispose();
    _minTasksController.dispose();
    _rewardAmountController.dispose();
    super.dispose();
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
                color: Colors.orange[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isCalculating ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Reward System',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTab == 0 ? 'Calculate & Distribute' : 'Reward History',
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
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'Calculate Rewards',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Reward History',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: _selectedTab == 0 ? _buildCalculateTab() : _buildHistoryTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Reward Criteria',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Users will be rewarded if they meet both criteria:\n'
                  '• Average rating ≥ minimum rating\n'
                  '• Approved applications for completed posts ≥ minimum posts',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Reward Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _minRatingController,
            decoration: InputDecoration(
              labelText: 'Minimum Average Rating',
              hintText: 'e.g., 4.0',
              prefixIcon: Icon(Icons.star, color: _ratingError != null ? Colors.red : Colors.orange),
              errorText: _ratingError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _ratingError != null ? Colors.red : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _ratingError != null ? Colors.red : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _ratingError != null ? Colors.red : AppColors.primaryDark,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: _ratingError != null ? Colors.red[50] : Colors.grey[50],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              if (_ratingError != null) {
                setState(() => _ratingError = null);
              }
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _minTasksController,
            decoration: InputDecoration(
              labelText: 'Minimum Completed Posts',
              hintText: 'e.g., 3',
              prefixIcon: Icon(Icons.task_alt, color: _tasksError != null ? Colors.red : Colors.green),
              errorText: _tasksError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _tasksError != null ? Colors.red : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _tasksError != null ? Colors.red : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _tasksError != null ? Colors.red : AppColors.primaryDark,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: _tasksError != null ? Colors.red[50] : Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              if (_tasksError != null) {
                setState(() => _tasksError = null);
              }
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _rewardAmountController,
            decoration: InputDecoration(
              labelText: 'Reward Amount (Credits)',
              hintText: 'e.g., 100',
              prefixIcon: Icon(Icons.account_balance_wallet, color: _amountError != null ? Colors.red : Colors.purple),
              errorText: _amountError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _amountError != null ? Colors.red : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _amountError != null ? Colors.red : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _amountError != null ? Colors.red : AppColors.primaryDark,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: _amountError != null ? Colors.red[50] : Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              if (_amountError != null) {
                setState(() => _amountError = null);
              }
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCalculating ? null : _calculateRewards,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isCalculating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Calculating...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Calculate & Distribute Rewards',
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
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.rewardService.streamRewardHistory(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading history: ${snapshot.error}',
              style: TextStyle(color: Colors.red[700]),
            ),
          );
        }

        final rewards = snapshot.data ?? [];

        if (rewards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No reward history yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final distribution = rewards[index];
            final distributionDate = distribution['distributionDate'] as DateTime?;
            final month = distribution['month'] as String? ?? 'Unknown';
            final successCount = distribution['successCount'] as int? ?? 0;
            final totalAmount = distribution['totalAmount'] as int? ?? 0;
            final rewardAmount = distribution['rewardAmount'] as int? ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.card_giftcard, color: Colors.orange[700], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Month: $month',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (distributionDate != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      DateFormat('dd MMM yyyy').format(distributionDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$totalAmount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            Text(
                              'total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDistributionStat(
                          icon: Icons.people,
                          label: 'Users',
                          value: successCount.toString(),
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildDistributionStat(
                          icon: Icons.account_balance_wallet,
                          label: 'Per User',
                          value: '$rewardAmount',
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDistributionStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _calculateRewards() async {
    
    setState(() {
      _ratingError = null;
      _tasksError = null;
      _amountError = null;
    });

    final minRating = double.tryParse(_minRatingController.text);
    final minTasks = int.tryParse(_minTasksController.text);
    final rewardAmount = int.tryParse(_rewardAmountController.text);

    bool hasError = false;

    if (minRating == null || minRating <= 0 || minRating > 5) {
      setState(() {
        _ratingError = 'Please enter a valid rating';
      });
      hasError = true;
    }

    if (minTasks == null || minTasks <= 0) {
      setState(() {
        _tasksError = 'Please enter a valid number of posts';
      });
      hasError = true;
    }

    if (rewardAmount == null || rewardAmount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid reward amount';
      });
      hasError = true;
    }

    if (hasError) {
      return;
    }

    final validMinRating = minRating!;
    final validMinTasks = minTasks!;
    final validRewardAmount = rewardAmount!;

    setState(() => _isCalculating = true);
    
    if (!mounted) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Calculating rewards...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    await Future.microtask(() {});
    await Future.delayed(Duration.zero);
    await Future.microtask(() {});
    
    if (!mounted) {
      Navigator.of(context).pop(); 
      return;
    }
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) {
      Navigator.of(context).pop(); 
      return;
    }

    try {
      
      final previewResult = await widget.rewardService.previewEligibleUsers(
        minRating: validMinRating,
        minCompletedTasks: validMinTasks,
        rewardAmount: validRewardAmount,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) {
        Navigator.of(context).pop(); 
        return;
      }

      await Future.delayed(const Duration(milliseconds: 100));
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      setState(() => _isCalculating = false);
      
      await Future.delayed(Duration.zero);
      await Future.microtask(() {});

      if (previewResult['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${previewResult['error'] ?? 'Failed to calculate preview'}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final eligibleUsers = previewResult['eligibleUsers'] as List<dynamic>? ?? [];
      final totalEligible = previewResult['totalEligible'] as int? ?? 0;
      final month = previewResult['month'] as String? ?? 'Unknown';
      final completedPostsCount = previewResult['completedPostsCount'] as int? ?? 0;

      await Future.delayed(Duration.zero);
      await Future.microtask(() {});
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 100));
      
      await Future.microtask(() {});
      await Future.delayed(const Duration(milliseconds: 50));
      
      final confirmed = await RewardPreviewDialog.show(
        context: context,
        month: month,
        completedPostsCount: completedPostsCount,
        totalEligible: totalEligible,
        minRating: validMinRating,
        minTasks: validMinTasks,
        rewardAmount: validRewardAmount,
        eligibleUsers: eligibleUsers,
      );
      
      if (confirmed != true) {
        return;
      }

      setState(() => _isCalculating = true);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Distributing rewards...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait, this may take a moment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));
      await Future.microtask(() {});
      await SchedulerBinding.instance.endOfFrame;

      final result = await widget.rewardService.calculateMonthlyRewards(
        minRating: validMinRating,
        minCompletedTasks: validMinTasks,
        rewardAmount: validRewardAmount,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        
        Navigator.of(context).pop();
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['success'] == true
                    ? 'Successfully distributed rewards to ${result['successCount']} users!'
                    : 'Error: ${result['error']}',
              ),
              backgroundColor: result['success'] == true ? Colors.green : Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        try {
          Navigator.of(context).pop(); 
        } catch (_) {
          
        }
        setState(() => _isCalculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      
      if (mounted) {
        try {
          Navigator.of(context).pop(); 
        } catch (_) {
          
        }
        setState(() => _isCalculating = false);
      }
    }
  }

}
