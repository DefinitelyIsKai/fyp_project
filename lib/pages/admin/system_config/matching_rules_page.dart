import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/matching_rule_model.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/user/matching_service.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class MatchingRulesPage extends StatefulWidget {
  const MatchingRulesPage({super.key});

  @override
  State<MatchingRulesPage> createState() => _MatchingRulesPageState();
}

class _MatchingRulesPageState extends State<MatchingRulesPage> {
  final SystemConfigService _configService = SystemConfigService();
  // Using static MatchingService.clearWeightsCache() instead of instance
  List<MatchingRuleModel> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final rules = await _configService.getMatchingRules();
      if (rules.isEmpty) {
        await _configService.initializeDefaultMatchingRules();
        final updatedRules = await _configService.getMatchingRules();
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

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all matching rules to their default values. Existing customizations will be lost. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _configService.initializeDefaultMatchingRules();
        
        // Clear matching weights cache to apply changes immediately (static method clears all instances)
        MatchingService.clearWeightsCache();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rules reset to defaults successfully. Matching cache cleared.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadRules();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting rules: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateRule(MatchingRuleModel rule) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final updatedBy = authService.currentAdmin?.email;
      
      await _configService.updateMatchingRule(rule, updatedBy: updatedBy);
      
      // Clear matching weights cache to apply changes immediately (static method clears all instances)
      MatchingService.clearWeightsCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rule updated successfully. Matching cache cleared.'),
            backgroundColor: Colors.green,
          ),
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

  void _showRuleDetails(MatchingRuleModel rule) {
    showDialog(
      context: context,
      builder: (context) => _RuleDetailsDialog(rule: rule, onUpdate: _updateRule),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matching Rules Configuration'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRules,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset') {
                _resetToDefaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 20),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
            ],
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
                      Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No matching rules found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _configService.initializeDefaultMatchingRules();
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
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Configure how jobs are matched to users. Adjust weights to prioritize different matching criteria. These weights correspond to the algorithm in hybrid_matching_engine.dart.',
                                  style: TextStyle(color: Colors.blue[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Weight Summary Card
                      _buildWeightSummaryCard(),
                      const SizedBox(height: 16),
                      ..._rules.map((rule) => _buildRuleCard(rule)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeightSummaryCard() {
    final enabledRules = _rules.where((r) => r.isEnabled).toList();
    final totalWeight = enabledRules.fold<double>(0.0, (sum, rule) => sum + rule.weight);
    final totalWeightPercent = totalWeight * 100;
    
    return Card(
      elevation: 2,
      color: totalWeight == 1.0 ? Colors.green[50] : Colors.orange[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: totalWeight == 1.0 ? Colors.green[300]! : Colors.orange[300]!,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  totalWeight == 1.0 ? Icons.check_circle : Icons.warning,
                  color: totalWeight == 1.0 ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'Weight Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: totalWeight == 1.0 ? Colors.green[900] : Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total Weight: ${totalWeightPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: totalWeight == 1.0 ? Colors.green[700] : Colors.orange[700],
              ),
            ),
            if (totalWeight != 1.0) ...[
              const SizedBox(height: 8),
              Text(
                totalWeight < 1.0
                    ? 'Total is less than 100%. Consider increasing weights for better matching coverage.'
                    : 'Total exceeds 100%. Consider reducing weights to balance the algorithm.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[900],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...enabledRules.map((rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      rule.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${(rule.weight * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(MatchingRuleModel rule) {
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weight: ${(rule.weight * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: rule.weight,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rule.isEnabled ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRuleDetails(rule),
                    tooltip: 'Edit Rule',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleDetailsDialog extends StatefulWidget {
  final MatchingRuleModel rule;
  final Function(MatchingRuleModel) onUpdate;

  const _RuleDetailsDialog({
    required this.rule,
    required this.onUpdate,
  });

  @override
  State<_RuleDetailsDialog> createState() => _RuleDetailsDialogState();
}

class _RuleDetailsDialogState extends State<_RuleDetailsDialog> {
  late MatchingRuleModel _editedRule;
  final Map<String, TextEditingController> _parameterControllers = {};

  @override
  void initState() {
    super.initState();
    _editedRule = widget.rule;
    _initializeControllers();
  }

  void _initializeControllers() {
    _editedRule.parameters.forEach((key, value) {
      _parameterControllers[key] = TextEditingController(text: value.toString());
    });
  }

  @override
  void dispose() {
    _parameterControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildDistanceParameterField(
    String key,
    String label,
    String description,
    String unit,
    {required double min, required double max}
  ) {
    final controller = _parameterControllers[key];
    final currentValue = _editedRule.parameters[key] ?? 0.0;
    bool hasError = false;
    if (controller != null && controller.text.isNotEmpty) {
      final parsedValue = double.tryParse(controller.text);
      if (parsedValue == null || parsedValue < min || parsedValue > max) {
        hasError = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        if (controller != null)
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: unit.isNotEmpty ? '$label ($unit)' : label,
            hintText: currentValue.toString(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.blue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: hasError ? Colors.red[50] : Colors.grey[50],
            suffixText: unit.isNotEmpty ? unit : null,
            helperText: 'Current: $currentValue${unit.isNotEmpty ? ' $unit' : ''} | Range: $min - $max',
            errorText: hasError
                ? 'Please enter a number between $min and $max'
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            setState(() {
              // Trigger rebuild to update error state
            });
          },
          )
        else
          Text(
            'Error: Controller not initialized',
            style: TextStyle(color: Colors.red),
          ),
      ],
    );
  }

  void _saveRule() {
    if (widget.rule.id == 'distance') {
      final maxDistanceController = _parameterControllers['maxDistanceKm'];
      final decayFactorController = _parameterControllers['decayFactor'];
      
      if (maxDistanceController != null && maxDistanceController.text.isNotEmpty) {
        final maxDistance = double.tryParse(maxDistanceController.text);
        if (maxDistance == null || maxDistance < 1.0 || maxDistance > 1000.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum Distance must be between 1 and 1000 km'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      if (decayFactorController != null && decayFactorController.text.isNotEmpty) {
        final decayFactor = double.tryParse(decayFactorController.text);
        if (decayFactor == null || decayFactor < 0.1 || decayFactor > 10.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Decay Factor must be between 0.1 and 10.0'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    final updatedParameters = <String, dynamic>{};
    _parameterControllers.forEach((key, controller) {
      final value = controller.text;
      if (value.isEmpty) {
        updatedParameters[key] = _editedRule.parameters[key];
      } else {
        final numValue = num.tryParse(value);
        updatedParameters[key] = numValue ?? value;
      }
    });
    
    updatedParameters['weight'] = _editedRule.weight;
    if (_editedRule.parameters.containsKey('description')) {
      updatedParameters['description'] = _editedRule.parameters['description'];
    }

    final updatedRule = _editedRule.copyWith(
      weight: _editedRule.weight,
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
                color: Colors.blue[700],
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
                      subtitle: const Text('Turn this matching rule on or off'),
                      value: _editedRule.isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _editedRule = _editedRule.copyWith(isEnabled: value);
                        });
                      },
                    ),
                    const Divider(),
                    // Weight Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weight: ${(_editedRule.weight * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _editedRule.weight,
                          min: 0.0,
                          max: 1.0,
                          divisions: 200,
                          label: '${(_editedRule.weight * 100).toStringAsFixed(1)}%',
                          onChanged: (value) {
                            setState(() {
                              _editedRule = _editedRule.copyWith(weight: value);
                              // Update the weight parameter as well
                              final updatedParams = Map<String, dynamic>.from(_editedRule.parameters);
                              updatedParams['weight'] = value;
                              _editedRule = _editedRule.copyWith(parameters: updatedParams);
                            });
                          },
                        ),
                        Text(
                          'This determines how much this rule contributes to the overall match score. Total of all enabled rules should ideally sum to 1.0 (100%).',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        // Show current total weight
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note: These weights are used in the hybrid matching engine scoring algorithm. Ensure weights are properly balanced for optimal matching results.',
                                  style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    // Parameters
                    if (_editedRule.parameters.isNotEmpty && 
                        !_editedRule.parameters.keys.every((k) => k == 'weight' || k == 'description'))
                    ...[
                      const Text(
                        'Additional Parameters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Special handling for distance matching parameters
                      if (widget.rule.id == 'distance') ...[
                        _buildDistanceParameterField(
                          'maxDistanceKm',
                          'Maximum Distance',
                          'Maximum distance in kilometers for job matching. Jobs beyond this distance will receive a score of 0.',
                          'km',
                          min: 1.0,
                          max: 1000.0,
                        ),
                        const SizedBox(height: 16),
                        _buildDistanceParameterField(
                          'decayFactor',
                          'Distance Decay Factor',
                          'Controls how quickly the match score decreases with distance. Higher values = stricter (score drops faster). Lower values = more forgiving (score drops slower).',
                          '',
                          min: 0.1,
                          max: 10.0,
                        ),
                      ] else ...[
                        // Generic parameter fields for other rules
                        ..._editedRule.parameters.entries.where((entry) => 
                          entry.key != 'weight' && entry.key != 'description'
                        ).map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: _parameterControllers[entry.key],
                              decoration: InputDecoration(
                                labelText: entry.key.replaceAll(RegExp(r'([A-Z])'), r' $1').trim(),
                                hintText: entry.value.toString(),
                                border: const OutlineInputBorder(),
                                helperText: 'Current: ${entry.value}',
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
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
                      backgroundColor: AppColors.primaryDark,
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

