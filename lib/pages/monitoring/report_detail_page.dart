import 'package:flutter/material.dart';
import 'package:fyp_project/models/report_model.dart';
import 'package:fyp_project/services/report_service.dart';

class ReportDetailPage extends StatefulWidget {
  final ReportModel report;

  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  final ReportService _reportService = ReportService();
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  Future<void> _updateReportStatus(ReportStatus status) async {
    setState(() => _isProcessing = true);
    try {
      await _reportService.updateReportStatus(
        widget.report.id,
        status,
        notes: _notesController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Type', value: widget.report.reportType.toString().split('.').last),
            _DetailRow(label: 'Reason', value: widget.report.reason),
            if (widget.report.description != null)
              _DetailRow(label: 'Description', value: widget.report.description!),
            _DetailRow(
              label: 'Reported At',
              value: widget.report.reportedAt.toString().split(' ')[0],
            ),
            _DetailRow(
              label: 'Status',
              value: widget.report.status.toString().split('.').last,
            ),
            if (widget.report.reviewNotes != null)
              _DetailRow(label: 'Review Notes', value: widget.report.reviewNotes!),
            const Divider(),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Review Notes',
                border: OutlineInputBorder(),
                hintText: 'Add notes about this report...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _updateReportStatus(ReportStatus.resolved),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _updateReportStatus(ReportStatus.dismissed),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

