import 'package:flutter/material.dart';
import 'package:fyp_project/pages/admin/system_config/rules_settings_page.dart';
import 'package:fyp_project/pages/admin/system_config/platform_settings_page.dart';
import 'package:fyp_project/pages/admin/system_config/matching_rules_page.dart';
import 'package:fyp_project/pages/admin/system_config/booking_rules_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class SystemConfigPage extends StatelessWidget {
  const SystemConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
        backgroundColor: AppColors.cardPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.cardPurple, Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage matching rules, booking rules, and platform settings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Matching Rules Section
            _buildSectionHeader('Matching & Algorithm Rules', Icons.tune, Colors.blue),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rule, color: Colors.blue, size: 28),
                ),
                title: const Text('Matching Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Configure job matching algorithms, weights, and criteria'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MatchingRulesPage()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings_applications, color: Colors.orange, size: 28),
                ),
                title: const Text('General Rules & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Set parameters such as matching logic, credit allocation, and abuse thresholds'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RulesSettingsPage()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Booking Rules Section
            _buildSectionHeader('Booking & Appointment Rules', Icons.event, Colors.green),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_busy, color: Colors.green, size: 28),
                ),
                title: const Text('Booking Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Configure booking windows, cancellation policies, and limits'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingRulesPage()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Platform Settings Section
            _buildSectionHeader('Platform Settings', Icons.settings, Colors.purple),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Colors.purple, size: 28),
                ),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
      ],
    );
  }
}

