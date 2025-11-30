import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/user/resume_attachment.dart';
import '../../../models/user/tag_category.dart';
import '../../../services/user/tag_service.dart';
import '../../../utils/user/resume_utils.dart';
import '../../../utils/user/tag_definitions.dart';
import '../../../utils/user/dialog_utils.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _previewingResume = false;
  final _tagService = TagService();
  Map<String, TagCategory> _categoryMap = {};
  bool _tagsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTagCategories();
  }

  Future<void> _loadTagCategories() async {
    try {
      final tagsData = await _tagService.getActiveTagCategoriesWithTags();
      final categoryMap = <String, TagCategory>{};
      for (final entry in tagsData.entries) {
        categoryMap[entry.key.id] = entry.key;
      }
      if (mounted) {
        setState(() {
          _categoryMap = categoryMap;
          _tagsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tagsLoaded = true;
        });
      }
    }
  }

  Future<void> _previewResume(ResumeAttachment attachment) async {
    if (_previewingResume) return;
    setState(() => _previewingResume = true);
    final ok = await openResumeAttachment(attachment);
    if (!ok && mounted) {
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Unable to open resume file',
      );
    }
    if (mounted) setState(() => _previewingResume = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF00C8A0),
              ),
            );
          }

          if (snap.hasError) {
            return _buildErrorState();
          }

          final data = snap.data?.data() ?? <String, dynamic>{};
          final name = (data['fullName'] as String?) ?? 'Unknown User';
          final email = (data['email'] as String?) ?? 'No email provided';
          final phone = (data['phoneNumber'] as String?) ?? 'Not shared';
          final location = (data['location'] as String?) ?? 'Location not specified';
          final gender = (data['gender'] as String?);
          final summary = (data['professionalSummary'] as String?) ?? 'No professional summary available.';
          final professionalProfile = (data['professionalProfile'] as String?) ?? 'Not specified';
          final workExperience = (data['workExperience'] as String?) ?? 'Not specified';
          final roleRaw = (data['role'] as String?)?.toLowerCase() ?? 'jobseeker';
          final role = roleRaw == 'recruiter' ? 'Recruiter' : 'Jobseeker';
          final tags = parseTagSelection(data['tags']);
          final resume = ResumeAttachment.fromMap(data['resume']);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                // Force refresh by updating state
              });
              await Future.delayed(const Duration(milliseconds: 100));
            },
            color: const Color(0xFF00C8A0),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(name, role),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildContactCard(email, phone, location, gender),
                      const SizedBox(height: 16),
                      _buildProfessionalDetailsCard(professionalProfile, workExperience, roleRaw),
                      const SizedBox(height: 16),
                      _buildSummaryCard(summary),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTagsCard(tags),
                      ],
                      const SizedBox(height: 16),
                      _buildResumeCard(resume),
                    ],
                  ),
                ),
              ],
            ),
          ),
          );
        },
        
      ),
    );
  }

  Widget _buildHeader(String name, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C8A0),
            const Color(0xFF00C8A0).withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00C8A0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(String email, String phone, String location, String? gender) {
    return _SectionCard(
      icon: Icons.contact_mail_outlined,
      title: 'Contact Information',
      child: Column(
        children: [
          _InfoRow(
            label: 'Email',
            value: email,
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Phone',
            value: phone,
            icon: Icons.phone_outlined,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Location',
            value: location,
            icon: Icons.location_on_outlined,
          ),
          if (gender != null && gender.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Gender',
              value: _formatGender(gender),
              icon: Icons.person_outline,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfessionalDetailsCard(String profile, String experience, String role) {
    return _SectionCard(
      icon: Icons.work_outline,
      title: 'Professional Details',
      child: Column(
        children: [
          _InfoRow(
            label: 'Professional Profile',
            value: profile,
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Experience',
            value: experience,
            icon: Icons.timeline_outlined,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Opportunity Preference',
            value: _formatOpportunityPreference(role),
            icon: Icons.campaign_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String summary) {
    return _SectionCard(
      icon: Icons.description_outlined,
      title: 'Professional Summary',
      child: Text(
        summary,
        style: TextStyle(
          color: Colors.grey[700],
          height: 1.5,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTagsCard(TagSelectionMap selections) {
    if (!_tagsLoaded) {
      return _SectionCard(
        icon: Icons.sell_outlined,
        title: 'Talent Tags',
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final availableCategories = selections.entries
        .where((entry) => entry.value.isNotEmpty && _categoryMap.containsKey(entry.key))
        .map((entry) => MapEntry(_categoryMap[entry.key]!, entry.value))
        .toList();

    if (availableCategories.isEmpty) {
      return _SectionCard(
        icon: Icons.sell_outlined,
        title: 'Talent Tags',
        child: Text(
          'No tags shared yet.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return _SectionCard(
      icon: Icons.sell_outlined,
      title: 'Talent Tags',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: availableCategories.map((entry) {
          final category = entry.key;
          final tags = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor: const Color(0xFF00C8A0).withOpacity(0.12),
                          labelStyle: const TextStyle(
                            color: Color(0xFF00C8A0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResumeCard(ResumeAttachment? resume) {
    final attachment = resume;
    final hasResume = attachment != null;
    String formatDescription = 'Upload a resume to share more details.';
    VoidCallback? previewCallback;
    if (attachment != null) {
      formatDescription = 'Format: ${attachment.fileType.toUpperCase()}';
      if (!_previewingResume) {
        previewCallback = () => _previewResume(attachment);
      }
    }
    final accent = const Color(0xFF00C8A0);

    return _SectionCard(
      icon: Icons.insert_drive_file_outlined,
      title: 'Resume',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attachment?.fileName ?? 'No resume shared',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            formatDescription,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: previewCallback,
              icon: _previewingResume
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: Text(hasResume ? 'Preview Resume' : 'Resume Unavailable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasResume ? accent : Colors.grey[300],
                foregroundColor: hasResume ? Colors.white : Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load profile',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatOpportunityPreference(String role) {
    switch (role.toLowerCase()) {
      case 'recruiter':
        return 'Looking for jobseekers';
      case 'jobseeker':
        return 'Actively seeking opportunities';
      default:
        return 'Not specified';
    }
  }

  String _formatGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      default:
        return gender;
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8A0).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF00C8A0)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00C8A0), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}