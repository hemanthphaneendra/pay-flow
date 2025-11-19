import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'user_service.dart';
import 'helpers/image_helper.dart';
// Conditional import for web
import 'dart:html' as html show AnchorElement, Blob, Url if (dart.library.io) '';

class CallViewPage extends StatefulWidget {
  final CallRequest callRequest;
  const CallViewPage({super.key, required this.callRequest});

  @override
  State<CallViewPage> createState() => _CallViewPageState();
}

class _CallViewPageState extends State<CallViewPage> {
  List<String> reportImages = [];
  List<String> receiptImages = [];
  List<Expense> expensesWithReceipts = [];
  bool isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      print('DEBUG: Loading images for call ${widget.callRequest.id} with status ${widget.callRequest.status.name}');
      
      // Load report images
      final reports = await UserService.getExpenseImages(
        callRequestId: widget.callRequest.id,
        imageType: 'report',
      );
      print('DEBUG: Found ${reports.length} report images');

      // Load receipt images
      final receipts = await UserService.getExpenseImages(
        callRequestId: widget.callRequest.id,
        imageType: 'receipt',
      );
      print('DEBUG: Found ${receipts.length} receipt images');
      print('DEBUG: Call has ${widget.callRequest.expenses.length} expenses');

      // Create expenses with receipt images
      final expensesWithImages = <Expense>[];
      for (int i = 0; i < widget.callRequest.expenses.length; i++) {
        final expense = widget.callRequest.expenses[i];
        final receiptBase64 = i < receipts.length ? receipts[i] : null;
        
        expensesWithImages.add(Expense(
          id: expense.id,
          type: expense.type,
          amount: expense.amount,
          description: expense.description,
          date: expense.date,
          receiptBase64: receiptBase64,
        ));
      }

      print('DEBUG: Created ${expensesWithImages.length} expenses with receipts');
      print('DEBUG: Expenses with receipt images: ${expensesWithImages.where((e) => e.receiptBase64 != null).length}');

      setState(() {
        reportImages = reports;
        receiptImages = receipts;
        expensesWithReceipts = expensesWithImages;
        isLoadingImages = false;
      });
    } catch (e) {
      print('Error loading images: $e');
      setState(() {
        isLoadingImages = false;
      });
    }
  }

  // Helper to format timestamps
  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return timestamp.toString();
      }
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp.toString();
    }
  }

  // Helper to download individual images
  Future<void> _downloadImage(BuildContext context, String base64String, String fileName) async {
    try {
      // Remove data URL prefix if present
      String cleanBase64 = base64String;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      
      final bytes = base64Decode(cleanBase64);
      
      if (kIsWeb) {
        // Web download
        final blob = html.Blob([bytes], 'image/jpeg');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image "$fileName" downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // For mobile/desktop - show message that feature is web-optimized
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image download is optimized for web. Use the main PDF download for mobile/desktop.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error downloading image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Generate and download PDF
  Future<void> _generatePDF(BuildContext context) async {
    final pdf = pw.Document();
    
    // Format date helper
    String formatDate(DateTime date) {
      return '${date.day}/${date.month}/${date.year}';
    }
    
    // Convert base64 image if exists
    pw.ImageProvider? reportImage;
    if (reportImages.isNotEmpty) {
      try {
        String base64String = reportImages.first;
        // Remove data URL prefix if present
        if (base64String.startsWith('data:')) {
          base64String = base64String.split(',')[1];
        }
        final bytes = base64Decode(base64String);
        reportImage = pw.MemoryImage(bytes);
      } catch (e) {
        print('Error decoding report image: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title
            pw.Text(
              'Call Request Details',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Main Card Container (matching the UI exactly)
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with customer name and status (matching Row layout)
                  pw.Row(
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: pw.Text('Customer:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          widget.callRequest.customerName,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: _getPdfStatusColor(widget.callRequest.status),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                        ),
                        child: pw.Text(
                          widget.callRequest.status.name.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  
                  // Details matching _detailRow format exactly
                  _buildPdfDetailRow('Requested By', widget.callRequest.requestedBy),
                  _buildPdfDetailRow('Call Period', '${widget.callRequest.callFromDate} - ${widget.callRequest.callToDate}'),
                  _buildPdfDetailRow('Duration', widget.callRequest.durationText),
                  _buildPdfDetailRow('Requested Amount', 'Rs. ${widget.callRequest.requestedAmount.toStringAsFixed(2)}'),
                  
                  if (widget.callRequest.approvedAmount != null)
                    _buildPdfDetailRow('Approved Amount', 'Rs. ${widget.callRequest.approvedAmount!.toStringAsFixed(2)}'),
                  
                  if (widget.callRequest.approvedAmount != null && widget.callRequest.approvedAmount != widget.callRequest.requestedAmount)
                    _buildPdfDetailRow('Manager Modified Amount', 'Rs. ${widget.callRequest.requestedAmount.toStringAsFixed(2)} → Rs. ${widget.callRequest.approvedAmount!.toStringAsFixed(2)}'),
                  
                  _buildPdfDetailRow('Notes', widget.callRequest.notes),
                  
                  if (widget.callRequest.rejectionReason != null)
                    _buildPdfDetailRow('Rejection Reason', widget.callRequest.rejectionReason!),
                  
                  _buildPdfDetailRow('Created At', widget.callRequest.createdAt.toString()),
                  
                  if (widget.callRequest.approvedAt != null)
                    _buildPdfDetailRow('Manager Approved At', widget.callRequest.approvedAt.toString()),
                  
                  if (widget.callRequest.approvedBy != null)
                    _buildPdfDetailRow('Manager Approved By', widget.callRequest.approvedBy!),
                  
                  if (widget.callRequest.creditedAt != null)
                    _buildPdfDetailRow('Credited At', widget.callRequest.creditedAt.toString()),
                  
                  if (widget.callRequest.creditedBy != null)
                    _buildPdfDetailRow('Credited By', widget.callRequest.creditedBy!),
                  
                  _buildPdfDetailRow('Is Credited', widget.callRequest.isCredited ? 'Yes' : 'No'),
                ],
              ),
            ),
            
            // Additional Expense Request Section (if exists)
            if (widget.callRequest.additionalExpenseRequest != null) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Additional Expense Request',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    _buildPdfDetailRow('Amount', 'Rs. ${(widget.callRequest.additionalExpenseRequest!['amount'] ?? 0).toStringAsFixed(2)}'),
                    _buildPdfDetailRow('Description', widget.callRequest.additionalExpenseRequest!['description']?.toString() ?? 'N/A'),
                    _buildPdfDetailRow('Status', (widget.callRequest.additionalExpenseRequest!['status']?.toString() ?? 'pending').toUpperCase()),
                    if (widget.callRequest.additionalExpenseRequest!['requestedAt'] != null)
                      _buildPdfDetailRow('Requested On', formatTimestamp(widget.callRequest.additionalExpenseRequest!['requestedAt'])),
                    if (widget.callRequest.additionalExpenseRequest!['status'] == 'approved' && widget.callRequest.additionalExpenseRequest!['approvedAt'] != null)
                      _buildPdfDetailRow('Approved On', formatTimestamp(widget.callRequest.additionalExpenseRequest!['approvedAt'])),
                    if (widget.callRequest.additionalExpenseRequest!['status'] == 'rejected' && widget.callRequest.additionalExpenseRequest!['rejectedAt'] != null)
                      _buildPdfDetailRow('Rejected On', formatTimestamp(widget.callRequest.additionalExpenseRequest!['rejectedAt'])),
                  ],
                ),
              ),
            ],
            
            // Duration Extensions Section (if exists)
            if (widget.callRequest.durationExtensionHistory != null && widget.callRequest.durationExtensionHistory!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Duration Extensions',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    ...widget.callRequest.durationExtensionHistory!.map((extension) =>
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildPdfDetailRow('Extended On', formatTimestamp(extension['extendedAt'])),
                            _buildPdfDetailRow('From Date', formatTimestamp(extension['previousToDate'])),
                            _buildPdfDetailRow('To Date', formatTimestamp(extension['newToDate'])),
                            _buildPdfDetailRow('Days Added', '${extension['daysAdded'] ?? 0} days'),
                            if (extension['reason'] != null && extension['reason'].toString().isNotEmpty)
                              _buildPdfDetailRow('Reason', extension['reason'].toString()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            

            
            // Expenses Section
            if (expensesWithReceipts.isNotEmpty) ...[              
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Expenses',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    ...expensesWithReceipts.map((expense) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                expense.type.name.toUpperCase(),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800,
                                ),
                              ),
                              pw.Text(
                                'Rs. ${expense.amount.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (expense.description.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              expense.description,
                              style: pw.TextStyle(
                                color: PdfColors.grey700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          pw.SizedBox(height: 4),
                          pw.Text(
                            formatDate(expense.date),
                            style: pw.TextStyle(
                              color: PdfColors.grey600,
                              fontSize: 10,
                            ),
                          ),
                          // Add receipt image if available
                          if (expense.receiptBase64 != null && expense.receiptBase64!.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Receipt:',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Expanded(
                                  child: () {
                                    try {
                                      String base64String = expense.receiptBase64!;
                                      // Remove data URL prefix if present
                                      if (base64String.startsWith('data:')) {
                                        base64String = base64String.split(',')[1];
                                      }
                                      final bytes = base64Decode(base64String);
                                      return pw.Container(
                                        constraints: const pw.BoxConstraints(
                                          maxHeight: 150,
                                          maxWidth: 200,
                                        ),
                                        decoration: pw.BoxDecoration(
                                          border: pw.Border.all(color: PdfColors.grey300),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                        ),
                                        child: pw.Image(
                                          pw.MemoryImage(bytes),
                                          fit: pw.BoxFit.contain,
                                        ),
                                      );
                                    } catch (e) {
                                      return pw.Container(
                                        height: 60,
                                        width: 100,
                                        decoration: pw.BoxDecoration(
                                          border: pw.Border.all(color: PdfColors.grey300),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                        ),
                                        child: pw.Center(
                                          child: pw.Text(
                                            'Receipt Image',
                                            style: pw.TextStyle(
                                              fontSize: 8,
                                              color: PdfColors.grey600,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Expenses:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          pw.Text(
                            'Rs. ${expensesWithReceipts.fold(0.0, (total, e) => total + e.amount).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Report Image Section (if exists)
            if (reportImage != null) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Report Screenshot',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Center(
                      child: pw.Container(
                        constraints: const pw.BoxConstraints(
                          maxHeight: 400,
                          maxWidth: 400,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Image(reportImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    // Generate PDF and handle download based on platform
    final pdfBytes = await pdf.save();
    final fileName = 'Call_Request_${widget.callRequest.customerName}_${formatDate(widget.callRequest.createdAt)}.pdf';
    
    try {
      if (kIsWeb) {
        // Web download using dart:html
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // For mobile/desktop platforms
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: fileName,
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to build PDF detail rows (matching _detailRow style)
  pw.Widget _buildPdfDetailRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(color: PdfColors.grey800),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get PDF status color
  PdfColor _getPdfStatusColor(CallRequestStatus status) {
    switch (status) {
      case CallRequestStatus.pendingApproval:
        return PdfColors.orange;
      case CallRequestStatus.approved:
        return PdfColors.green;
      case CallRequestStatus.rejected:
        return PdfColors.red;
      case CallRequestStatus.pendingCredit:
        return PdfColors.blue;
      case CallRequestStatus.draft:
        return PdfColors.grey;
      case CallRequestStatus.completed:
      case CallRequestStatus.pendingReport:
        return PdfColors.green700;
      case CallRequestStatus.poPending:
        return PdfColors.purple;
      case CallRequestStatus.pendingInvoice:
        return PdfColors.orange700;
      case CallRequestStatus.invoiceCreated:
        return PdfColors.blue700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Request Details'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: isLoadingImages 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading images...'),
              ],
            ),
          )
        : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        widget.callRequest.customerName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          widget.callRequest.status.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: _statusColor(widget.callRequest.status),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow('Requested By', widget.callRequest.requestedBy),
                  _detailRow(
                    'Call Period',
                    '${widget.callRequest.callFromDate} - ${widget.callRequest.callToDate}',
                  ),
                  _detailRow('Duration', widget.callRequest.durationText),
                  _detailRow(
                    'Requested Amount',
                    '₹${widget.callRequest.requestedAmount.toStringAsFixed(2)}',
                  ),
                  if (widget.callRequest.approvedAmount != null)
                    _detailRow(
                      'Approved Amount',
                      '₹${widget.callRequest.approvedAmount!.toStringAsFixed(2)}',
                    ),
                  if (widget.callRequest.approvedAmount != null &&
                      widget.callRequest.approvedAmount != widget.callRequest.requestedAmount)
                    _detailRow(
                      'Manager Modified Amount',
                      '₹${widget.callRequest.requestedAmount.toStringAsFixed(2)} → ₹${widget.callRequest.approvedAmount!.toStringAsFixed(2)}',
                    ),
                  _detailRow('Notes', widget.callRequest.notes),
                  if (widget.callRequest.rejectionReason != null)
                    _detailRow(
                      'Rejection Reason',
                      widget.callRequest.rejectionReason!,
                    ),
                  _detailRow('Created At', widget.callRequest.createdAt.toString()),
                  if (widget.callRequest.approvedAt != null)
                    _detailRow(
                      'Manager Approved At',
                      widget.callRequest.approvedAt.toString(),
                    ),
                  if (widget.callRequest.approvedBy != null)
                    _detailRow('Manager Approved By', widget.callRequest.approvedBy!),
                  if (widget.callRequest.creditedAt != null)
                    _detailRow(
                      'Credited At',
                      widget.callRequest.creditedAt.toString(),
                    ),
                  if (widget.callRequest.creditedBy != null)
                    _detailRow('Credited By',widget.callRequest.creditedBy!),
                  _detailRow(
                    'Is Credited',
                    widget.callRequest.isCredited ? 'Yes' : 'No',
                  ),
                  // Additional Expense Request Details
                  if (widget.callRequest.additionalExpenseRequest != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Expense Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _detailRow(
                            'Additional Amount',
                            '₹${(widget.callRequest.additionalExpenseRequest!['amount'] ?? 0).toDouble().toStringAsFixed(2)}',
                          ),
                          _detailRow(
                            'Reason',
                            widget.callRequest.additionalExpenseRequest!['reason'] ??
                                'No reason provided',
                          ),
                          _detailRow(
                            'Requested By',
                            widget.callRequest
                                    .additionalExpenseRequest!['requestedBy'] ??
                                'Unknown',
                          ),
                          if (widget.callRequest
                                  .additionalExpenseRequest!['requestedAt'] !=
                              null)
                            _detailRow(
                              'Requested At',
                              (widget.callRequest.additionalExpenseRequest!['requestedAt']
                                      as Timestamp)
                                  .toDate()
                                  .toString(),
                            ),
                          // Show main call's manager approval details
                          if (widget.callRequest.approvedBy != null) ...[
                            _detailRow(
                              'Manager Approved By',
                              widget.callRequest.approvedBy!,
                            ),
                          ],
                          if (widget.callRequest.approvedAt != null) ...[
                            _detailRow(
                              'Manager Approved At',
                              widget.callRequest.approvedAt.toString(),
                            ),
                          ],
                          // Show additional expense specific approval details
                          if (widget.callRequest
                                  .additionalExpenseRequest!['approvedBy'] !=
                              null) ...[
                            _detailRow(
                              'Additional Expense Approved By',
                              widget.callRequest
                                  .additionalExpenseRequest!['approvedBy'],
                            ),
                            if (widget.callRequest
                                    .additionalExpenseRequest!['approvedAt'] !=
                                null)
                              _detailRow(
                                'Additional Expense Approved At',
                                (widget.callRequest.additionalExpenseRequest!['approvedAt']
                                        as Timestamp)
                                    .toDate()
                                    .toString(),
                              ),
                            if (widget.callRequest
                                    .additionalExpenseRequest!['rejectionReason'] !=
                                null)
                              _detailRow(
                                'Rejection Reason',
                                widget.callRequest
                                    .additionalExpenseRequest!['rejectionReason'],
                              ),
                          ],
                          // Show additional expense specific credit information
                          if (widget.callRequest
                                  .additionalExpenseRequest!['creditedAt'] !=
                              null) ...[
                            _detailRow(
                              'Additional Expense Credited At',
                              (widget.callRequest.additionalExpenseRequest!['creditedAt']
                                      as Timestamp)
                                  .toDate()
                                  .toString(),
                            ),
                          ],
                          if (widget.callRequest
                                  .additionalExpenseRequest!['creditedBy'] !=
                              null) ...[
                            _detailRow(
                              'Additional Expense Credited By',
                              widget.callRequest
                                  .additionalExpenseRequest!['creditedBy'],
                            ),
                          ],
                          // Show total amount (initial + additional)
                          _detailRow(
                            'Total Amount',
                            '₹${widget.callRequest.finalAmount.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Due Date Extension Request Details
                  if (widget.callRequest.dueDateExtensionRequest != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due Date Extension Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.callRequest
                                  .dueDateExtensionRequest!['newDueDate'] !=
                              null)
                            _detailRow(
                              'Requested Due Date',
                              (widget.callRequest.dueDateExtensionRequest!['newDueDate']
                                      as Timestamp)
                                  .toDate()
                                  .toString(),
                            ),
                          _detailRow(
                            'Reason',
                            widget.callRequest.dueDateExtensionRequest!['reason'] ??
                                'No reason provided',
                          ),
                          _detailRow(
                            'Requested By',
                            widget.callRequest
                                    .dueDateExtensionRequest!['requestedBy'] ??
                                'Unknown',
                          ),
                          if (widget.callRequest
                                  .dueDateExtensionRequest!['requestedAt'] !=
                              null)
                            _detailRow(
                              'Requested At',
                              (widget.callRequest.dueDateExtensionRequest!['requestedAt']
                                      as Timestamp)
                                  .toDate()
                                  .toString(),
                            ),
                          _detailRow(
                            'Status',
                            (widget.callRequest.dueDateExtensionRequest!['status'] ??
                                    'pending')
                                .toString()
                                .toUpperCase(),
                          ),
                          if (widget.callRequest
                                  .dueDateExtensionRequest!['respondedBy'] !=
                              null) ...[
                            _detailRow(
                              'Responded By',
                              widget.callRequest
                                  .dueDateExtensionRequest!['respondedBy'],
                            ),
                            if (widget.callRequest
                                    .dueDateExtensionRequest!['respondedAt'] !=
                                null)
                              _detailRow(
                                'Responded At',
                                (widget.callRequest.dueDateExtensionRequest!['respondedAt']
                                        as Timestamp)
                                    .toDate()
                                    .toString(),
                              ),
                            if (widget.callRequest
                                    .dueDateExtensionRequest!['rejectionReason'] !=
                                null)
                              _detailRow(
                                'Rejection Reason',
                                widget.callRequest
                                    .dueDateExtensionRequest!['rejectionReason'],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Duration Extension History
                  if (widget.callRequest.durationExtensionHistory != null &&
                      widget.callRequest.durationExtensionHistory!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Call Duration Extension History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.callRequest.durationExtensionHistory!
                              .map(
                                (extension) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.teal.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (extension['previousEndDate'] != null)
                                        _detailRow(
                                          'Previous End Date',
                                          (extension['previousEndDate']
                                                  as Timestamp)
                                              .toDate()
                                              .toString()
                                              .split(
                                                ' ',
                                              )[0], // Show only date part
                                        ),
                                      if (extension['newEndDate'] != null)
                                        _detailRow(
                                          'Extended to',
                                          (extension['newEndDate'] as Timestamp)
                                              .toDate()
                                              .toString()
                                              .split(
                                                ' ',
                                              )[0], // Show only date part
                                        ),
                                      _detailRow(
                                        'Reason',
                                        extension['reason'] ??
                                            'No reason provided',
                                      ),
                                      _detailRow(
                                        'Extended By',
                                        extension['extendedBy'] ?? 'Unknown',
                                      ),
                                      if (extension['extendedAt'] != null)
                                        _detailRow(
                                          'Extended At',
                                          (extension['extendedAt'] as Timestamp)
                                              .toDate()
                                              .toString(),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),
                  ],
                  if (widget.callRequest.poNumber != null &&
                      widget.callRequest.poNumber!.isNotEmpty)
                    _detailRow('PO Number', widget.callRequest.poNumber!),
                  if (widget.callRequest.piNumber != null &&
                      widget.callRequest.piNumber!.isNotEmpty)
                    _detailRow('PI Number', widget.callRequest.piNumber!),
                ],
              ),
            ),
          ),
          if (expensesWithReceipts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Expenses',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ...expensesWithReceipts.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.type.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₹${e.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  Text(
                                    e.description,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${e.date}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (e.receiptBase64 != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  children: [
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.memory(
                                                  ImageHelper.getImageBytes(
                                                    e.receiptBase64!,
                                                  ),
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.red,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            ImageHelper.getImageBytes(
                                              e.receiptBase64!,
                                            ),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.red,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    IconButton(
                                      icon: const Icon(Icons.download, size: 16),
                                      tooltip: 'Download Receipt',
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _downloadImage(
                                        context,
                                        e.receiptBase64!,
                                        'Receipt_${e.description}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (reportImages.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Report Screenshots (${reportImages.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Display all report images
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: reportImages.asMap().entries.map((entry) {
                        final index = entry.key;
                        final imageBase64 = entry.value;
                        
                        return Container(
                          width: 150,
                          child: Column(
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: InteractiveViewer(
                                          child: Image.memory(
                                            ImageHelper.getImageBytes(imageBase64),
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.red,
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      ImageHelper.getImageBytes(imageBase64),
                                      height: 120,
                                      width: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(
                                            Icons.broken_image,
                                            color: Colors.red,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Image ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download, size: 16),
                                    tooltip: 'Download Image',
                                    onPressed: () => _downloadImage(
                                      context,
                                      imageBase64,
                                      'Report_Screenshot_${index + 1}_${widget.callRequest.customerName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Follow Ups Card
          if (widget.callRequest.followUps.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.forum, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Follow Ups',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Table for call follow-ups
                    if (widget.callRequest.followUps.any((f) => f['type'] != 'email'))
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Who Called')),
                            DataColumn(label: Text('Whom Called')),
                            DataColumn(label: Text('Notes')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Due Date')),
                            DataColumn(label: Text('PO Received')),
                            DataColumn(label: Text('By')),
                          ],
                          rows: widget.callRequest.followUps
                              .asMap()
                              .entries
                              .where((entry) => entry.value['type'] != 'email')
                              .map((entry) {
                                final followUp = entry.value;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(followUp['whoCalled'] ?? '-'),
                                    ),
                                    DataCell(
                                      Text(followUp['whomCalled'] ?? '-'),
                                    ),
                                    DataCell(Text(followUp['notes'] ?? '-')),
                                    DataCell(Text(followUp['date'] ?? '-')),
                                    DataCell(Text(followUp['dueDate'] ?? '-')),
                                    DataCell(
                                      followUp['poReceived'] == true
                                          ? Text(
                                              'Yes\n${followUp['poNumber'] ?? ''}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                              ),
                                            )
                                          : const Text('No'),
                                    ),
                                    DataCell(
                                      Text(followUp['createdBy'] ?? '-'),
                                    ),
                                  ],
                                );
                              })
                              .toList(),
                        ),
                      ),
                    // Cards for email follow-ups
                    ...widget.callRequest.followUps
                        .asMap()
                        .entries
                        .where((entry) => entry.value['type'] == 'email')
                        .map((entry) {
                          final idx = entry.key;
                          final followUp = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      color: Colors.orange.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Email Follow Up #${idx + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('To: ${followUp['recipient'] ?? '-'}'),
                                Text('Subject: ${followUp['subject'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text(
                                  followUp['body'] ?? '-',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sent: ${followUp['sentAt'] ?? followUp['createdAt'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'By: ${followUp['createdBy'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(CallRequestStatus status) {
    switch (status) {
      case CallRequestStatus.pendingApproval:
        return Colors.orange.shade700;
      case CallRequestStatus.approved:
        return Colors.blue.shade700;
      case CallRequestStatus.rejected:
        return Colors.red.shade700;
      case CallRequestStatus.pendingCredit:
        return Colors.purple.shade700;
      case CallRequestStatus.draft:
        return Colors.grey.shade600;
      case CallRequestStatus.pendingReport:
        return Colors.amber.shade800;
      case CallRequestStatus.completed:
        return Colors.green.shade700;
      case CallRequestStatus.poPending:
        return Colors.brown.shade700;
      case CallRequestStatus.pendingInvoice:
        return Colors.indigo.shade700;
      case CallRequestStatus.invoiceCreated:
        return Colors.cyan.shade700;
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
