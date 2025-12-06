import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/user/dialog_utils.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final String _supportEmail = 'support@jobseek.app';
  final String _supportPhone = '+1 (555) 123-4567';

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=Help & Support Request',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Unable to open email. Please contact us at $_supportEmail',
      );
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _supportPhone);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Unable to make phone call. Please call us at $_supportPhone',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contact_support, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildContactCard(
                  icon: Icons.email,
                  title: 'Email Support',
                  subtitle: _supportEmail,
                  onTap: _launchEmail,
                ),
                const SizedBox(height: 12),
                _buildContactCard(
                  icon: Icons.phone,
                  title: 'Phone Support',
                  subtitle: _supportPhone,
                  onTap: _launchPhone,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.quiz, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FAQItem(
                  question: 'How do I create a job post?',
                  answer: 'To create a job post, go to the "Posts" tab in the bottom navigation and tap the "+" button. Fill in all the required information including title, description, budget, location, and requirements. You can save as draft or publish immediately.',
                ),
                _FAQItem(
                  question: 'How do I apply for a job?',
                  answer: 'Browse available jobs in the "Search & Discovery" tab. When you find a job you\'re interested in, tap on it to view details, then tap "Apply Now" at the bottom. Note that applying costs 100 points, which will be held until the recruiter makes a decision.',
                ),
                _FAQItem(
                  question: 'What are points/credits used for?',
                  answer: 'Credits (points) are used to create job posts (200 credits) and apply for jobs (100 credits). Credits are held when you create a post or apply, and will be deducted if approved or released if rejected. You can purchase more credits in your Wallet.',
                ),
                _FAQItem(
                  question: 'How does the matching system work?',
                  answer: 'Our matching system uses AI to match jobseekers with relevant job posts based on skills, experience, and preferences. You can view your matches in the "Matching" tab. Recruiters can also use precise matching for optimal candidate selection.',
                ),
                _FAQItem(
                  question: 'Can I edit or delete my job post?',
                  answer: 'Yes, you can edit or delete your job posts from the "Posts" tab. Tap on a post to view it, then use the options menu to edit or delete. Note that deleting a post will notify all applicants.',
                ),
                _FAQItem(
                  question: 'How do I report inappropriate content?',
                  answer: 'You can report posts, users, or jobseekers using the flag icon. Reports are reviewed by our moderation team. To report a post, open it and tap the flag icon in the top right corner.',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'Need More Help?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'If you cannot find the answer to your question in the FAQs above, please contact our support team using the email or phone number provided. We typically respond within 24 hours during business days.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00C8A0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00C8A0), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isExpanded 
                  ? const Color(0xFF00C8A0).withOpacity(0.05)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isExpanded 
                    ? const Color(0xFF00C8A0).withOpacity(0.3)
                    : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isExpanded ? const Color(0xFF00C8A0) : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _isExpanded ? const Color(0xFF00C8A0) : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              widget.answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
