import 'dart:convert';

class ResumeAttachment {
  const ResumeAttachment({
    required this.fileName,
    required this.fileType,
    this.base64Data,
    this.downloadUrl,
  });

  final String fileName;
  final String fileType;
  final String? base64Data;
  final String? downloadUrl;

  bool get hasRemoteUrl => downloadUrl != null && downloadUrl!.isNotEmpty;
  bool get hasEmbeddedData => base64Data != null && base64Data!.isNotEmpty;

  String? get legacyValue => downloadUrl ?? base64Data;

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'fileType': fileType,
        if (base64Data != null) 'base64': base64Data,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
      };

  static ResumeAttachment? fromMap(dynamic data) {
    if (data is! Map) return null;
    final fileName = data['fileName'] as String? ?? 'Resume';
    final fileType = data['fileType'] as String? ?? 'pdf';
    final base64 = data['base64'] as String?;
    final remoteUrl = data['downloadUrl'] as String?;
    if ((base64 == null || base64.isEmpty) && (remoteUrl == null || remoteUrl.isEmpty)) {
      return null;
    }
    return ResumeAttachment(
      fileName: fileName,
      fileType: fileType,
      base64Data: base64,
      downloadUrl: remoteUrl,
    );
  }

  static ResumeAttachment? fromLegacyValue(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Resume';
      final type = segment.contains('.') ? segment.split('.').last : 'pdf';
      return ResumeAttachment(
        fileName: segment,
        fileType: type,
        downloadUrl: value,
      );
    }
    try {
      base64Decode(value);
      return ResumeAttachment(
        fileName: 'Resume',
        fileType: 'pdf',
        base64Data: value,
      );
    } catch (_) {
      return null;
    }
  }
}

