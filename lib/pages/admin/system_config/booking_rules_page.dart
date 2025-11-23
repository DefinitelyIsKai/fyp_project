import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/booking_rule_model.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class BookingRulesPage extends StatefulWidget {
  const BookingRulesPage({super.key});

  @override
  State<BookingRulesPage> createState() => _BookingRulesPageState();
}

class _BookingRulesPageState extends State<BookingRulesPage> {
  final SystemConfigService _configService = SystemConfigService();
  List<BookingRuleModel> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final rules = await _configService.getBookingRules();
      if (rules.isEmpty) {
        await _configService.initializeDefaultBookingRules();
        final updatedRules = await _configService.getBookingRules();
        setState(() => _rules = updatedRules);
      } else {
        setState(() => _rules = rules);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rules: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRule(BookingRuleModel rule) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final updatedBy = authService.currentAdmin?.email;
      
      await _configService.updateBookingRule(rule, updatedBy: updatedBy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule updated successfully')),
        );
        _loadRules();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating rule: $e')),
        );
      }
    }
  }

  void _showRuleDetails(BookingRuleModel rule) {
    showDialog(
      context: context,
      builder: (context) => _BookingRuleDetailsDialog(rule: rule, onUpdate: _updateRule),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Rules Configuration'),
        backgroundColor: AppColors.cardGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRules,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No booking rules found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _configService.initializeDefaultBookingRules();
                          _loadRules();
                        },
                        child: const Text('Initialize Default Rules'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.green[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Configure booking and appointment rules. Set time windows, limits, and policies for user bookings.',
                                  style: TextStyle(color: Colors.green[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._rules.map((rule) => _buildRuleCard(rule)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRuleCard(BookingRuleModel rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRuleDetails(rule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rule.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: rule.isEnabled,
                    onChanged: (value) {
                      final updatedRule = rule.copyWith(isEnabled: value);
                      _updateRule(updatedRule);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Show key parameters preview
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rule.parameters.entries.take(3).map((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppColors.success.withOpacity(0.1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showRuleDetails(rule),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Rule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingRuleDetailsDialog extends StatefulWidget {
  final BookingRuleModel rule;
  final Function(BookingRuleModel) onUpdate;

  const _BookingRuleDetailsDialog({
    required this.rule,
    required this.onUpdate,
  });

  @override
  State<_BookingRuleDetailsDialog> createState() => _BookingRuleDetailsDialogState();
}

class _BookingRuleDetailsDialogState extends State<_BookingRuleDetailsDialog> {
  late BookingRuleModel _editedRule;
  final Map<String, TextEditingController> _parameterControllers = {};

  @override
  void initState() {
    super.initState();
    _editedRule = widget.rule;
    _initializeControllers();
  }

  void _initializeControllers() {
    _editedRule.parameters.forEach((key, value) {
      if (value is List) {
        _parameterControllers[key] = TextEditingController(text: value.join(', '));
      } else {
        _parameterControllers[key] = TextEditingController(text: value.toString());
      }
    });
  }

  @override
  void dispose() {
    _parameterControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _saveRule() {
    final updatedParameters = <String, dynamic>{};
    _parameterControllers.forEach((key, controller) {
      final value = controller.text;
      // Try to parse as number, boolean, or list
      if (value.toLowerCase() == 'true') {
        updatedParameters[key] = true;
      } else if (value.toLowerCase() == 'false') {
        updatedParameters[key] = false;
      } else if (value.contains(',')) {
        // List of values
        updatedParameters[key] = value.split(',').map((e) => num.tryParse(e.trim()) ?? e.trim()).toList();
      } else {
        final numValue = num.tryParse(value);
        updatedParameters[key] = numValue ?? value;
      }
    });

    final updatedRule = _editedRule.copyWith(
      parameters: updatedParameters,
      updatedAt: DateTime.now(),
    );

    widget.onUpdate(updatedRule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editedRule.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _editedRule.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable/Disable
                    SwitchListTile(
                      title: const Text('Enable Rule'),
                      subtitle: const Text('Turn this booking rule on or off'),
                      value: _editedRule.isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _editedRule = _editedRule.copyWith(isEnabled: value);
                        });
                      },
                    ),
                    const Divider(),
                    // Parameters
                    const Text(
                      'Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._editedRule.parameters.entries.map((entry) {
                      final isList = entry.value is List;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _parameterControllers[entry.key],
                          decoration: InputDecoration(
                            labelText: entry.key.replaceAll(RegExp(r'([A-Z])'), r' $1').trim(),
                            hintText: isList ? entry.value.join(', ') : entry.value.toString(),
                            border: const OutlineInputBorder(),
                            helperText: isList
                                ? 'Enter comma-separated values (e.g., 24, 2)'
                                : 'Current: ${entry.value}',
                          ),
                          maxLines: isList ? 2 : 1,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveRule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Changes'),
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

