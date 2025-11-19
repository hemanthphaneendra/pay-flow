import 'package:flutter/material.dart';
import 'widgets/image_upload.dart';
import 'user_service.dart';

class CompleteCallRequestPage extends StatefulWidget {
  final CallRequest callRequest;
  final void Function(String? reportScreenshotUrl, bool sent) onComplete;
  final bool forceProof;
  final bool isUploadingToCompleted;

  const CompleteCallRequestPage({
    super.key,
    required this.callRequest,
    required this.onComplete,
    this.forceProof = false,
    this.isUploadingToCompleted = false,
  });

  @override
  State<CompleteCallRequestPage> createState() =>
      _CompleteCallRequestPageState();
}

class _CompleteCallRequestPageState extends State<CompleteCallRequestPage> {
  bool _sentReport = false;
  String? _reportScreenshotUrl;
  bool _saving = false;
  bool _loadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadExistingReport();
  }

  Future<void> _loadExistingReport() async {
    if (widget.isUploadingToCompleted) {
      try {
        // Load existing report images
        final reportImages = await UserService.getExpenseImages(
          callRequestId: widget.callRequest.id,
          imageType: 'report',
        );

        if (reportImages.isNotEmpty) {
          _reportScreenshotUrl = reportImages.first;
        }
      } catch (e) {
        print('Error loading existing report: $e');
      }
    }

    setState(() {
      _loadingImages = false;
    });
  }

  void _onImageUploaded(String url) {
    setState(() {
      _reportScreenshotUrl = url;
    });
  }

  Future<void> _onSubmit() async {
    setState(() => _saving = true);
    widget.onComplete(_reportScreenshotUrl, _sentReport);
    if (mounted) {
      // For upload to completed calls, pop with success result
      if (widget.isUploadingToCompleted && _reportScreenshotUrl != null) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isUploadingToCompleted
              ? 'Upload Report'
              : 'Complete Call Request',
        ),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _loadingImages
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading existing report...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isUploadingToCompleted
                        ? 'Upload report for this completed call:'
                        : 'Did you send the report to the customer?',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (widget.isUploadingToCompleted) ...[
                    const SizedBox(height: 16),
                    ImageUpload(
                      initialBase64: _reportScreenshotUrl,
                      onImageUploaded: _onImageUploaded,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _sentReport,
                          onChanged: (val) =>
                              setState(() => _sentReport = true),
                        ),
                        const Text('Yes'),
                        const SizedBox(width: 24),
                        Radio<bool>(
                          value: false,
                          groupValue: _sentReport,
                          onChanged: (val) =>
                              setState(() => _sentReport = false),
                        ),
                        const Text('Not yet'),
                      ],
                    ),
                    if (_sentReport || widget.forceProof) ...[
                      const SizedBox(height: 16),
                      const Text('Upload screenshot of sent report:'),
                      ImageUpload(
                        initialBase64: _reportScreenshotUrl,
                        onImageUploaded: _onImageUploaded,
                      ),
                    ],
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed:
                            (_saving ||
                                ((widget.forceProof ||
                                        widget.isUploadingToCompleted) &&
                                    (_reportScreenshotUrl == null ||
                                        _reportScreenshotUrl!.isEmpty)))
                            ? null
                            : _onSubmit,
                        child: Text(
                          widget.isUploadingToCompleted
                              ? 'Upload Report'
                              : ((_sentReport || widget.forceProof)
                                    ? 'Complete'
                                    : 'Mark as Pending Report'),
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
