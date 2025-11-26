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
        title: const Text(
          'System Configuration',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.cardPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          Expanded(child: _buildOptionsGrid(context)),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Header
  // -------------------------------------------------------
  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardPurple, Color(0xFF9C27B0)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage matching rules, booking rules, and platform settings',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Grid options
  // -------------------------------------------------------
  Widget _buildOptionsGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        children: [
          _ManagementCard(
            title: 'Matching Rules',
            description: 'Configure job matching algorithms, weights, and criteria',
            icon: Icons.rule,
            iconColor: Colors.blue[700]!,
            backgroundColor: Colors.blue[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MatchingRulesPage()),
              );
            },
            stats: 'Algorithm config',
            badgeCount: 0,
          ),
          _ManagementCard(
            title: 'General Rules',
            description: 'Set parameters such as matching logic, credit allocation, and abuse thresholds',
            icon: Icons.settings_applications,
            iconColor: Colors.orange[700]!,
            backgroundColor: Colors.orange[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RulesSettingsPage()),
              );
            },
            stats: 'System rules',
            badgeCount: 0,
          ),
          _ManagementCard(
            title: 'Booking Rules',
            description: 'Configure booking windows, cancellation policies, and limits',
            icon: Icons.event_busy,
            iconColor: Colors.green[700]!,
            backgroundColor: Colors.green[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingRulesPage()),
              );
            },
            stats: 'Booking config',
            badgeCount: 0,
          ),
          _ManagementCard(
            title: 'Platform Settings',
            description: 'Update platform settings and policy terms',
            icon: Icons.business,
            iconColor: Colors.purple[700]!,
            backgroundColor: Colors.purple[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlatformSettingsPage()),
              );
            },
            stats: 'Platform config',
            badgeCount: 0,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// Reusable Management Card (Same as Post Moderation)
// -------------------------------------------------------
class _ManagementCard extends StatelessWidget {
  final String title;
  final String description;
  final String stats;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _ManagementCard({
    required this.title,
    required this.description,
    required this.stats,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 28, color: iconColor),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  SizedBox(
                    height: 40,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Description
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stats,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),

              // Badge in top-right corner
              if (badgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

