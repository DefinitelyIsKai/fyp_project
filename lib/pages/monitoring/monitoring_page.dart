import 'package:flutter/material.dart';
import 'package:fyp_project/pages/monitoring/search_filter_page.dart';
import 'package:fyp_project/pages/monitoring/flagged_content_page.dart';

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring & Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.search, size: 40),
              title: const Text('Search and Filter', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Quickly locate content using keywords, category, or status'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchFilterPage()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag, size: 40),
              title: const Text('Flagged Content', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Monitor flagged content or reports'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FlaggedContentPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

