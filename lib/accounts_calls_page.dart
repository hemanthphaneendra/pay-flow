import 'package:flutter/material.dart';
import 'user_service.dart';
import 'call_view_page.dart';
import 'expense_tracking_page.dart';

class AccountsCallsPage extends StatefulWidget {
  final String username;

  const AccountsCallsPage({super.key, required this.username});

  @override
  State<AccountsCallsPage> createState() => _AccountsCallsPageState();
}

class _AccountsCallsPageState extends State<AccountsCallsPage> {
  Widget _buildInvoiceTable(
    List<CallRequest> requests, {
    required bool isPending,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPending ? Icons.receipt_long : Icons.receipt,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                isPending ? 'No pending invoices' : 'No created invoices',
                style: const TextStyle(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.blue.shade50),
                children: [
                  _tableHeaderCell('Customer'),
                  _tableHeaderCell('Call User'),
                  _tableHeaderCell('Call Period'),
                  _tableHeaderCell('Amount'),
                  _tableHeaderCell('Status'),
                  _tableHeaderCell('Actions'),
                ],
              ),
              ...requests.map(
                (request) => TableRow(
                  children: [
                    _tableCell(
                      Text(
                        request.customerName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    _tableCell(
                      Text(
                        request.requestedBy,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    _tableCell(
                      Text(
                        '${_formatDateOnly(request.callFromDate)} - ${_formatDateOnly(request.callToDate)}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    _tableCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.additionalExpenseRequest != null &&
                                    request.additionalExpenseRequest!['status'] ==
                                        'pending'
                                ? '₹${_formatAmount((request.additionalExpenseRequest!['amount'] ?? 0).toDouble())}'
                                : '₹${_formatAmount(request.finalAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (request.additionalExpenseRequest != null &&
                              request.additionalExpenseRequest!['status'] ==
                                  'pending') ...[
                            const SizedBox(height: 2),
                            Text(
                              'Additional Request',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _tableCell(_buildStatusChip(request.status)),
                    _tableCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_red_eye,
                              color: Colors.indigo,
                            ),
                            tooltip: 'View Details',
                            onPressed: () async {
                              // ignore: use_build_context_synchronously
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CallViewPage(callRequest: request),
                                ),
                              );
                            },
                          ),
                          if (isPending)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Created'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(64, 36),
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                      'Mark Invoice as Created',
                                    ),
                                    content: const Text(
                                      'Are you sure you want to mark this invoice as created?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await UserService.markInvoiceCreated(
                                    callId: request.id,
                                    createdBy: widget.username,
                                  );
                                  if (mounted) setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Invoice marked as created!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _markAsCredited(CallRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Credited'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${request.customerName}'),
            Text(
              request.additionalExpenseRequest != null &&
                      request.additionalExpenseRequest!['status'] == 'pending'
                  ? 'Additional Amount: ₹${_formatAmount((request.additionalExpenseRequest!['amount'] ?? 0).toDouble())}'
                  : 'Amount: ₹${_formatAmount(request.finalAmount)}',
            ),
            if (request.additionalExpenseRequest != null &&
                request.additionalExpenseRequest!['status'] == 'pending') ...[
              const SizedBox(height: 4),
              Text(
                'Original Amount: ₹${_formatAmount(request.requestedAmount)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to mark this call as credited?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Credited'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await UserService.markCallAsCredited(
        request.id,
        widget.username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Call marked as credited successfully!'
                  : 'Failed to mark call as credited.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }

      // Move to draft after marking as credited
      if (success) {
        await UserService.moveCallToDraft(request.id);
      }
    }
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
      case CallRequestStatus.pendingReport:
        return 'Pending Report';
      case CallRequestStatus.completed:
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
        return Colors.deepOrange;
      case CallRequestStatus.completed:
        return Colors.teal;
      case CallRequestStatus.poPending:
        return Colors.brown;
      case CallRequestStatus.pendingInvoice:
        return Colors.orangeAccent;
      case CallRequestStatus.invoiceCreated:
        return Colors.green;
    }
  }

  Widget _buildCallRequestsTable(List<CallRequest> requests) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.blue.shade50),
                children: [
                  _tableHeaderCell('Customer'),
                  _tableHeaderCell('Call Period'),
                  _tableHeaderCell('Duration'),
                  _tableHeaderCell('Amount'),
                  _tableHeaderCell('Status'),
                  _tableHeaderCell('Notes'),
                  _tableHeaderCell('Actions'),
                ],
              ),
              ...requests.map(
                (request) => TableRow(
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
                        request.additionalExpenseRequest != null &&
                                request.additionalExpenseRequest!['status'] ==
                                    'pending'
                            ? '₹${_formatAmount((request.additionalExpenseRequest!['amount'] ?? 0).toDouble())} (Additional)'
                            : '₹${_formatAmount(request.finalAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _tableCell(_buildStatusChip(request.status)),
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
                          if (request.status == CallRequestStatus.rejected &&
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
                                border: Border.all(color: Colors.red.shade200),
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
                                border: Border.all(color: Colors.blue.shade200),
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
                    _tableCell(
                      request.status == CallRequestStatus.approved ||
                              request.status == CallRequestStatus.pendingCredit
                          ? IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              tooltip: 'Mark as Credited',
                              onPressed: () => _markAsCredited(request),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.visibility,
                                color: Colors.blueGrey,
                              ),
                              tooltip: 'View',
                              onPressed: () {
                                // Optionally show details dialog
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableHeaderCell(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _tableCell(Widget child) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    );
  }

  Widget _buildStatusChip(CallRequestStatus status) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    return Container(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls - Accounts Team'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CallRequest>>(
        stream: UserService.getCallRequestsForAccounts(widget.username),
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
          final pendingInvoiceRequests = callRequests
              .where((req) => req.status == CallRequestStatus.pendingInvoice)
              .toList();
          final invoiceCreatedRequests = callRequests
              .where((req) => req.status == CallRequestStatus.invoiceCreated)
              .toList();
          final toCreditRequests = callRequests
              .where((req) => req.status == CallRequestStatus.pendingCredit)
              .toList();
          final creditedRequests = callRequests
              .where(
                (req) =>
                    req.isCredited == true && req.creditedBy == widget.username,
              )
              .toList();

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
                    'Approved call requests will appear here for credit processing',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.blue.shade700,
                  tabs: [
                    Tab(
                      text:
                          'Pending Invoice (${pendingInvoiceRequests.length})',
                      icon: const Icon(Icons.receipt_long),
                    ),
                    Tab(
                      text:
                          'Invoice Created (${invoiceCreatedRequests.length})',
                      icon: const Icon(Icons.receipt),
                    ),
                    Tab(
                      text: 'To Credit (${toCreditRequests.length})',
                      icon: const Icon(Icons.account_balance_wallet),
                    ),
                    Tab(
                      text: 'Credited (${creditedRequests.length})',
                      icon: const Icon(Icons.check_circle),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Pending Invoice Tab
                      _buildInvoiceTable(
                        pendingInvoiceRequests,
                        isPending: true,
                      ),
                      // Invoice Created Tab
                      _buildInvoiceTable(
                        invoiceCreatedRequests,
                        isPending: false,
                      ),
                      // To Credit Tab
                      _buildCallRequestsTable(toCreditRequests),
                      // Credited Tab
                      _buildCallRequestsTable(creditedRequests),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseTrackingPage(username: widget.username),
          ),
        ),
        icon: const Icon(Icons.analytics_outlined),
        label: const Text('Track Expenses'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }
}
