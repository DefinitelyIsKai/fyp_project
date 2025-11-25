import 'package:flutter/material.dart';

import '../../models/user/resume_attachment.dart';
import '../../utils/user/resume_utils.dart';

class ResumePreviewCard extends StatelessWidget {
  const ResumePreviewCard({
    super.key,
    required this.attachment,
    required this.uploading,
    required this.onUpload,
    this.onRemove,
  });

  final ResumeAttachment? attachment;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  bool get _hasResume => attachment != null;

  String get _fileLabel {
    if (!_hasResume) return 'No resume uploaded yet';
    return attachment!.fileName;
  }

  String get _subtitle {
    if (!_hasResume) return 'Upload a PDF or image resume file.';
    final type = attachment!.fileType.toUpperCase();
    return 'Stored as $type • Tap Preview to view.';
  }

  Future<void> _preview(BuildContext context) async {
    final resume = attachment;
    if (resume == null) return;
    final ok = await openResumeAttachment(resume);
    if (!ok && context.mounted) {
      _showError(context);
    }
  }

  void _showError(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Unable to open resume file'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF00C8A0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF00C8A0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: uploading ? null : onUpload,
                icon: uploading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Icon(_hasResume ? Icons.swap_horiz : Icons.cloud_upload_outlined, color: accent),
                label: Text(_hasResume ? 'Replace Resume' : 'Upload Resume'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              TextButton.icon(
                onPressed: _hasResume ? () => _preview(context) : null,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview'),
              ),
              if (_hasResume && onRemove != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

