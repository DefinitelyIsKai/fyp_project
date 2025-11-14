import 'package:flutter/material.dart';
import 'package:fyp_project/pages/post_moderation/categories_page.dart';
import 'package:fyp_project/pages/post_moderation/tags_page.dart';

class ManageTagsCategoriesPage extends StatelessWidget {
  const ManageTagsCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tags & Categories')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.category, size: 40),
              title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Organize job posts by industry or type'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesPage()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.label, size: 40),
              title: const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Manage tags for job posts'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TagsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

