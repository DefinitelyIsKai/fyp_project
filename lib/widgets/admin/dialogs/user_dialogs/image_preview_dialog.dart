import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Dialog for previewing base64 encoded images
class ImagePreviewDialog extends StatelessWidget {
  final String base64String;
  final Map<String, Uint8List>? imageCache;

  const ImagePreviewDialog({
    super.key,
    required this.base64String,
    this.imageCache,
  });

  /// Shows the image preview dialog
  static void show({
    required BuildContext context,
    required String base64String,
    Map<String, Uint8List>? imageCache,
  }) {
    try {
      final cleanBase64 = base64String.trim().replaceAll(RegExp(r'\s+'), '');
      Uint8List bytes;
      
      if (imageCache != null && imageCache.containsKey(cleanBase64)) {
        bytes = imageCache[cleanBase64]!;
      } else {
        bytes = base64Decode(cleanBase64);
        if (imageCache != null) {
          imageCache[cleanBase64] = bytes;
        }
      }

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Image Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Image
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey[100],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.red[300], size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.red[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error displaying image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget is typically used via the static show method
    return const SizedBox.shrink();
  }
}

