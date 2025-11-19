import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../helpers/image_helper.dart';

class ImageUpload extends StatefulWidget {
  final String? initialBase64;
  final void Function(String base64) onImageUploaded;

  const ImageUpload({
    super.key,
    this.initialBase64,
    required this.onImageUploaded,
  });

  @override
  State<ImageUpload> createState() => _ImageUploadState();
}

class _ImageUploadState extends State<ImageUpload> {
  String? _imageBase64;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.initialBase64;
  }

  @override
  void didUpdateWidget(ImageUpload oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the image when initialBase64 changes
    if (widget.initialBase64 != oldWidget.initialBase64) {
      _imageBase64 = widget.initialBase64;
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // More aggressive: smaller resolution
      maxHeight: 800, // More aggressive: smaller resolution
      imageQuality: 60, // More aggressive: lower quality
    );
    if (picked == null) return;
    setState(() => _uploading = true);

    try {
      final bytes = await picked.readAsBytes();
      final dataUrl = ImageHelper.createDataUrl(bytes, picked.name);

      setState(() {
        _imageBase64 = dataUrl;
        _uploading = false;
      });
      widget.onImageUploaded(_imageBase64!);
    } catch (e) {
      setState(() => _uploading = false);
      // Show error to user instead of silent failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _imageBase64 != null
            ? Image.memory(
                ImageHelper.getImageBytes(_imageBase64!),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.red),
              )
            : const Text('No image'),
        const SizedBox(width: 8),
        _uploading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Upload Image',
                onPressed: _pickAndUploadImage,
              ),
      ],
    );
  }
}
