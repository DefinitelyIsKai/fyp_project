import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/system_config_model.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';

class PlatformSettingsPage extends StatefulWidget {
  const PlatformSettingsPage({super.key});

  @override
  State<PlatformSettingsPage> createState() => _PlatformSettingsPageState();
}

class _PlatformSettingsPageState extends State<PlatformSettingsPage> {
  final SystemConfigService _configService = SystemConfigService();
  List<SystemConfigModel> _settings = [];
  bool _isLoading = true;
  Map<String, dynamic> _settingValues = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final settings = await _configService.getPlatformSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _settingValues = {
            for (var setting in settings) setting.id: setting.value
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(SystemConfigModel setting, dynamic newValue) async {
    if (!mounted) return;
    
    // Optimistically update UI
    setState(() {
      _settingValues[setting.id] = newValue;
    });
    
    try {
      await _configService.updateConfig(setting.id, newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${setting.key} ${setting.dataType == 'boolean' ? (newValue ? 'enabled' : 'disabled') : 'updated'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _settingValues[setting.id] = setting.value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Settings'),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No settings found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _settings.length,
                  itemBuilder: (context, index) {
                    final setting = _settings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    setting.key.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    setting.description ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildSettingEditor(setting),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildSettingEditor(SystemConfigModel setting) {
    final currentValue = _settingValues[setting.id] ?? setting.value;
    
    if (setting.dataType == 'boolean') {
      return Switch(
        value: currentValue as bool? ?? false,
        onChanged: (value) {
          if (mounted) {
            _updateSetting(setting, value);
          }
        },
      );
    } else if (setting.dataType == 'number') {
      return SizedBox(
        width: 150,
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: currentValue.toString(),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          controller: TextEditingController(text: currentValue.toString()),
          onSubmitted: (value) {
            final numValue = int.tryParse(value) ?? double.tryParse(value);
            if (numValue != null && mounted) {
              _updateSetting(setting, numValue);
            }
          },
        ),
      );
    } else {
      return SizedBox(
        width: 200,
        child: TextField(
          decoration: InputDecoration(
            hintText: currentValue.toString(),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          controller: TextEditingController(text: currentValue.toString()),
          onSubmitted: (value) {
            if (mounted) {
              _updateSetting(setting, value);
            }
          },
        ),
      );
    }
  }
}

