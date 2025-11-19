import 'dart:convert';
import 'dart:typed_data';

class ImageHelper {
  /// Converts image data (either data URL or legacy base64) to bytes
  static Uint8List getImageBytes(String imageData) {
    if (imageData.startsWith('data:')) {
      // Data URL format: data:image/png;base64,xxxxx
      final base64String = imageData.split(',')[1];
      return base64Decode(base64String);
    } else {
      // Legacy base64 string
      return base64Decode(imageData);
    }
  }

  /// Creates a data URL from image bytes and file name
  static String createDataUrl(Uint8List bytes, String fileName) {
    try {
      final base64String = base64Encode(bytes);

      // Determine MIME type from file extension
      final fileExtension = fileName.split('.').last.toLowerCase();
      String mimeType = 'image/png'; // default
      if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (fileExtension == 'gif') {
        mimeType = 'image/gif';
      } else if (fileExtension == 'webp') {
        mimeType = 'image/webp';
      }

      final dataUrl = 'data:$mimeType;base64,$base64String';
      return dataUrl;
    } catch (e) {
      // If there's any error, return a placeholder
      throw Exception('Failed to create data URL: $e');
    }
  }
}
