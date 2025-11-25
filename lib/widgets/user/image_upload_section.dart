import 'package:flutter/material.dart';
import '../../services/user/storage_service.dart';

/// A reusable image upload section widget
/// 
/// Displays a grid of uploaded images with the ability to add and remove images.
/// Used for post attachments, profile images, etc.
class ImageUploadSection extends StatefulWidget {
  /// The list of image URLs to display
  final List<String> images;
  
  /// Callback when images are added
  final Function(List<String> newUrls) onImagesAdded;
  
  /// Callback when an image is removed
  final Function(int index) onImageRemoved;
  
  /// The title/header text
  final String title;
  
  /// Optional description text
  final String? description;
  
  /// The storage service to use for uploading
  final StorageService storageService;
  
  /// The ID to use for organizing uploads (e.g., postId, userId)
  final String uploadId;
  
  /// Whether the section is disabled (e.g., during save)
  final bool disabled;
  
  /// Optional custom upload function
  final Future<List<String>> Function()? customUploadFunction;

  const ImageUploadSection({
    super.key,
    required this.images,
    required this.onImagesAdded,
    required this.onImageRemoved,
    required this.title,
    this.description,
    required this.storageService,
    required this.uploadId,
    this.disabled = false,
    this.customUploadFunction,
  });

  @override
  State<ImageUploadSection> createState() => _ImageUploadSectionState();
}

class _ImageUploadSectionState extends State<ImageUploadSection> {
  Future<void> _pickAndUploadImages() async {
    if (widget.disabled) return;
    
    List<String> urls;
    if (widget.customUploadFunction != null) {
      urls = await widget.customUploadFunction!();
    } else {
      urls = await widget.storageService.pickAndUploadPostImages(
        postId: widget.uploadId,
      );
    }
    
    if (urls.isNotEmpty && mounted) {
      widget.onImagesAdded(urls);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attachment, size: 20, color: const Color(0xFF00C8A0)),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
        if (widget.description != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.description!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 16),
        
        if (widget.images.isEmpty)
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No images added',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8,
              mainAxisExtent: 100,
            ),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final url = widget.images[index];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.broken_image, color: Colors.grey[400]),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: InkWell(
                        onTap: widget.disabled
                            ? null
                            : () => widget.onImageRemoved(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        
        const SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.disabled ? null : _pickAndUploadImages,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00C8A0),
              side: const BorderSide(color: Color(0xFF00C8A0)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add_photo_alternate, size: 20),
            label: const Text(
              'Add Images',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

