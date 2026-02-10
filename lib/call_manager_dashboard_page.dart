import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_service.dart';
import 'call_view_page.dart';

class CallManagerDashboardPage extends StatefulWidget {
  final String username;

  const CallManagerDashboardPage({super.key, required this.username});

  @override
  State<CallManagerDashboardPage> createState() =>
      _CallManagerDashboardPageState();
}

class _CallManagerDashboardPageState extends State<CallManagerDashboardPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _processedSearchController =
      TextEditingController();
  late final TabController _tabController;
  Timer? _processedSearchDebounce;
  CallRequestStatus? _processedStatusFilter;

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _approveCallRequest(CallRequest request) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ApprovalDialog(
        request: request,
        title: 'Approve Call Request',
        isApproval: true,
      ),
    );

    if (result != null) {
      final success = await UserService.approveCallRequest(
        request.id,
        widget.username,
        result['modifiedAmount'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Call request approved successfully!'
                  : 'Failed to approve call request.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectCallRequest(CallRequest request) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ApprovalDialog(
        request: request,
        title: 'Reject Call Request',
        isApproval: false,
      ),
    );

    if (result != null) {
      final success = await UserService.rejectCallRequest(
        request.id,
        result['reason'] ?? 'Rejected by call manager',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Call request rejected successfully!'
                  : 'Failed to reject call request.',
            ),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
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
        return Colors.indigo;
      case CallRequestStatus.invoiceCreated:
        return Colors.cyan;
    }
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 1),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.blue.shade50),
                    children: [
                      _tableHeaderCell('Customer'),
                      _tableHeaderCell('Requested By'),
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
                          Text(
                            request.requestedBy,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.additionalExpenseRequest != null &&
                                        request.additionalExpenseRequest!['status'] ==
                                            'pending'
                                    ? '₹${_formatAmount((request.additionalExpenseRequest!['amount'] ?? 0).toDouble())}'
                                    : '₹${_formatAmount(request.finalAmount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                Text(
                                  'Original: ₹${_formatAmount(request.requestedAmount)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
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
                        _tableCell(
                          request.status == CallRequestStatus.pendingApproval
                              ? Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Approve',
                                      onPressed: () =>
                                          _approveCallRequest(request),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Reject',
                                      onPressed: () =>
                                          _rejectCallRequest(request),
                                    ),
                                  ],
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.visibility,
                                    color: Colors.blueGrey,
                                  ),
                                  tooltip: 'View',
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CallViewPage(callRequest: request),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  bool get _hasProcessedFilters {
    return _processedStatusFilter != null ||
        _processedSearchController.text.trim().isNotEmpty;
  }

  void _clearProcessedFilters() {
    if (!_hasProcessedFilters) return;
    _processedSearchController.clear();
    setState(() {
      _processedStatusFilter = null;
    });
  }

  void _onProcessedSearchChanged(String value) {
    _processedSearchDebounce?.cancel();
    _processedSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  Widget _buildProcessedFilters(List<CallRequest> processedRequests) {
    final statuses = CallRequestStatus.values
        .where((status) => status != CallRequestStatus.pendingApproval)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                'Filter Processed Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _hasProcessedFilters ? _clearProcessedFilters : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _processedSearchController,
                  onChanged: _onProcessedSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Search by customer or requester',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _processedSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _processedSearchController.clear();
                              _onProcessedSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<CallRequestStatus?>(
                  value: _processedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<CallRequestStatus?>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    ...statuses.map(
                      (status) => DropdownMenuItem<CallRequestStatus?>(
                        value: status,
                        child: Text(_getStatusText(status)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _processedStatusFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<CallRequest> _applyProcessedFilters(List<CallRequest> requests) {
    final query = _processedSearchController.text.trim().toLowerCase();

    return requests.where((request) {
      final matchesStatus =
          _processedStatusFilter == null ||
          request.status == _processedStatusFilter;
      final matchesSearch =
          query.isEmpty ||
          request.customerName.toLowerCase().contains(query) ||
          request.requestedBy.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Widget _buildProcessedTab(List<CallRequest> processedRequests) {
    final filteredRequests = _applyProcessedFilters(processedRequests);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProcessedFilters(processedRequests),
          filteredRequests.isEmpty
              ? Container(
                  height: 400,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _hasProcessedFilters
                            ? 'No requests match your filters'
                            : 'No processed requests found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (_hasProcessedFilters) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _clearProcessedFilters,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Clear Filters'),
                        ),
                      ],
                    ],
                  ),
                )
              : _buildCallRequestsTable(filteredRequests),
        ],
      ),
    );
  }

  // Future<void> _onRefresh() async {
  //   // Implement your refresh logic here, e.g., fetching new data from the server
  //   setState(
  //     () {},
  //   ); // This will rebuild the widget and reflect any data changes
  // }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _processedSearchDebounce?.cancel();
    _processedSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<CallRequest>>(
        stream: UserService.getCallRequestsForManager(),
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
          final pendingRequests = callRequests
              .where((req) => req.status == CallRequestStatus.pendingApproval)
              .toList();
          final processedRequests = callRequests
              .where((req) => req.status != CallRequestStatus.pendingApproval)
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
                    'Call requests will appear here when submitted',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                title: const Text('Call Request Management'),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                floating: true,
                snap: true,
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue.shade700,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.blue.shade700,
                    tabs: [
                      Tab(
                        text: 'Pending (${pendingRequests.length})',
                        icon: const Icon(Icons.pending_actions),
                      ),
                      Tab(
                        text: 'Processed (${processedRequests.length})',
                        icon: const Icon(Icons.history),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // Pending Tab
                pendingRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All Caught Up!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No pending call requests to review',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : _buildCallRequestsTable(pendingRequests),
                // Processed Tab
                processedRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Processed Requests',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Processed requests will appear here',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : _buildProcessedTab(processedRequests),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ApprovalDialog extends StatefulWidget {
  final CallRequest request;
  final String title;
  final bool isApproval;

  const ApprovalDialog({
    super.key,
    required this.request,
    required this.title,
    required this.isApproval,
  });

  @override
  State<ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<ApprovalDialog> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _modifyAmount = false;

  @override
  void initState() {
    super.initState();
    // If there's an additional expense request, show that amount
    if (widget.request.additionalExpenseRequest != null &&
        widget.request.additionalExpenseRequest!['status'] == 'pending') {
      _amountController.text =
          (widget.request.additionalExpenseRequest!['amount'] ?? 0)
              .toDouble()
              .toStringAsFixed(2);
    } else {
      _amountController.text = widget.request.requestedAmount.toStringAsFixed(
        2,
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Call details
              Text(
                'Call Details:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Customer: ${widget.request.customerName}'),
              Text('Duration: ${widget.request.durationText}'),
              if (widget.request.additionalExpenseRequest != null &&
                  widget.request.additionalExpenseRequest!['status'] ==
                      'pending') ...[
                Text(
                  'Original Amount: ₹${widget.request.requestedAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Additional Amount Requested: ₹${(widget.request.additionalExpenseRequest!['amount'] ?? 0).toDouble().toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.request.additionalExpenseRequest!['reason'] !=
                    null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason for Additional Expense:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    widget.request.additionalExpenseRequest!['reason'] ?? '',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ] else ...[
                Text(
                  'Requested Amount: ₹${widget.request.requestedAmount.toStringAsFixed(2)}',
                ),
              ],
              const SizedBox(height: 16),

              if (widget.isApproval) ...[
                // Amount modification option
                CheckboxListTile(
                  title: const Text('Modify Amount'),
                  value: _modifyAmount,
                  onChanged: (value) {
                    setState(() {
                      _modifyAmount = value ?? false;
                      if (!_modifyAmount) {
                        // Reset to appropriate amount based on request type
                        if (widget.request.additionalExpenseRequest != null &&
                            widget
                                    .request
                                    .additionalExpenseRequest!['status'] ==
                                'pending') {
                          _amountController.text =
                              (widget
                                          .request
                                          .additionalExpenseRequest!['amount'] ??
                                      0)
                                  .toDouble()
                                  .toStringAsFixed(2);
                        } else {
                          _amountController.text = widget
                              .request
                              .requestedAmount
                              .toStringAsFixed(2);
                        }
                      }
                    });
                  },
                ),

                if (_modifyAmount) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Approved Amount',
                      prefixText: '₹ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Amount is required';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ] else ...[
                // Rejection reason
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason',
                    hintText: 'Enter reason for rejection',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Rejection reason is required';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final result = <String, dynamic>{};

              if (widget.isApproval) {
                if (_modifyAmount) {
                  result['modifiedAmount'] = double.parse(
                    _amountController.text,
                  );
                }
              } else {
                result['reason'] = _reasonController.text.trim();
              }

              Navigator.of(context).pop(result);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isApproval ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.isApproval ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 4 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
