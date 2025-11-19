import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../invoice_follow_up_page.dart';
import '../invoice_view_page.dart';

class NotificationsPage extends StatefulWidget {
  final String username;
  final String userType;

  const NotificationsPage({required this.username, required this.userType});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _pendingApprovalScrollController = ScrollController();
  final ScrollController _partialScrollController = ScrollController();
  final ScrollController _completeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingScrollController.dispose();
    _pendingApprovalScrollController.dispose();
    _partialScrollController.dispose();
    _completeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue.shade800,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade600,
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Pending Approval'),
              Tab(text: 'Partial'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationTab('pending'),
              _buildNotificationTab('pendingApproval'),
              _buildNotificationTab('partial'),
              _buildNotificationTab('complete'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTab(String filterStatus) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final todayEnd = todayStart.add(const Duration(days: 1));

        // Filter invoices based on status AND due date/expected date
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Filter for Msml user in accounts team - only show ACME company invoices
          if (widget.username.toLowerCase() == 'msml' &&
              widget.userType == 'accounts') {
            final company = data['company']?.toString() ?? '';
            if (company != 'ACME') {
              return false; // Skip non-ACME invoices
            }
          }

          // Filter for Kalyani user - exclude ACME company invoices
          if (widget.username.toLowerCase() == 'kalyani') {
            final company = data['company']?.toString() ?? '';
            if (company == 'ACME') {
              return false; // Skip ACME invoices
            }
          }

          final status = data['status']?.toString() ?? 'pending';

          // First check if status matches
          bool statusMatches = false;
          if (filterStatus == 'pending') {
            statusMatches = status == 'pending';
          } else if (filterStatus == 'pendingApproval') {
            final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
            final accountsApproval = approvals['accounts'];
            final debtCollectionApproval = approvals['debtCollection'];
            final approvalsPending =
                (accountsApproval?['approved'] == true ||
                    debtCollectionApproval?['approved'] == true) &&
                !(accountsApproval?['approved'] == true &&
                    debtCollectionApproval?['approved'] == true);
            // Include documents where the server-side status already marks pending approval
            // or where the approvals map indicates one side has proposed (approvalsPending).
            statusMatches =
                status == 'pending_approval' ||
                status == 'pending_partial_approval' ||
                approvalsPending;
          } else if (filterStatus == 'partial') {
            statusMatches = status == 'partial';
          } else if (filterStatus == 'complete') {
            statusMatches = status == 'complete';
          }

          if (!statusMatches) return false;

          // Debug logging for pendingApproval to trace why documents match or not
          if (filterStatus == 'pendingApproval') {
            final invoiceNo = data['invoiceNo']?.toString() ?? doc.id;
            final approvalsMap = data['approvals'];
            // Print a concise debug line - this appears in the device log / console
            print(
              'NOTIF DEBUG: invoice=$invoiceNo status=$status approvals=$approvalsMap statusMatches=$statusMatches',
            );
            // If this document matches pending-approval logic, include it regardless of date
            if (statusMatches) return true;
          }

          // Then check if it has a due date or expected date today
          bool hasTodayDate = false;

          // Check due date
          final dueDate = data['dueDate'];
          if (dueDate is Timestamp) {
            final dueDateObject = dueDate.toDate();
            if (dueDateObject.isAfter(
                  todayStart.subtract(const Duration(microseconds: 1)),
                ) &&
                dueDateObject.isBefore(todayEnd)) {
              hasTodayDate = true;
            }
          }

          // Check expected remaining date (for partial payments)
          if (!hasTodayDate) {
            final expectedDate = data['expectedRemainingDate'];
            if (expectedDate is Timestamp) {
              final expectedDateObject = expectedDate.toDate();
              if (expectedDateObject.isAfter(
                    todayStart.subtract(const Duration(microseconds: 1)),
                  ) &&
                  expectedDateObject.isBefore(todayEnd)) {
                hasTodayDate = true;
              }
            }
          }

          return hasTodayDate;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getTabIcon(filterStatus),
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_getTabTitle(filterStatus).toLowerCase()} invoices due today',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Great! You\'re all caught up.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return _buildInvoiceTable(filteredDocs, filterStatus);
      },
    );
  }

  IconData _getTabIcon(String filterStatus) {
    switch (filterStatus) {
      case 'pending':
        return Icons.pending_actions;
      case 'pendingApproval':
        return Icons.approval;
      case 'partial':
        return Icons.pie_chart;
      case 'complete':
        return Icons.check_circle;
      default:
        return Icons.event_available;
    }
  }

  String _getTabTitle(String filterStatus) {
    switch (filterStatus) {
      case 'pending':
        return 'Pending';
      case 'pendingApproval':
        return 'Pending Approval';
      case 'partial':
        return 'Partial';
      case 'complete':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  Widget _buildInvoiceTable(List<DocumentSnapshot> docs, String filterStatus) {
    ScrollController hScrollController;
    switch (filterStatus) {
      case 'pending':
        hScrollController = _pendingScrollController;
        break;
      case 'pendingApproval':
        hScrollController = _pendingApprovalScrollController;
        break;
      case 'partial':
        hScrollController = _partialScrollController;
        break;
      case 'complete':
        hScrollController = _completeScrollController;
        break;
      default:
        hScrollController = _pendingScrollController;
    }

    final rows = <DataRow>[];

    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final data = doc.data() as Map<String, dynamic>;
      final rowIndex = i + 1;

      final invoiceNo = data['invoiceNo']?.toString() ?? '';
      final company = data['company']?.toString() ?? '';
      final customer = data['customer']?.toString() ?? '';
      final status = data['status']?.toString() ?? 'pending';
      final description = data['description']?.toString() ?? '';

      // Get invoice date
      final invoiceDate = data['invoiceDate'];
      DateTime? invoiceDateObject;
      if (invoiceDate is Timestamp) {
        invoiceDateObject = invoiceDate.toDate();
      }

      // Get service period
      final serviceFrom = data['serviceFrom'];
      final serviceTo = data['serviceTo'];
      DateTime? serviceFromDate;
      DateTime? serviceToDate;
      if (serviceFrom is Timestamp) serviceFromDate = serviceFrom.toDate();
      if (serviceTo is Timestamp) serviceToDate = serviceTo.toDate();

      final serviceDaysStr = (serviceFromDate != null && serviceToDate != null)
          ? '${_fmt(serviceFromDate)} - ${_fmt(serviceToDate)}'
          : '';

      // Get the relevant date (due date or expected date)
      DateTime? relevantDate;

      // For partial status, prioritize expected remaining date
      if (filterStatus == 'partial') {
        final expectedDate = data['expectedRemainingDate'];
        if (expectedDate is Timestamp) {
          relevantDate = expectedDate.toDate();
        }
      }

      // If no expected date found, or not partial, check for due date
      if (relevantDate == null) {
        final dueDate = data['dueDate'];
        if (dueDate is Timestamp) {
          relevantDate = dueDate.toDate();
        }
      }

      // Calculate pending amount for partial payments
      final pendingAmount = (() {
        if (filterStatus == 'partial') {
          final p = data['pendingAmount'];
          if (p == null) return 'N/A';
          if (p is num) return p.toStringAsFixed(2);
          final parsed = double.tryParse(p.toString());
          return parsed == null ? p.toString() : parsed.toStringAsFixed(2);
        }
        return '';
      })();
      final totalAmount = (() {
        final v = data['totalAmount'];
        if (v == null) return '';
        if (v is num) return v.toStringAsFixed(2);
        final parsed = double.tryParse(v.toString());
        return parsed == null ? v.toString() : parsed.toStringAsFixed(2);
      })();

      final receivedAmount = (() {
        final v = data['receivedAmount'];
        if (v == null) return '';
        if (v is num) return v.toStringAsFixed(2);
        final parsed = double.tryParse(v.toString());
        return parsed == null ? v.toString() : parsed.toStringAsFixed(2);
      })();

      rows.add(
        DataRow(
          cells: [
            DataCell(Text('$rowIndex')),
            DataCell(Text(invoiceNo)),
            DataCell(Text(company)),
            DataCell(
              Text(invoiceDateObject != null ? _fmt(invoiceDateObject) : ''),
            ),
            DataCell(
              Text(
                relevantDate != null ? _fmt(relevantDate) : '',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(Text(serviceDaysStr)),
            DataCell(Text(customer, overflow: TextOverflow.ellipsis)),
            DataCell(Text('₹$totalAmount')),
            DataCell(Text('₹$receivedAmount')),
            if (filterStatus == 'partial') DataCell(Text('₹$pendingAmount')),
            if (filterStatus == 'complete')
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: (() {
                    // Get deductions (same logic as work process)
                    List<String> allDeductionInfo = [];

                    // 1. Get deductions from main deductions field
                    final mainDeductionsList = data['deductions'] as List?;
                    if (mainDeductionsList != null &&
                        mainDeductionsList.isNotEmpty) {
                      for (final deduction in mainDeductionsList) {
                        final deductionMap = deduction as Map<String, dynamic>;
                        final type =
                            deductionMap['type']?.toString() ?? 'Unknown';
                        final amount = deductionMap['amount']?.toString();
                        if (amount != null && amount.isNotEmpty) {
                          allDeductionInfo.add('$type (₹${amount})');
                        } else {
                          allDeductionInfo.add(type);
                        }
                      }
                    }

                    // 2. Get deductions from payments list
                    final payments = (data['payments'] as List?) ?? [];
                    for (
                      int paymentIndex = 0;
                      paymentIndex < payments.length;
                      paymentIndex++
                    ) {
                      final payment =
                          payments[paymentIndex] as Map<String, dynamic>;
                      final paymentDeductions = payment['deductions'] as List?;
                      if (paymentDeductions != null &&
                          paymentDeductions.isNotEmpty) {
                        for (final deduction in paymentDeductions) {
                          final deductionMap =
                              deduction as Map<String, dynamic>;
                          final type =
                              deductionMap['type']?.toString() ?? 'Unknown';
                          final amount = deductionMap['amount']?.toString();
                          final displayText =
                              amount != null && amount.isNotEmpty
                              ? '$type (₹${amount}) [P${paymentIndex + 1}]'
                              : '$type [P${paymentIndex + 1}]';
                          allDeductionInfo.add(displayText);
                        }
                      }
                    }

                    if (allDeductionInfo.isNotEmpty) {
                      return Text(
                        allDeductionInfo.join(', '),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 11),
                      );
                    }

                    return const Text('N/A', style: TextStyle(fontSize: 12));
                  })(),
                ),
              ),
            DataCell(
              SizedBox(
                width: 160,
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    tooltip: 'View',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoiceViewPage(invoiceId: doc.id, data: data),
                      ),
                    ),
                  ),
                  if (status != 'complete' && widget.userType != 'admin')
                    IconButton(
                      icon: const Icon(Icons.edit_note_outlined, size: 22),
                      tooltip: 'Edit / Follow-up',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InvoiceFollowUpPage(
                            username: widget.username,
                            userType: widget.userType,
                            invoiceId: doc.id,
                            initialData: data,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Scrollbar(
        controller: hScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hScrollController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 24,
            ),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(Colors.blue.shade50),
              columnSpacing: 28,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 68,
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
                outside: BorderSide(color: Colors.grey.shade300),
              ),
              columns: [
                const DataColumn(label: Text('S.No')),
                const DataColumn(label: Text('Invoice No')),
                const DataColumn(label: Text('Company')),
                const DataColumn(label: Text('Invoice Date')),
                DataColumn(
                  label: Text(
                    filterStatus == 'partial'
                        ? 'Expected Remaining Date'
                        : 'Due Date',
                  ),
                ),
                const DataColumn(label: Text('Service Days')),
                const DataColumn(label: Text('Customer Name')),
                const DataColumn(label: Text('Total Amount')),
                const DataColumn(label: Text('Received Amount')),
                if (filterStatus == 'partial')
                  const DataColumn(label: Text('Pending Amount')),
                if (filterStatus == 'complete')
                  const DataColumn(label: Text('Deduction')),
                const DataColumn(label: Text('Description')),
                const DataColumn(label: Text('Actions')),
              ],
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
