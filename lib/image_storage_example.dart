// Example demonstrating the new expense images storage system

import 'package:flutter/material.dart';
import 'user_service.dart';

class ImageStorageExample extends StatefulWidget {
  final String callRequestId;

  const ImageStorageExample({super.key, required this.callRequestId});

  @override
  State<ImageStorageExample> createState() => _ImageStorageExampleState();
}

class _ImageStorageExampleState extends State<ImageStorageExample> {
  List<String> receiptImages = [];
  List<String> reportImages = [];
  Map<String, dynamic> imageStats = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      // Load receipt images
      final receipts = await UserService.getExpenseImages(
        callRequestId: widget.callRequestId,
        imageType: 'receipt',
      );

      // Load report images
      final reports = await UserService.getExpenseImages(
        callRequestId: widget.callRequestId,
        imageType: 'report',
      );

      // Get image statistics for receipt images
      final stats = await UserService.getImageStatistics(
        callRequestId: widget.callRequestId,
        imageType: 'receipt',
      );

      setState(() {
        receiptImages = receipts;
        reportImages = reports;
        imageStats = stats;
      });
    } catch (e) {
      print('Error loading images: $e');
    }
  }

  Future<void> _storeExampleImages() async {
    // Example: Store multiple receipt images
    final exampleReceiptImages = [
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
    ];

    await UserService.storeExpenseImages(
      callRequestId: widget.callRequestId,
      imageBase64List: exampleReceiptImages,
      imageType: 'receipt',
    );

    // Example: Store report image
    final exampleReportImage = [
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
    ];

    await UserService.storeExpenseImages(
      callRequestId: widget.callRequestId,
      imageBase64List: exampleReportImage,
      imageType: 'report',
    );

    // Reload images
    _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Storage Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _storeExampleImages,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Image Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Total Images: ${imageStats['totalImages'] ?? 0}'),
                    Text(
                      'Total Documents: ${imageStats['totalDocuments'] ?? 0}',
                    ),
                    Text('Image Type: ${imageStats['imageType'] ?? 'None'}'),
                    Text(
                      'Estimated Size: ${(imageStats['estimatedSize'] ?? 0) / 1024} KB',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Receipt Images Section
            const Text(
              'Receipt Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            receiptImages.isEmpty
                ? const Text('No receipt images found')
                : SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: receiptImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('Receipt ${index + 1}')),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),

            // Report Images Section
            const Text(
              'Report Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            reportImages.isEmpty
                ? const Text('No report images found')
                : SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: reportImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('Report ${index + 1}')),
                        );
                      },
                    ),
                  ),

            const SizedBox(height: 32),

            // How it works explanation
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How the System Works:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Images are stored in a separate "expense_images" collection',
                    ),
                    Text(
                      '• Each document uses the same ID as the call_request',
                    ),
                    Text(
                      '• If images exceed 800KB, they\'re split across multiple documents',
                    ),
                    Text(
                      '• Documents are named: callRequestId, callRequestId_1, callRequestId_2, etc.',
                    ),
                    Text(
                      '• Images are categorized by type: "receipt" or "report"',
                    ),
                    Text(
                      '• Main call_request documents no longer store image data',
                    ),
                    Text('• Use helper methods to load images when needed'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
