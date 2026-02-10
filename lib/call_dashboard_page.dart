import 'complete_call_request_page.dart';
import 'call_view_page.dart';
import 'package:flutter/material.dart';
import 'user_service.dart';
import 'call_form_page.dart';
import 'expense_editor_page.dart';

class CallDashboardPage extends StatefulWidget {
  final String username;

  const CallDashboardPage({super.key, required this.username});

  @override
  State<CallDashboardPage> createState() => _CallDashboardPageState();
}

class _CallDashboardPageState extends State<CallDashboardPage>
    with SingleTickerProviderStateMixin {
  bool _hasPendingRequests = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkPendingRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPendingRequests() async {
    final hasPending = await UserService.hasPendingCallRequests(
      widget.username,
    );
    setState(() {
      _hasPendingRequests = hasPending;
    });
  }

  Future<void> _navigateToCallForm() async {
    if (_hasPendingRequests) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You already have a pending call request. Please wait for it to be processed.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallFormPage(username: widget.username),
      ),
    );

    if (result == true) {
      _checkPendingRequests();
    }
  }

  // Show dialog for uploading report to completed calls
  void _showUploadReportDialog(CallRequest request) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CompleteCallRequestPage(
          callRequest: request,
          isUploadingToCompleted: true,
          onComplete: (reportScreenshotBase64, sent) async {
            if (reportScreenshotBase64 != null) {
              // Update the completed call with the report
              await UserService.updateCallReport(
                requestId: request.id,
                reportScreenshotBase64: reportScreenshotBase64,
              );
            }
          },
        ),
      ),
    );

    // Show feedback after returning to this page
    if (mounted && result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _showCompletionNotesDialog(CallRequest request) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: request.completionNotes ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            (request.completionNotes?.isNotEmpty ?? false)
                ? 'Update Completion Notes'
                : 'Add Completion Notes',
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Completion Notes',
                hintText: 'Add any context about this completed call',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter some notes';
                }
                if (value.trim().length < 5) {
                  return 'Please enter at least 5 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                try {
                  await UserService.updateCompletionNotes(
                    requestId: request.id,
                    notes: controller.text.trim(),
                    updatedBy: widget.username,
                  );
                  if (mounted) {
                    Navigator.of(dialogCtx).pop(true);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save notes: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (mounted && saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completion notes saved'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Show dialog for completing call request
  void _showCompleteCallDialog(CallRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Call Request'),
        content: const Text(
          'Do you have a report to upload? You can upload it now or add it later after marking the call as complete.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeCallWithReport(request);
            },
            child: const Text('Upload Report'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeCallWithoutReport(request);
            },
            child: const Text('Complete Without Report'),
          ),
        ],
      ),
    );
  }

  // Complete call with report upload
  void _completeCallWithReport(CallRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompleteCallRequestPage(
          callRequest: request,
          onComplete: (reportScreenshotBase64, sent) async {
            await UserService.completeCallRequest(
              requestId: request.id,
              sentReport: true,
              reportScreenshotBase64: reportScreenshotBase64,
            );
            setState(() {});
          },
        ),
      ),
    );
  }

  // Complete call without report
  void _completeCallWithoutReport(CallRequest request) async {
    try {
      await UserService.completeCallRequest(
        requestId: request.id,
        sentReport: false,
        reportScreenshotBase64: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Call request completed successfully. You can add report later if needed.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete call request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show dialog for requesting due date extension
  void _showDueDateExtensionDialog(CallRequest request) {
    final reasonController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Request Due Date Extension'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current due date: ${request.pendingReportDueDate != null ? _formatDateOnly(request.pendingReportDueDate!) : 'Not set'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  selectedDate != null
                      ? 'New due date: ${_formatDateOnly(selectedDate!)}'
                      : 'Select new due date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for extension',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  selectedDate != null &&
                      reasonController.text.trim().isNotEmpty
                  ? () async {
                      final success = await UserService.requestDueDateExtension(
                        callId: request.id,
                        newDueDate: selectedDate!,
                        reason: reasonController.text.trim(),
                        requestedBy: widget.username,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Due date extension requested successfully'
                                  : 'Failed to request extension',
                            ),
                            backgroundColor: success
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Request Extension'),
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog for extending call duration
  void _showDurationExtensionDialog(CallRequest request) {
    final reasonController = TextEditingController();
    DateTime? selectedEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Extend Call Duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current call period: ${_formatDateOnly(request.callFromDate)} - ${_formatDateOnly(request.callToDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  selectedEndDate != null
                      ? 'New end date: ${_formatDateOnly(selectedEndDate!)}'
                      : 'Select new end date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: request.callToDate.add(
                      const Duration(days: 1),
                    ),
                    firstDate: request.callToDate.add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedEndDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for extension',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  selectedEndDate != null &&
                      reasonController.text.trim().isNotEmpty
                  ? () async {
                      final success = await UserService.extendCallDuration(
                        callId: request.id,
                        newEndDate: selectedEndDate!,
                        reason: reasonController.text.trim(),
                        extendedBy: widget.username,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Call duration extended successfully'
                                  : 'Failed to extend call duration',
                            ),
                            backgroundColor: success
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Extend Duration'),
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog for requesting additional expenses
  void _showAdditionalExpenseDialog(CallRequest request) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Additional Expenses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current approved amount: ₹${_formatAmount(request.finalAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Additional amount needed',
                border: OutlineInputBorder(),
                prefixText: '₹',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for additional expenses',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              final reason = reasonController.text.trim();

              if (amount != null && amount > 0 && reason.isNotEmpty) {
                final success = await UserService.requestAdditionalExpenses(
                  callId: request.id,
                  additionalAmount: amount,
                  reason: reason,
                  requestedBy: widget.username,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Additional expense request submitted successfully'
                            : 'Failed to submit request',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid amount and reason'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  String _getStatusText(CallRequestStatus status) {
    switch (status) {
      case CallRequestStatus.pendingApproval:
        return 'Pending Approval';
      case CallRequestStatus.approved:
        return 'Approved';
      case CallRequestStatus.rejected:
        return 'Rejected';
      case CallRequestStatus.pendingCredit:
        return 'Pending Credit';
      case CallRequestStatus.draft:
        return 'Ongoing';

      case CallRequestStatus.completed:
      case CallRequestStatus.pendingReport:
        return 'Completed';
      case CallRequestStatus.poPending:
        return 'PO Pending';
      case CallRequestStatus.pendingInvoice:
        return 'Pending Invoice';
      case CallRequestStatus.invoiceCreated:
        return 'Invoice Created';
    }
  }

  Color _getStatusColor(CallRequestStatus status) {
    switch (status) {
      case CallRequestStatus.pendingApproval:
        return Colors.orange;
      case CallRequestStatus.approved:
        return Colors.green;
      case CallRequestStatus.rejected:
        return Colors.red;
      case CallRequestStatus.pendingCredit:
        return Colors.blue;
      case CallRequestStatus.draft:
        return Colors.purple;
      case CallRequestStatus.pendingReport:
      case CallRequestStatus.completed:
        return Colors.teal;
      case CallRequestStatus.poPending:
        return Colors.brown;
      case CallRequestStatus.pendingInvoice:
        return Colors.indigo;
      case CallRequestStatus.invoiceCreated:
        return Colors.cyan;
    }
  }

  Widget _buildCallRequestsTable(
    List<CallRequest> requests, {
    bool isPendingReport = false,
    bool isCompleted = false,
  }) {
    if (requests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_disabled, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No call requests found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use LayoutBuilder to make the table fill the available width
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height:
              MediaQuery.of(context).size.height *
              0.6, // Limit height for scrolling
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Table(
                  border: TableBorder.all(
                    color: Colors.grey.shade400,
                    width: 1,
                  ),
                  columnWidths: isCompleted
                      ? const <int, TableColumnWidth>{
                          0: FlexColumnWidth(2), // Customer
                          1: FlexColumnWidth(2), // Call Period
                          2: FlexColumnWidth(1), // Duration
                          3: FlexColumnWidth(1), // Amount
                          4: FlexColumnWidth(1), // Amount Spent
                          5: FlexColumnWidth(1.2), // Owes / Owed
                          6: FlexColumnWidth(2), // Expense Type & Amount
                          7: FlexColumnWidth(1), // Status
                          8: FlexColumnWidth(1), // Notes
                          9: FlexColumnWidth(2.5), // Actions (if exists)
                        }
                      : const <int, TableColumnWidth>{
                          0: FlexColumnWidth(2), // Customer
                          1: FlexColumnWidth(2), // Call Period
                          2: FlexColumnWidth(1), // Duration
                          3: FlexColumnWidth(1), // Amount
                          4: FlexColumnWidth(2), // Expense Type & Amount
                          5: FlexColumnWidth(1), // Status
                          6: FlexColumnWidth(1), // Notes
                          7: FlexColumnWidth(2.5), // Actions
                        },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Table header
                    TableRow(
                      decoration: BoxDecoration(color: Colors.blue.shade50),
                      children: [
                        _tableHeaderCell('Customer'),
                        _tableHeaderCell('Call Period'),
                        _tableHeaderCell('Duration'),
                        _tableHeaderCell('Amount'),
                        if (isCompleted) _tableHeaderCell('Amount Spent'),
                        if (isCompleted) _tableHeaderCell('Owes / Owed'),
                        _tableHeaderCell('Expense Type & Amount'),
                        _tableHeaderCell('Status'),

                        _tableHeaderCell('Notes'),
                        _tableHeaderCell('Actions'),
                      ],
                    ),
                    ...requests.map((request) {
                      final totalSpent = request.expenses.fold<double>(
                        0.0,
                        (sum, e) => sum + e.amount,
                      );
                      final settlementDiff = totalSpent - request.finalAmount;

                      return TableRow(
                        children: [
                          _tableCell(
                            Text(
                              request.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          _tableCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From: ${_formatDateOnly(request.callFromDate)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'To: ${_formatDateOnly(request.callToDate)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          _tableCell(
                            Text(
                              request.durationText,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _tableCell(
                            Text(
                              '₹${_formatAmount(request.finalAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCompleted)
                            _tableCell(
                              Text(
                                '₹${_formatAmount(totalSpent)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (isCompleted)
                            _tableCell(
                              _buildSettlementIndicator(settlementDiff),
                            ),
                          // Expense type & amount column (placeholder for now)
                          _tableCell(
                            request.expenses.isNotEmpty
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: request.expenses
                                        .map(
                                          (e) => Text(
                                            '${e.type.name}: ₹${_formatAmount(e.amount)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  )
                                : const Text(
                                    '-',
                                    style: TextStyle(fontSize: 13),
                                  ),
                          ),
                          _tableCell(
                            _buildStatusChip(request.status, request: request),
                          ),
                          // Due date column for pending report
                          if (isPendingReport)
                            _tableCell(_buildDueDateCell(request)),
                          _tableCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (request.notes.isNotEmpty)
                                  Text(
                                    request.notes,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                if (request.status ==
                                        CallRequestStatus.rejected &&
                                    request.rejectionReason != null) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'Rejected: ${request.rejectionReason}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                                if (request.approvedAmount != null &&
                                    request.approvedAmount !=
                                        request.requestedAmount) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'Modified: ₹${_formatAmount(request.requestedAmount)} → ₹${_formatAmount(request.approvedAmount!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Actions column
                          _tableCell(
                            SizedBox(
                              width: 300,
                              // Increased width to show more icons
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_red_eye,
                                        color: Colors.indigo,
                                      ),
                                      tooltip: 'View Details',
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CallViewPage(
                                              callRequest: request,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (request.status ==
                                            CallRequestStatus.draft ||
                                        request.status ==
                                            CallRequestStatus.approved) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Edit Expenses',
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ExpenseEditorPage(
                                                    callRequest: request,
                                                    onSave: (updatedExpenses) {
                                                      setState(() {
                                                        // Optionally update local state if needed
                                                      });
                                                    },
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Request additional expenses button
                                      IconButton(
                                        icon: Icon(
                                          Icons.attach_money,
                                          color:
                                              request.additionalExpenseRequest !=
                                                      null &&
                                                  request.additionalExpenseRequest!['status'] ==
                                                      'pending'
                                              ? Colors.grey
                                              : Colors.orange,
                                        ),
                                        tooltip:
                                            request.additionalExpenseRequest !=
                                                    null &&
                                                request.additionalExpenseRequest!['status'] ==
                                                    'pending'
                                            ? 'Additional expense request pending approval'
                                            : 'Request Additional Expenses',
                                        onPressed:
                                            request.additionalExpenseRequest !=
                                                    null &&
                                                request.additionalExpenseRequest!['status'] ==
                                                    'pending'
                                            ? null
                                            : () =>
                                                  _showAdditionalExpenseDialog(
                                                    request,
                                                  ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        tooltip: 'Complete Call Request',
                                        onPressed: () =>
                                            _showCompleteCallDialog(request),
                                      ),
                                    ],
                                    if (request.status ==
                                        CallRequestStatus.completed)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_note_outlined,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Edit Expenses',
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ExpenseEditorPage(
                                                    callRequest: request,
                                                    onSave: (_) =>
                                                        setState(() {}),
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    // Upload report for completed calls
                                    if (request.status ==
                                            CallRequestStatus.completed ||
                                        request.status ==
                                            CallRequestStatus.pendingReport ||
                                        request.status ==
                                            CallRequestStatus.poPending ||
                                        request.status ==
                                            CallRequestStatus.pendingInvoice ||
                                        request.status ==
                                            CallRequestStatus
                                                .invoiceCreated) ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.upload_file,
                                          color:
                                              request.reportScreenshotBase64 !=
                                                      null &&
                                                  request
                                                      .reportScreenshotBase64!
                                                      .isNotEmpty
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                        tooltip:
                                            request.reportScreenshotBase64 !=
                                                    null &&
                                                request
                                                    .reportScreenshotBase64!
                                                    .isNotEmpty
                                            ? 'Update Report'
                                            : 'Upload Report',
                                        onPressed: () =>
                                            _showUploadReportDialog(request),
                                      ),
                                    ],
                                    if (request.status ==
                                        CallRequestStatus.completed)
                                      IconButton(
                                        icon: Icon(
                                          Icons.note_alt_outlined,
                                          color:
                                              (request
                                                      .completionNotes
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? Colors.deepPurple
                                              : Colors.grey.shade800,
                                        ),
                                        tooltip:
                                            (request
                                                    .completionNotes
                                                    ?.isNotEmpty ??
                                                false)
                                            ? 'Edit Completion Notes'
                                            : 'Add Completion Notes',
                                        onPressed: () =>
                                            _showCompletionNotesDialog(request),
                                      ),
                                    // Duration extension for active calls
                                    if (request.status ==
                                            CallRequestStatus.draft ||
                                        request.status ==
                                            CallRequestStatus.approved) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.access_time,
                                          color: Colors.teal,
                                        ),
                                        tooltip: 'Extend Call Duration',
                                        onPressed: () =>
                                            _showDurationExtensionDialog(
                                              request,
                                            ),
                                      ),
                                    ],
                                    // Due date extension for pending report status
                                    if (request.status ==
                                        CallRequestStatus.pendingReport) ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.calendar_today,
                                          color:
                                              request.dueDateExtensionRequest !=
                                                      null &&
                                                  request.dueDateExtensionRequest!['status'] ==
                                                      'pending'
                                              ? Colors.grey
                                              : Colors.deepOrange,
                                        ),
                                        tooltip:
                                            request.dueDateExtensionRequest !=
                                                    null &&
                                                request.dueDateExtensionRequest!['status'] ==
                                                    'pending'
                                            ? 'Due date extension request pending approval'
                                            : 'Extend Due Date',
                                        onPressed:
                                            request.dueDateExtensionRequest !=
                                                    null &&
                                                request.dueDateExtensionRequest!['status'] ==
                                                    'pending'
                                            ? null
                                            : () => _showDueDateExtensionDialog(
                                                request,
                                              ),
                                      ),
                                    ],
                                    if (isPendingReport &&
                                        request.status ==
                                            CallRequestStatus
                                                .pendingReport) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Edit Expenses',
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ExpenseEditorPage(
                                                    callRequest: request,
                                                    onSave: (updatedExpenses) {
                                                      setState(() {
                                                        // Optionally update local state if needed
                                                      });
                                                    },
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: Colors.teal,
                                        ),
                                        tooltip: 'Mark as Complete',
                                        onPressed: () async {
                                          // Ask for image proof, then mark as completed
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CompleteCallRequestPage(
                                                callRequest: request,
                                                onComplete:
                                                    (
                                                      reportScreenshotBase64,
                                                      sent,
                                                    ) async {
                                                      if (reportScreenshotBase64 !=
                                                              null &&
                                                          reportScreenshotBase64
                                                              .isNotEmpty) {
                                                        await UserService.completeCallRequest(
                                                          requestId: request.id,
                                                          sentReport: true,
                                                          reportScreenshotBase64:
                                                              reportScreenshotBase64,
                                                        );
                                                        setState(() {});
                                                      }
                                                    },
                                                forceProof: true,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeaderCell(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildSettlementIndicator(double difference) {
    if (difference.abs() < 0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'Settled',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final bool companyOwes = difference > 0;
    final displayAmount = _formatAmount(difference.abs());
    final Color borderColor = companyOwes
        ? Colors.green.shade300
        : Colors.red.shade300;
    final Color backgroundColor = companyOwes
        ? Colors.green.shade50
        : Colors.red.shade50;
    final Color textColor = companyOwes
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        companyOwes
            ? 'Company owes ₹$displayAmount'
            : 'You owe ₹$displayAmount',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tableCell(Widget child) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: child,
    );
  }

  Widget _buildStatusChip(CallRequestStatus status, {CallRequest? request}) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor, width: 1.5),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        if (request != null) ...[
          // Show pending due date extension request
          if (request.dueDateExtensionRequest != null &&
              request.dueDateExtensionRequest!['status'] == 'pending') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: const Text(
                'Extension Pending',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDueDateCell(CallRequest request) {
    // Debug: Print the request data
    print('DEBUG: Request ${request.id} status: ${request.status}');
    print(
      'DEBUG: Request pendingReportDueDate: ${request.pendingReportDueDate}',
    );

    if (request.status != CallRequestStatus.pendingReport ||
        request.pendingReportDueDate == null) {
      return const Text('-', style: TextStyle(fontSize: 13));
    }

    final dueDate = request.pendingReportDueDate!;
    final now = DateTime.now();
    final daysDiff = dueDate.difference(now).inDays;
    final isOverdue = daysDiff < 0;
    final isDueToday = daysDiff == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDateOnly(dueDate),
          style: TextStyle(
            fontSize: 13,
            color: isOverdue ? Colors.red : Colors.black,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          isOverdue
              ? '${daysDiff.abs()} days overdue'
              : isDueToday
              ? 'Due today'
              : 'Due in $daysDiff days',
          style: TextStyle(
            fontSize: 11,
            color: isOverdue
                ? Colors.red
                : isDueToday
                ? Colors.orange
                : Colors.grey,
            fontWeight: isOverdue || isDueToday
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  List<CallRequest> _filterRequestsByStatus(
    List<CallRequest> requests,
    Set<CallRequestStatus> statuses,
  ) {
    return requests
        .where((request) => statuses.contains(request.status))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Call Requests'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CallRequest>>(
        stream: UserService.getCallRequestsForUser(widget.username),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading call requests',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final callRequests = snapshot.data ?? [];
          final pendingRequests = _filterRequestsByStatus(callRequests, {
            CallRequestStatus.pendingApproval,
          });
          final creditPendingRequests = _filterRequestsByStatus(callRequests, {
            CallRequestStatus.pendingCredit,
          });
          final draftRequests = _filterRequestsByStatus(callRequests, {
            CallRequestStatus.draft,
          });

          final completedRequests = _filterRequestsByStatus(callRequests, {
            CallRequestStatus.completed,
            CallRequestStatus.poPending,
            CallRequestStatus.pendingInvoice,
            CallRequestStatus.invoiceCreated,
          });
          final rejectedRequests = _filterRequestsByStatus(callRequests, {
            CallRequestStatus.rejected,
          });

          if (callRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_disabled,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Call Requests',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first call request to get started',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _navigateToCallForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Call Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.blue.shade700,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_actions, size: 18),
                          const SizedBox(height: 4),
                          Text('Pending (${pendingRequests.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_bottom, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            'Credit Pending (${creditPendingRequests.length})',
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_actions, size: 18),
                          const SizedBox(height: 4),
                          Text('Ongoing (${draftRequests.length})'),
                        ],
                      ),
                    ),

                    Tab(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 18),
                          const SizedBox(height: 4),
                          Text('Completed (${completedRequests.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel, size: 18),
                          const SizedBox(height: 4),
                          Text('Rejected (${rejectedRequests.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCallRequestsTable(pendingRequests),
                    _buildCallRequestsTable(creditPendingRequests),
                    _buildCallRequestsTable(draftRequests),

                    _buildCallRequestsTable(
                      completedRequests,
                      isCompleted: true,
                    ),
                    _buildCallRequestsTable(rejectedRequests),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCallForm,
        backgroundColor: _hasPendingRequests
            ? Colors.grey
            : Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Call'),
      ),
    );
  }
}
