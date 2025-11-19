// Clean single-file implementation
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../invoice_view_page.dart';
import '../invoice_follow_up_page.dart';
import '../utils/indian_format.dart';

class InvoicesTab extends StatefulWidget {
  final String filterStatus;
  final String username;
  final String userType;
  final String invoiceNoFilter;
  final String companyFilter;
  final String customerFilter;
  final DateTime? dueDateFilter;
  final bool paymentAdviceFilter;

  const InvoicesTab({
    super.key,
    required this.filterStatus,
    required this.username,
    required this.userType,
    required this.invoiceNoFilter,
    required this.companyFilter,
    required this.customerFilter,
    required this.dueDateFilter,
    this.paymentAdviceFilter = false,
  });

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab> {
  final ScrollController _hScrollController = ScrollController();

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collection('invoices');

    final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
    if (widget.filterStatus == 'pending') {
      stream = query
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots();
    } else if (widget.filterStatus == 'pending_approval') {
      stream = query
          .where(
            'status',
            whereIn: ['pending_approval', 'pending_partial_approval'],
          )
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots();
    } else {
      stream = query
          .where('status', isEqualTo: widget.filterStatus)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No invoices found',
              style: TextStyle(color: Colors.blueGrey.shade600),
            ),
          );
        }

        // Sort docs by invoice number (extract numeric part after last /)
        final sortedDocs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aInvoiceNo = aData['invoiceNo']?.toString() ?? '';
          final bInvoiceNo = bData['invoiceNo']?.toString() ?? '';

          // Extract numeric part after last /
          final aMatch = RegExp(r'/(\d+)$').firstMatch(aInvoiceNo);
          final bMatch = RegExp(r'/(\d+)$').firstMatch(bInvoiceNo);

          if (aMatch != null && bMatch != null) {
            final aNum = int.tryParse(aMatch.group(1)!) ?? 0;
            final bNum = int.tryParse(bMatch.group(1)!) ?? 0;
            return aNum.compareTo(bNum); // Ascending order (smallest first)
          }

          // Fallback to string comparison
          return aInvoiceNo.compareTo(bInvoiceNo);
        });

        final rows = <DataRow>[];
        int rowIndex = 0;

        for (final doc in sortedDocs) {
          final data = doc.data();
          final invoiceNo = data['invoiceNo']?.toString() ?? '';

          // Filter for Msml user in accounts team - only show ACME company invoices
          if (widget.username.toLowerCase() == 'msml' &&
              widget.userType == 'accounts') {
            final company = data['company']?.toString() ?? '';
            if (company != 'ACME') {
              continue; // Skip non-ACME invoices
            }
          }

          // Filter for Kalyani user - exclude ACME company invoices
          if (widget.username.toLowerCase() == 'kalyani') {
            final company = data['company']?.toString() ?? '';
            if (company == 'ACME') {
              continue; // Skip ACME invoices
            }
          }

          DateTime? invoiceDate;
          final invTs = data['invoiceDate'];
          if (invTs is Timestamp) invoiceDate = invTs.toDate();

          DateTime? dueDate;
          DateTime? expectedRemainingDate;
          final dueTs = data['dueDate'];
          if (dueTs is Timestamp) dueDate = dueTs.toDate();

          if (widget.filterStatus == 'partial') {
            final expTs = data['expectedRemainingDate'];
            if (expTs is Timestamp) {
              expectedRemainingDate = expTs.toDate();
            } else {
              expectedRemainingDate = dueDate;
            }
          }

          DateTime? serviceFrom;
          DateTime? serviceTo;
          final sfTs = data['serviceFrom'];
          if (sfTs is Timestamp) serviceFrom = sfTs.toDate();
          final stTs = data['serviceTo'];
          if (stTs is Timestamp) serviceTo = stTs.toDate();

          final customer = data['customerName']?.toString() ?? '';
          final company = data['company']?.toString() ?? '';
          final description = data['description']?.toString() ?? '';

          bool matchesFilters = true;
          if (widget.invoiceNoFilter.isNotEmpty) {
            matchesFilters =
                matchesFilters &&
                invoiceNo.toLowerCase().contains(
                  widget.invoiceNoFilter.toLowerCase(),
                );
          }
          if (widget.companyFilter.isNotEmpty) {
            matchesFilters =
                matchesFilters &&
                company.toLowerCase().contains(
                  widget.companyFilter.toLowerCase(),
                );
          }
          if (widget.customerFilter.isNotEmpty) {
            matchesFilters =
                matchesFilters &&
                customer.toLowerCase().contains(
                  widget.customerFilter.toLowerCase(),
                );
          }

          if (widget.dueDateFilter != null) {
            final targetDate = widget.filterStatus == 'partial'
                ? expectedRemainingDate
                : dueDate;
            if (targetDate != null) {
              matchesFilters =
                  matchesFilters &&
                  _isSameDate(targetDate, widget.dueDateFilter!);
            } else {
              matchesFilters = false;
            }
          }

          if (widget.paymentAdviceFilter) {
            final paymentAdviceProvided = data['paymentAdviceProvided'] == true;
            if (!paymentAdviceProvided) matchesFilters = false;
          }

          if (!matchesFilters) continue;

          rowIndex++;

          final overdue = widget.filterStatus == 'partial'
              ? (expectedRemainingDate != null &&
                    expectedRemainingDate.isBefore(DateTime.now()))
              : (dueDate != null && dueDate.isBefore(DateTime.now()));

          final serviceDaysStr = (serviceFrom != null && serviceTo != null)
              ? '${_fmt(serviceFrom)} - ${_fmt(serviceTo)}'
              : '';

          final totalAmount = (() {
            final v = data['totalAmount'];
            if (v == null) return '';
            if (v is num)
              return formatIndianCurrency(v.toDouble(), withSymbol: false);
            final parsed = double.tryParse(v.toString());
            return parsed == null
                ? v.toString()
                : formatIndianCurrency(parsed, withSymbol: false);
          })();

          final receivedAmount = (() {
            final v = data['receivedAmount'];
            if (v == null) return '';
            if (v is num)
              return formatIndianCurrency(v.toDouble(), withSymbol: false);
            final parsed = double.tryParse(v.toString());
            return parsed == null
                ? v.toString()
                : formatIndianCurrency(parsed, withSymbol: false);
          })();

          final pendingAmount = (() {
            if (widget.filterStatus == 'partial') {
              final p = data['pendingAmount'];
              if (p == null) return 'N/A';
              if (p is num)
                return formatIndianCurrency(p.toDouble(), withSymbol: false);
              final parsed = double.tryParse(p.toString());
              return parsed == null
                  ? p.toString()
                  : formatIndianCurrency(parsed, withSymbol: false);
            }
            return '';
          })();

          rows.add(
            DataRow(
              cells: [
                DataCell(Text('$rowIndex')),
                DataCell(Text(invoiceNo)),
                DataCell(Text(company)),
                DataCell(Text(invoiceDate == null ? '' : _fmt(invoiceDate))),
                DataCell(
                  Text(
                    widget.filterStatus == 'partial'
                        ? (expectedRemainingDate == null
                              ? ''
                              : _fmt(expectedRemainingDate))
                        : (dueDate == null ? '' : _fmt(dueDate)),
                    style: TextStyle(
                      color: overdue ? Colors.red.shade600 : null,
                      fontWeight: overdue ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                DataCell(Text(serviceDaysStr)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      customer,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text('₹$totalAmount')),
                DataCell(Text('₹$receivedAmount')),
                if (widget.filterStatus == 'partial')
                  DataCell(Text('₹$pendingAmount')),
                if (widget.filterStatus == 'complete' ||
                    widget.filterStatus == 'pending_approval')
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: (() {
                        List<String> allDeductionInfo = [];

                        final mainDeductionsList = data['deductions'] as List?;
                        if (mainDeductionsList != null &&
                            mainDeductionsList.isNotEmpty) {
                          for (final deduction in mainDeductionsList) {
                            final deductionMap =
                                deduction as Map<String, dynamic>;
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

                        final payments = (data['payments'] as List?) ?? [];
                        for (
                          int paymentIndex = 0;
                          paymentIndex < payments.length;
                          paymentIndex++
                        ) {
                          final payment =
                              payments[paymentIndex] as Map<String, dynamic>;
                          final paymentDeductions =
                              payment['deductions'] as List?;
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
                                  ? '$type (₹$amount) [P${paymentIndex + 1}]'
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

                        final oldDeduction = data['deduction']?.toString();
                        return Text(
                          oldDeduction ?? 'N/A',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                        );
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
                      widget.filterStatus != 'complete' &&
                              widget.userType != 'admin'
                          ? IconButton(
                              icon: const Icon(
                                Icons.edit_note_outlined,
                                size: 22,
                              ),
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
                            )
                          : const SizedBox.shrink(),
                      // Delete buttons: non-complete invoices (non-admin users) and completed invoices (admin only)
                      widget.filterStatus != 'complete' &&
                              widget.userType != 'admin'
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDelete(context, doc.id, invoiceNo),
                            )
                          : const SizedBox.shrink(),
                      widget.filterStatus == 'complete' &&
                              widget.userType == 'admin'
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDelete(context, doc.id, invoiceNo),
                            )
                          : const SizedBox.shrink(),
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
            controller: _hScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hScrollController,
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
                        widget.filterStatus == 'partial'
                            ? 'Expected Remaining Date'
                            : 'Due Date',
                      ),
                    ),
                    const DataColumn(label: Text('Service Days')),
                    const DataColumn(label: Text('Customer Name')),
                    const DataColumn(label: Text('Total Amount')),
                    const DataColumn(label: Text('Received Amount')),
                    if (widget.filterStatus == 'partial')
                      const DataColumn(label: Text('Pending Amount')),
                    if (widget.filterStatus == 'complete' ||
                        widget.filterStatus == 'pending_approval')
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
      },
    );
  }
}

// Local helpers copied from home_screen.dart so this file is self-contained
bool _isSameDate(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> _confirmDelete(
  BuildContext context,
  String docId,
  String invoiceNo,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Invoice'),
      content: Text('Are you sure you want to delete invoice #$invoiceNo?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) {
    try {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(docId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invoice #$invoiceNo deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}
