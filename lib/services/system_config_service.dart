import 'package:fyp_project/models/system_config_model.dart';

class SystemConfigService {
  Future<List<SystemConfigModel>> getRulesConfigs() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data
    return [
      SystemConfigModel(
        id: '1',
        key: 'matching_logic',
        value: 'default',
        description: 'Job matching algorithm',
        dataType: 'string',
        updatedAt: DateTime.now(),
      ),
      SystemConfigModel(
        id: '2',
        key: 'credit_allocation',
        value: 10,
        description: 'Default credit allocation per user',
        dataType: 'number',
        updatedAt: DateTime.now(),
      ),
      SystemConfigModel(
        id: '3',
        key: 'abuse_threshold',
        value: 5,
        description: 'Number of reports before auto-suspension',
        dataType: 'number',
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<List<SystemConfigModel>> getPlatformSettings() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data
    return [
      SystemConfigModel(
        id: '1',
        key: 'platform_name',
        value: 'JobSeek',
        description: 'Platform name',
        dataType: 'string',
        updatedAt: DateTime.now(),
      ),
      SystemConfigModel(
        id: '2',
        key: 'maintenance_mode',
        value: false,
        description: 'Enable maintenance mode',
        dataType: 'boolean',
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<void> updateConfig(String configId, dynamic value) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }
}

