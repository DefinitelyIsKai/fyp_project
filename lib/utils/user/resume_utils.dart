import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user/resume_attachment.dart';

/// Returns true if the attachment could be opened successfully.
Future<bool> openResumeAttachment(ResumeAttachment attachment) async {
  if (attachment.hasRemoteUrl) {
    final uri = Uri.tryParse(attachment.downloadUrl!);
    if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return false;
  }

  if (!attachment.hasEmbeddedData) return false;

  try {
    final bytes = base64Decode(attachment.base64Data!);
    final dir = await getTemporaryDirectory();
    final sanitizedName = attachment.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fallbackName = sanitizedName.isEmpty ? 'resume.${attachment.fileType}' : sanitizedName;
    final filePath = '${dir.path}/resume_${DateTime.now().millisecondsSinceEpoch}_$fallbackName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  } catch (_) {
    return false;
  }
}

