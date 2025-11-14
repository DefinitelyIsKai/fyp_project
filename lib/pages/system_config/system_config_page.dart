import 'package:flutter/material.dart';
import 'package:fyp_project/pages/system_config/rules_settings_page.dart';
import 'package:fyp_project/pages/system_config/platform_settings_page.dart';

class SystemConfigPage extends StatelessWidget {
  const SystemConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.rule, size: 40),
              title: const Text('Define Rules', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Set parameters such as matching logic, credit allocation, and abuse thresholds'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RulesSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings, size: 40),
              title: const Text('Platform Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Update platform settings and policy terms'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlatformSettingsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

