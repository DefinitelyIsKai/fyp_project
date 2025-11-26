import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/user/storage_service.dart';
import '../../utils/user/dialog_utils.dart';

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
  
  /// Maximum number of images allowed (null for unlimited)
  final int? maxImages;

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
    this.maxImages,
  });

  @override
  State<ImageUploadSection> createState() => _ImageUploadSectionState();
}

class _ImageUploadSectionState extends State<ImageUploadSection> {
  bool _isUploading = false;

  /// Build widget to display base64 image
  Widget _buildBase64Image(String base64String) {
    try {
      // Clean the base64 string - remove any whitespace
      final cleanBase64 = base64String.trim().replaceAll(RegExp(r'\s+'), '');
      
      // Decode base64 to bytes
      final bytes = base64Decode(cleanBase64);
      
      // Use Image.memory to display the image
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('Error displaying base64 image: $error');
          return Container(
            color: Colors.grey[100],
            child: Icon(Icons.broken_image, color: Colors.grey[400]),
          );
        },
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      print('Base64 string length: ${base64String.length}');
      // Try as data URI as fallback
      try {
        return _buildDataUriImage('data:image/jpeg;base64,$base64String');
      } catch (e2) {
        return Container(
          color: Colors.grey[100],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
              const SizedBox(height: 4),
              Text(
                'Failed to load',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Build widget to display data URI image
  Widget _buildDataUriImage(String dataUri) {
    try {
      // Extract base64 part from data URI
      // Format: data:image/jpeg;base64,{base64String}
      final base64String = dataUri.split(',').length > 1 
          ? dataUri.split(',')[1] 
          : dataUri;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[100],
            child: Icon(Icons.broken_image, color: Colors.grey[400]),
          );
        },
      );
    } catch (e) {
      print('Error decoding data URI image: $e');
      // Fallback to Image.network
      return Image.network(
        dataUri,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[100],
            child: Icon(Icons.broken_image, color: Colors.grey[400]),
          );
        },
      );
    }
  }

  Future<void> _pickAndUploadImages() async {
    if (widget.disabled || _isUploading) return;
    
    // Check if we've reached the maximum number of images
    if (widget.maxImages != null && widget.images.length >= widget.maxImages!) {
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'You can only upload a maximum of ${widget.maxImages} images.',
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }
    
    // Set uploading state
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }
    
    try {
      List<String> urls;
      if (widget.customUploadFunction != null) {
        urls = await widget.customUploadFunction!();
      } else {
        // Only pick images and convert to base64, don't upload to Firestore yet
        urls = await widget.storageService.pickPostImages();
      }
      
      if (urls.isNotEmpty && mounted) {
        // Limit the number of images to add based on maxImages
        if (widget.maxImages != null) {
          final remainingSlots = widget.maxImages! - widget.images.length;
          if (remainingSlots > 0) {
            final imagesToAdd = urls.take(remainingSlots).toList();
            widget.onImagesAdded(imagesToAdd);
            
            // If user selected more images than allowed, show a message
            if (urls.length > remainingSlots && mounted) {
              DialogUtils.showWarningMessage(
                context: context,
                message: 'Only ${remainingSlots} image(s) were added. Maximum of ${widget.maxImages} images allowed.',
                duration: const Duration(seconds: 3),
              );
            }
          } else {
            if (mounted) {
              DialogUtils.showWarningMessage(
                context: context,
                message: 'You have reached the maximum of ${widget.maxImages} images. Please remove some before adding new ones.',
                duration: const Duration(seconds: 2),
              );
            }
          }
        } else {
          widget.onImagesAdded(urls);
        }
      } else if (urls.isEmpty && mounted) {
        // Show error if no images were uploaded
        if (mounted) {
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Failed to upload images. Please try again.',
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      // Show error message to user
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Error uploading images: ${e.toString()}',
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      // Reset uploading state
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
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
        if (widget.description != null || widget.maxImages != null) ...[
          const SizedBox(height: 12),
          if (widget.description != null)
            Text(
              widget.description!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          if (widget.maxImages != null) ...[
            if (widget.description != null) const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Maximum ${widget.maxImages} image${widget.maxImages == 1 ? '' : 's'} allowed',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (widget.images.isNotEmpty)
                  Text(
                    ' (${widget.images.length}/${widget.maxImages})',
                    style: TextStyle(
                      color: widget.images.length >= widget.maxImages! 
                          ? Colors.orange[700] 
                          : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
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
              final imageData = widget.images[index];
              
              // Check if it's a base64 string, HTTP URL, or data URI
              final bool isHttpUrl = imageData.startsWith('http://') || imageData.startsWith('https://');
              final bool isDataUri = imageData.startsWith('data:image/');
              
              // Base64 strings are typically long (hundreds to thousands of characters)
              // and contain only base64 characters: A-Z, a-z, 0-9, +, /, =
              // They don't start with http:// or data:
              final bool looksLikeBase64 = imageData.length > 100 && 
                  !isHttpUrl && 
                  !isDataUri &&
                  RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(imageData.trim());
              
              final bool isBase64 = looksLikeBase64 || (!isHttpUrl && !isDataUri && imageData.length > 50);
              
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
                      child: isBase64
                          ? _buildBase64Image(imageData)
                          : isDataUri
                              ? _buildDataUriImage(imageData)
                              : Image.network(
                                  imageData,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[100],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / 
                                                loadingProgress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
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
            onPressed: (widget.disabled || 
                        _isUploading ||
                        (widget.maxImages != null && widget.images.length >= widget.maxImages!))
                ? null 
                : _pickAndUploadImages,
            style: OutlinedButton.styleFrom(
              foregroundColor: (widget.maxImages != null && widget.images.length >= widget.maxImages!)
                  ? Colors.grey
                  : const Color(0xFF00C8A0),
              side: BorderSide(
                color: (widget.maxImages != null && widget.images.length >= widget.maxImages!)
                    ? Colors.grey
                    : const Color(0xFF00C8A0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C8A0)),
                    ),
                  )
                : Icon(
                    Icons.add_photo_alternate, 
                    size: 20,
                    color: (widget.maxImages != null && widget.images.length >= widget.maxImages!)
                        ? Colors.grey
                        : const Color(0xFF00C8A0),
                  ),
            label: Text(
              _isUploading
                  ? 'Uploading...'
                  : (widget.maxImages != null && widget.images.length >= widget.maxImages!
                      ? 'Maximum Reached (${widget.maxImages}/${widget.maxImages})'
                      : 'Add Images${widget.maxImages != null ? ' (${widget.images.length}/${widget.maxImages})' : ''}'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: (widget.maxImages != null && widget.images.length >= widget.maxImages!)
                    ? Colors.grey
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

