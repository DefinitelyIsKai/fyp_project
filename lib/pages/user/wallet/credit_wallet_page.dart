import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/user/wallet_service.dart';
import '../../../models/user/wallet.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/date_utils.dart' as DateUtilsHelper;
import '../../../utils/user/timestamp_utils.dart';
import '../../../widgets/user/loading_indicator.dart';
import '../../../widgets/user/empty_state.dart';
import '../../../widgets/admin/dialogs/user_dialogs/add_credits_dialog.dart';
import '../../../widgets/user/pagination_dots_widget.dart';

class CreditWalletPage extends StatefulWidget {
  const CreditWalletPage({super.key});

  @override
  State<CreditWalletPage> createState() => _CreditWalletPageState();
}

//parsing
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class _CreditWalletPageState extends State<CreditWalletPage> with WidgetsBindingObserver {
  final WalletService _walletService = WalletService();
  WalletTxnType? _selectedFilter;
  List<Map<String, dynamic>> _pendingPayments = [];
  
  //agination
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  List<List<_UnifiedTransaction>> _pages = [];
  List<List<_UnifiedTransaction>> _filteredPages = []; //cache
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<_UnifiedTransaction> _allTransactions = [];
  WalletTxnType? _lastFilter; 
  static const int _itemsPerPage = 10;
  static const int _initialStreamLimit = 50; //load50
  
  // Cache the stream to avoid recreating it on every rebuild
  Stream<List<_UnifiedTransaction>>? _cachedUnifiedStream;
  
  // Scroll controller for balance card shrink effect
  final ScrollController _scrollController = ScrollController();
  bool _isCardShrunk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingPayments();
      _refreshPendingPayments();
    });
    
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _scrollController.dispose();
    _currentPageNotifier.dispose();
    _cachedUnifiedStream = null; // Clear cached stream
    super.dispose();
  }
  
  void _toggleCardShrink() {
    setState(() {
      _isCardShrunk = !_isCardShrunk;
    });
  }

  //transactions cancelled payments 
  Stream<List<_UnifiedTransaction>> _getUnifiedTransactionsStream() {
    if (_cachedUnifiedStream != null) {
      return _cachedUnifiedStream!;
    }
    
    final controller = StreamController<List<_UnifiedTransaction>>();
    final transactionsStream = _walletService.streamTransactions(limit: _initialStreamLimit);
    final cancelledPaymentsStream = _walletService.streamCancelledPayments();
    
    List<WalletTransaction>? latestTransactions;
    List<Map<String, dynamic>>? latestCancelledPayments;
    
    void emitIfReady() {
      if (latestTransactions != null && latestCancelledPayments != null) {
        final unified = <_UnifiedTransaction>[];
        
        for (final txn in latestTransactions!) {
          unified.add(_UnifiedTransaction(
            id: txn.id,
            type: txn.type,
            amount: txn.amount,
            description: txn.description,
            createdAt: txn.createdAt,
            isCancelled: false,
          ));
        }

        for (final payment in latestCancelledPayments!) {
          final credits = _parseInt(payment['credits']);
          final createdAt = TimestampUtils.parseTimestamp(payment['createdAt']);
          unified.add(_UnifiedTransaction(
            id: payment['id'] as String? ?? '',
            type: WalletTxnType.credit,
            amount: credits,
            description: 'Top-up payment (Cancelled)',
            createdAt: createdAt,
            isCancelled: true,
          ));
        }

        //date sorting
        unified.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!controller.isClosed) {
          controller.add(unified);
        }
      }
    }
    
    final transactionsSubscription = transactionsStream.listen(
      (transactions) {
        latestTransactions = transactions;
        emitIfReady();
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );
    
    final cancelledSubscription = cancelledPaymentsStream.listen(
      (payments) {
        latestCancelledPayments = payments;
        emitIfReady();
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );
    
    //clean
    controller.onCancel = () {
      transactionsSubscription.cancel();
      cancelledSubscription.cancel();
      _cachedUnifiedStream = null;
    };
    
    _cachedUnifiedStream = controller.stream;
    return _cachedUnifiedStream!;
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMore || _allTransactions.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final lastTransaction = _allTransactions.last;
      final moreTransactions = await _walletService.loadMoreTransactions(
        lastTransactionTime: lastTransaction.createdAt,
        lastTransactionId: lastTransaction.isCancelled ? null : lastTransaction.id,
        limit: _itemsPerPage,
      );

      final unified = <_UnifiedTransaction>[];
      
      for (final txn in moreTransactions) {
        unified.add(_UnifiedTransaction(
          id: txn.id,
          type: txn.type,
          amount: txn.amount,
          description: txn.description,
          createdAt: txn.createdAt,
          isCancelled: false,
        ));
      }

      //cancelled payments
      final allCancelled = await _walletService.loadInitialCancelledPayments(limit: 1000);
      final existingIds = _allTransactions
          .where((t) => t.isCancelled)
          .map((t) => t.id)
          .toSet();
      
      for (final payment in allCancelled) {
        if (existingIds.contains(payment['id'])) continue;
        
        final credits = payment['credits'] as int? ?? 0;
        final createdAt = TimestampUtils.parseTimestamp(payment['createdAt']);
      
        if (createdAt.isBefore(lastTransaction.createdAt) ||
            (createdAt.isAtSameMomentAs(lastTransaction.createdAt) &&
             payment['id'] as String != lastTransaction.id)) {
          unified.add(_UnifiedTransaction(
            id: payment['id'] as String? ?? '',
            type: WalletTxnType.credit,
            amount: credits,
            description: 'Top-up payment (Cancelled)',
            createdAt: createdAt,
            isCancelled: true,
          ));
        }
      }

      if (!mounted) return;

      if (!mounted) return;

      if (unified.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      //new transactions and re-sort
      _allTransactions.addAll(unified);
      _allTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      //pages
      final pages = <List<_UnifiedTransaction>>[];
      for (int i = 0; i < _allTransactions.length; i += _itemsPerPage) {
        final end = (i + _itemsPerPage < _allTransactions.length) 
            ? i + _itemsPerPage 
            : _allTransactions.length;
        pages.add(_allTransactions.sublist(i, end));
      }

      //recalculate filtered new data
      final filteredTransactions = _selectedFilter == null
          ? _allTransactions
          : _allTransactions.where((t) {
              if (_selectedFilter == WalletTxnType.credit) {
                return t.type == WalletTxnType.credit && !t.isCancelled;
              }
              return t.type == _selectedFilter;
            }).toList();

      final filteredPages = <List<_UnifiedTransaction>>[];
      for (int i = 0; i < filteredTransactions.length; i += _itemsPerPage) {
        final end = (i + _itemsPerPage < filteredTransactions.length) 
            ? i + _itemsPerPage 
            : filteredTransactions.length;
        filteredPages.add(filteredTransactions.sublist(i, end));
      }
      if (filteredPages.isEmpty && filteredTransactions.isNotEmpty) {
        filteredPages.add(filteredTransactions);
      }

      setState(() {
        _pages = pages;
        _filteredPages = filteredPages;
        if (unified.length < _itemsPerPage) {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading more transactions: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayments();
    }
  }

  Future<void> _checkPendingPayments() async {
    if (!mounted) return;
    try {
      await _walletService.checkAndCreditPendingPayments();
      //refresh pending payment
      await _refreshPendingPayments();
    } catch (e) {
      print('Error checking pending payments: $e');
    }
  }

  Future<void> _refreshPendingPayments() async {
    try {
      //get pending payments 
      final pendingPayments = await _walletService.getPendingPayments();
      if (mounted) {
        setState(() {
          _pendingPayments = pendingPayments;
        });
      }
    } catch (e) {
      print('Error refreshing pending payments: $e');
    }
  }


  void _showAddCreditDialog() {
    AddCreditsDialog.show(
      context: context,
      walletService: _walletService,
      onTopUpStarted: () {
        _refreshPendingPayments();
      },
    );
  }


  Future<void> _openPendingPayment(String checkoutUrl) async {
    try {
      final url = Uri.parse(checkoutUrl);
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Could not open payment page',
        );
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to open payment: $e',
      );
    }
  }

  Future<void> _completePendingPayment(String sessionId, String paymentId, {String checkoutUrl = ''}) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF00C8A0),
        ),
      ),
    );

    try {
      await _walletService.completePendingPayment(sessionId: sessionId);
      
      if (!mounted) return;
      
      //close 
      Navigator.of(context).pop();
      
      // Refresh pending payments
      await _refreshPendingPayments();
      
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Payment completed successfully! Credits have been added to your wallet.',
      );
    } catch (e) {
      if (!mounted) return;
    
      Navigator.of(context).pop();
      
      if (e.toString().contains('PAYMENT_NOT_COMPLETED')) {
        if (checkoutUrl.isNotEmpty) {
          final shouldOpen = await DialogUtils.showConfirmationDialog(
            context: context,
            title: 'Payment Not Completed',
            message: 'The payment has not been completed yet. Would you like to open the payment page?',
            icon: Icons.payment,
            confirmText: 'Open Payment Page',
            cancelText: 'Cancel',
            isDestructive: false,
          );
          
          if (shouldOpen == true && mounted) {
            await _openPendingPayment(checkoutUrl);
          }
        } else {
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Payment not completed yet. Please complete the payment first.',
          );
        }
        return;
      }
      
      String errorMessage = 'Failed to complete payment';
      
      if (e.toString().contains('PAYMENT_ALREADY_PROCESSED')) {
        errorMessage = 'This payment has already been processed. Please refresh the page.';
        await _refreshPendingPayments();
      } else if (e.toString().contains('PAYMENT_ALREADY_PROCESSING')) {
        errorMessage = 'Payment is being processed. Please wait a moment and refresh.';
      } else if (e.toString().contains('Payment not found')) {
        errorMessage = 'Payment not found. It may have already been processed.';
        await _refreshPendingPayments();
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      DialogUtils.showWarningMessage(
        context: context,
        message: errorMessage,
      );
    }
  }

  Future<void> _cancelPendingPayment(String sessionId, String paymentId) async {
    if (!mounted) return;
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Cancel Payment?',
      message: 'Are you sure you want to cancel this pending payment? You can start a new top-up after cancelling.',
      icon: Icons.cancel_outlined,
      confirmText: 'Yes, Cancel',
      cancelText: 'No',
      isDestructive: true,
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF00C8A0),
        ),
      ),
    );

    try {
      await _walletService.cancelPendingPayment(sessionId);
      
      if (!mounted) return;
      
      Navigator.of(context).pop();
      await _refreshPendingPayments();     
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Payment cancelled successfully',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to cancel payment: $e',
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              
            });
            await Future.delayed(const Duration(milliseconds: 100));
          },
          color: const Color(0xFF00C8A0),
        child: CustomScrollView(
          controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                //pending paym
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _walletService.streamPendingPayments(),
                  builder: (context, snap) {
              List<Map<String, dynamic>> pendingPayments = [];
              
              if (snap.hasData) {
                pendingPayments = snap.data ?? [];
                //cached data
                _pendingPayments = pendingPayments;
              } else if (snap.hasError) {
                print('Error loading pending payments from stream: ${snap.error}');
                pendingPayments = _pendingPayments;
              } else {
                pendingPayments = _pendingPayments;
              }
              
              print('Pending payments count in UI: ${pendingPayments.length}');
              if (pendingPayments.isNotEmpty) {
                print('Pending payments data: $pendingPayments');
              }
              
              if (pendingPayments.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pending_actions,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pending Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...pendingPayments.map((payment) {
                      final credits = _parseInt(payment['credits']);
                      final amount = _parseInt(payment['amount']);
                      final checkoutUrl = payment['checkoutUrl'] as String? ?? '';
                      final createdAt = TimestampUtils.parseTimestamp(payment['createdAt']);
                      final dateStr = DateUtilsHelper.DateUtils.formatRelativeDate(createdAt);
                      final amountDollars = (amount / 100).toStringAsFixed(2);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.shade300,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.payment,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '$credits credits - \$$amountDollars',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Started $dateStr',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 140,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _cancelPendingPayment(
                                    payment['sessionId'] as String? ?? '',
                                    payment['id'] as String? ?? '',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade400),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize: const Size(60, 32),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () => _completePendingPayment(
                                    payment['sessionId'] as String? ?? '',
                                    payment['id'] as String? ?? '',
                                    checkoutUrl: checkoutUrl,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize: const Size(70, 32),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Complete',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 4),
                    Text(
                      'Please complete your pending payment before starting a new top-up.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
                ),
                
                // Balance Card
                GestureDetector(
                  onTap: _toggleCardShrink,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.all(_isCardShrunk ? 8 : 16),
                    padding: EdgeInsets.all(_isCardShrunk ? 12 : 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00C8A0),
                          const Color(0xFF00C8A0).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(_isCardShrunk ? 12 : 20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C8A0).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isCardShrunk
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Balance',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  StreamBuilder<Wallet>(
                                    stream: _walletService.streamWallet(),
                                    builder: (context, snap) {
                                      if (snap.connectionState == ConnectionState.waiting) {
                                        return const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        );
                                      }
                                      
                                      if (snap.hasError) {
                                        return Text(
                                          '0',
                                          style: TextStyle(
                                            fontSize: 24,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      }
                                      
                                      final wallet = snap.data;
                                      final int balance = wallet?.balance ?? 0;
                                      final int heldCredits = wallet?.heldCredits ?? 0;
                                      final int availableBalance = balance - heldCredits;
                                      
                                      return Text(
                                        availableBalance.toString(),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _toggleCardShrink,
                                  icon: const Icon(
                                    Icons.expand,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: 'Expand',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: _walletService.streamPendingPayments(),
                                  builder: (context, snap) {
                                    final hasPending = (snap.data?.isNotEmpty ?? false);
                                    
                                    return IconButton(
                                      onPressed: hasPending ? null : _showAddCreditDialog,
                                      icon: Icon(
                                        hasPending ? Icons.block : Icons.add,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      tooltip: hasPending ? 'Complete Pending Payment First' : 'Add Credits',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<Wallet>(
                              stream: _walletService.streamWallet(),
                              builder: (context, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator(color: Colors.white);
                                }
                                
                                if (snap.hasError) {
                                  return const Text(
                                    '0',
                                    style: TextStyle(
                                      fontSize: 42,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                }
                                
                                final wallet = snap.data;
                                final int balance = wallet?.balance ?? 0;
                                final int heldCredits = wallet?.heldCredits ?? 0;
                                final int availableBalance = balance - heldCredits;
                                
                                return Column(
                                  children: [
                                    Text(
                                      availableBalance.toString(),
                                      style: const TextStyle(
                                        fontSize: 42,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (heldCredits > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '$heldCredits on hold',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Credits',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: StreamBuilder<List<Map<String, dynamic>>>(
                                    stream: _walletService.streamPendingPayments(),
                                    builder: (context, snap) {
                                      final hasPending = (snap.data?.isNotEmpty ?? false);
                                      
                                      return ElevatedButton(
                                        onPressed: hasPending ? null : _showAddCreditDialog,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: hasPending 
                                              ? Colors.grey.shade300 
                                              : Colors.white,
                                          foregroundColor: hasPending 
                                              ? Colors.grey.shade600 
                                              : const Color(0xFF00C8A0),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: hasPending ? 0 : 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              hasPending ? Icons.block : Icons.add,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              hasPending 
                                                  ? 'Complete Pending Payment First'
                                                  : 'Add Credits',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _toggleCardShrink,
                                  icon: const Icon(
                                    Icons.unfold_less,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  tooltip: 'Shrink',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
                ),

                //filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterChip('All', _selectedFilter == null),
                          _buildFilterChip('Added', _selectedFilter == WalletTxnType.credit),
                          _buildFilterChip('Spent', _selectedFilter == WalletTxnType.debit),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          //trans
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                //available height dynamic screen size
                final mediaQuery = MediaQuery.of(context);
                final screenHeight = mediaQuery.size.height;
                final screenWidth = mediaQuery.size.width;
                final isLandscape = screenWidth > screenHeight;
                final padding = mediaQuery.padding;
                
                final cardHeight = _isCardShrunk ? 200 : 400;
                final appBarHeight = 56; 
                final otherElementsHeight = 100; //margim
                final safeAreaHeight = padding.top + padding.bottom;
                
                //available height 
                final calculatedHeight = screenHeight - cardHeight - appBarHeight - otherElementsHeight - safeAreaHeight;
                
                //minimum height percentage minimum   
                final minHeight = isLandscape 
                    ? (screenHeight * 0.3).clamp(200.0, double.infinity)
                    : (screenHeight * 0.25).clamp(300.0, double.infinity);
                
                final finalHeight = calculatedHeight > minHeight 
                    ? calculatedHeight 
                    : minHeight;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: finalHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildTransactionsList(),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<_UnifiedTransaction>>(
      stream: _getUnifiedTransactionsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator.standard();
        }

        if (snap.hasError) {
          return Center(
            child: Text('Error loading transactions: ${snap.error}'),
          );
        }

        final allTransactions = snap.data ?? [];
        final pages = <List<_UnifiedTransaction>>[];
        for (int i = 0; i < allTransactions.length; i += _itemsPerPage) {
          final end = (i + _itemsPerPage < allTransactions.length) 
              ? i + _itemsPerPage 
              : allTransactions.length;
          pages.add(allTransactions.sublist(i, end));
        }
        if (pages.isEmpty && allTransactions.isNotEmpty) {
          pages.add(allTransactions);
        }

        final dataChanged = _allTransactions.length != allTransactions.length ||
            _pages.length != pages.length;
        final filterChanged = _lastFilter != _selectedFilter;
        
        if (dataChanged || filterChanged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final filteredTransactions = _selectedFilter == null
                  ? allTransactions
                  : allTransactions.where((t) {
                      if (_selectedFilter == WalletTxnType.credit) {
                        return t.type == WalletTxnType.credit && !t.isCancelled;
                      }
                      return t.type == _selectedFilter;
                    }).toList();
              final filteredPages = <List<_UnifiedTransaction>>[];
              for (int i = 0; i < filteredTransactions.length; i += _itemsPerPage) {
                final end = (i + _itemsPerPage < filteredTransactions.length) 
                    ? i + _itemsPerPage 
                    : filteredTransactions.length;
                filteredPages.add(filteredTransactions.sublist(i, end));
              }
              if (filteredPages.isEmpty && filteredTransactions.isNotEmpty) {
                filteredPages.add(filteredTransactions);
              }

              setState(() {
                _allTransactions = allTransactions;
                _pages = pages;
                _filteredPages = filteredPages;
                _hasMore = allTransactions.length >= _initialStreamLimit;
                _lastFilter = _selectedFilter;
                //go first page when changed
                if (filterChanged) {
                  _currentPage = 0;
                  _currentPageNotifier.value = 0;
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                }
              });
            }
          });
        }

       
        final filteredPages = _filteredPages.isEmpty && _allTransactions.isNotEmpty
            ? _pages 
            : _filteredPages;

        if (filteredPages.isEmpty || filteredPages.every((page) => page.isEmpty)) {
          
          if (_hasMore && !_isLoadingMore && allTransactions.length >= _initialStreamLimit) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadMoreTransactions();
            });
          }
          return const EmptyState.noTransactions();
        }

      
        final shouldLoadMore = _currentPage >= filteredPages.length - 1 && 
                              _hasMore && 
                              !_isLoadingMore &&
                              allTransactions.length >= _initialStreamLimit;
        if (shouldLoadMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadMoreTransactions();
          });
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: filteredPages.length + (_isLoadingMore ? 1 : 0),
                onPageChanged: (index) {
                 
                  if (_currentPage != index) {
                    _currentPage = index;
                    _currentPageNotifier.value = index;
                  }
                 
                  if (index >= filteredPages.length - 2 && 
                      _hasMore && 
                      !_isLoadingMore &&
                      allTransactions.length >= _initialStreamLimit) {
                    _loadMoreTransactions();
                  }
                },
                itemBuilder: (context, pageIndex) {
              if (pageIndex == filteredPages.length) {
               
                return const LoadingIndicator.standard();
              }

              final pageTransactions = filteredPages[pageIndex];
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: pageTransactions.length,
                itemBuilder: (context, index) {
                  final t = pageTransactions[index];
                  final bool isCredit = t.type == WalletTxnType.credit;
                  final dateStr = DateUtilsHelper.DateUtils.formatRelativeDate(t.createdAt);
                  
                  //held credits 
                  final bool isOnHold = t.description.contains('(On Hold)');
                  final bool isReleased = t.description.contains('(Released)');
                  
                  //color determin
                  Color iconColor;
                  Color backgroundColor;
                  IconData iconData;
                  
                  if (t.isCancelled) {
                    iconColor = Colors.grey;
                    backgroundColor = Colors.grey.withOpacity(0.1);
                    iconData = Icons.cancel_outlined;
                  } else if (isOnHold) {
                    iconColor = Colors.orange.shade700;
                    backgroundColor = Colors.orange.withOpacity(0.1);
                    iconData = Icons.lock_clock;
                  } else if (isReleased) {
                    iconColor = const Color(0xFF00C8A0);
                    backgroundColor = const Color(0xFF00C8A0).withOpacity(0.1);
                    iconData = Icons.lock_open;
                  } else if (isCredit) {
                    iconColor = const Color(0xFF00C8A0);
                    backgroundColor = const Color(0xFF00C8A0).withOpacity(0.1);
                    iconData = Icons.add;
                  } else {
                    iconColor = Colors.red;
                    backgroundColor = Colors.red.withOpacity(0.1);
                    iconData = Icons.remove;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.isCancelled 
                            ? Colors.grey[300]! 
                            : (isOnHold ? Colors.orange.shade200 : Colors.grey[100]!),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Opacity(
                      opacity: t.isCancelled ? 0.6 : 1.0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.description,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: t.isCancelled 
                                      ? Colors.grey[700] 
                                      : Colors.black,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (t.isCancelled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Cancelled',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else if (isOnHold)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'On Hold',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isCredit || isReleased ? '+' : '-'}${t.amount}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: t.isCancelled
                                    ? Colors.grey
                                    : (isOnHold 
                                        ? Colors.orange.shade700
                                        : (isCredit || isReleased 
                                            ? const Color(0xFF00C8A0) 
                                            : Colors.red)),
                              ),
                            ),
                            Text(
                              'credits',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (filteredPages.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ValueListenableBuilder<int>(
              valueListenable: _currentPageNotifier,
              builder: (context, currentPage, _) {
                return PaginationDotsWidget(
                  totalPages: filteredPages.length,
                  currentPage: currentPage,
                );
              },
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: (selected) {
        if (!selected) return;
        setState(() {
          _selectedFilter = label == 'All' 
              ? null 
              : label == 'Added' 
                  ? WalletTxnType.credit 
                  : WalletTxnType.debit;
          //reset
          _currentPage = 0;
          _currentPageNotifier.value = 0;
        });
        //first page
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF00C8A0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _UnifiedTransaction {
  final String id;
  final WalletTxnType type;
  final int amount;
  final String description;
  final DateTime createdAt;
  final bool isCancelled;

  _UnifiedTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.isCancelled,
  });
}