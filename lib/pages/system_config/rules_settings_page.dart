import 'package:flutter/material.dart';
import 'package:fyp_project/models/system_config_model.dart';
import 'package:fyp_project/services/system_config_service.dart';

class RulesSettingsPage extends StatefulWidget {
  const RulesSettingsPage({super.key});

  @override
  State<RulesSettingsPage> createState() => _RulesSettingsPageState();
}

class _RulesSettingsPageState extends State<RulesSettingsPage> {
  final SystemConfigService _configService = SystemConfigService();
  List<SystemConfigModel> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() => _isLoading = true);
    try {
      final configs = await _configService.getRulesConfigs();
      setState(() => _configs = configs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading configs: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateConfig(SystemConfigModel config, dynamic newValue) async {
    try {
      await _configService.updateConfig(config.id, newValue);
      _loadConfigs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rules & Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? const Center(child: Text('No configuration found'))
              : ListView.builder(
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(config.key),
                        subtitle: Text(config.description ?? ''),
                        trailing: _buildConfigEditor(config),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildConfigEditor(SystemConfigModel config) {
    if (config.dataType == 'boolean') {
      return Switch(
        value: config.value as bool? ?? false,
        onChanged: (value) => _updateConfig(config, value),
      );
    } else if (config.dataType == 'number') {
      return SizedBox(
        width: 100,
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: config.value.toString(),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final numValue = num.tryParse(value);
            if (numValue != null) {
              _updateConfig(config, numValue);
            }
          },
        ),
      );
    } else {
      return SizedBox(
        width: 150,
        child: TextField(
          decoration: InputDecoration(
            hintText: config.value.toString(),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => _updateConfig(config, value),
        ),
      );
    }
  }
}

