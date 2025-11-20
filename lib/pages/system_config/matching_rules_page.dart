import 'package:flutter/material.dart';
import 'package:fyp_project/models/matching_rule_model.dart';
import 'package:fyp_project/services/system_config_service.dart';
import 'package:fyp_project/services/auth_service.dart';
import 'package:provider/provider.dart';

class MatchingRulesPage extends StatefulWidget {
  const MatchingRulesPage({super.key});

  @override
  State<MatchingRulesPage> createState() => _MatchingRulesPageState();
}

class _MatchingRulesPageState extends State<MatchingRulesPage> {
  final SystemConfigService _configService = SystemConfigService();
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

  Future<void> _updateRule(MatchingRuleModel rule) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final updatedBy = authService.currentAdmin?.email;
      
      await _configService.updateMatchingRule(rule, updatedBy: updatedBy);
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
        backgroundColor: Colors.blue[700],
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
                                  'Configure how jobs are matched to users. Adjust weights to prioritize different matching criteria.',
                                  style: TextStyle(color: Colors.blue[900]),
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
                          'Weight: ${(rule.weight * 100).toStringAsFixed(0)}%',
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

  void _saveRule() {
    final updatedParameters = <String, dynamic>{};
    _parameterControllers.forEach((key, controller) {
      final value = controller.text;
      // Try to parse as number, otherwise keep as string
      final numValue = num.tryParse(value);
      updatedParameters[key] = numValue ?? value;
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
                          'Weight: ${(_editedRule.weight * 100).toStringAsFixed(0)}%',
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
                          divisions: 100,
                          label: '${(_editedRule.weight * 100).toStringAsFixed(0)}%',
                          onChanged: (value) {
                            setState(() {
                              _editedRule = _editedRule.copyWith(weight: value);
                            });
                          },
                        ),
                        Text(
                          'This determines how much this rule contributes to the overall match score.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
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
                      backgroundColor: Colors.blue[700],
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

