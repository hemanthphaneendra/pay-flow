import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'utils/indian_format.dart';

class InvoiceViewPage extends StatelessWidget {
  final String invoiceId;
  final Map<String, dynamic> data;
  const InvoiceViewPage({
    super.key,
    required this.invoiceId,
    required this.data,
  });

  DateTime? _d(dynamic v) => v is Timestamp ? v.toDate() : null;

  @override
  Widget build(BuildContext context) {
    final invoiceNo = data['invoiceNo']?.toString() ?? '';
    final invoiceDate = _d(data['invoiceDate']);
    final dueDate = _d(data['dueDate']);
    final sf = _d(data['serviceFrom']);
    final st = _d(data['serviceTo']);
    final followUps = (data['followUps'] as List?) ?? [];
    final status = data['status']?.toString() ?? 'pending';
    final expectedRemainingDate = _d(data['expectedRemainingDate']);
    final payments = (data['payments'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: Text('Invoice #$invoiceNo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(context, 'Basic Info', [
            _row('Invoice No', invoiceNo),
            _row('Invoice Date', invoiceDate == null ? '' : _fmt(invoiceDate)),
            _row(
              'Total Amount',
              (data['totalAmount'] == null)
                  ? ''
                  : formatIndianCurrency(
                      double.tryParse(data['totalAmount'].toString()) ?? 0.0,
                      withSymbol: false,
                    ),
            ),
            _row('Due Date', dueDate == null ? '' : _fmt(dueDate)),
            _row(
              'Service Days',
              sf != null && st != null ? '${_fmt(sf)} - ${_fmt(st)}' : '',
            ),
            _row('Service Type', data['serviceType']?.toString() ?? ''),
            _row('Company', data['company']?.toString() ?? ''),
            _row('Customer', data['customerName']?.toString() ?? ''),
            _row('Status', status),
            _row(
              'Expected Remaining Date',
              expectedRemainingDate == null
                  ? 'N/A'
                  : _fmt(expectedRemainingDate),
            ),
            _row(
              'Pending Amount',
              (() {
                final pendingAmount = data['pendingAmount'];
                if (pendingAmount == null) return 'N/A';
                if (pendingAmount is num)
                  return formatIndianCurrency(
                    pendingAmount.toDouble(),
                    withSymbol: false,
                  );
                final parsed = double.tryParse(pendingAmount.toString());
                return parsed == null
                    ? pendingAmount.toString()
                    : formatIndianCurrency(parsed, withSymbol: false);
              })(),
            ),
          ]),
          _section(context, 'Description', [
            SelectableText(data['description']?.toString() ?? ''),
          ]),
          _section(context, 'Payment Details', [
            Text(
              'Total Amount: ${data['totalAmount'] == null ? '0' : formatIndianCurrency(double.tryParse(data['totalAmount'].toString()) ?? 0.0, withSymbol: false)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Received Amount: ${data['receivedAmount'] == null ? '0' : formatIndianCurrency(double.tryParse(data['receivedAmount'].toString()) ?? 0.0, withSymbol: false)}',
            ),
            const SizedBox(height: 8),
            // Payment Approvals
            (() {
              final approvals =
                  data['approvals'] as Map<String, dynamic>? ?? {};
              final partialApprovals =
                  data['partialApprovals'] as Map<String, dynamic>? ?? {};
              final completionPayment =
                  data['completionPayment'] as Map<String, dynamic>?;
              final partialPayment =
                  data['partialPayment'] as Map<String, dynamic>?;

              if (status == 'complete') {
                final accountsApprover = approvals['accounts']?['approvedBy'];
                final debtCollectionApprover =
                    approvals['debtCollection']?['approvedBy'];

                if (accountsApprover != null &&
                    debtCollectionApprover != null) {
                  if (completionPayment != null) {
                    final proposedBy = completionPayment['proposedBy'];
                    final proposedByTeam = completionPayment['proposedByTeam'];
                    final approverTeam = proposedByTeam == 'accounts'
                        ? 'debtCollection'
                        : 'accounts';
                    final approver = approverTeam == 'accounts'
                        ? accountsApprover
                        : debtCollectionApprover;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completion Proposed by: $proposedByTeam ($proposedBy)',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Completion Approved by: $approverTeam ($approver)',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  } else {
                    return Text(
                      'Completed by: Accounts($accountsApprover), DebtCollection($debtCollectionApprover)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    );
                  }
                }
              }

              if (status == 'partial') {
                final accountsApprover =
                    partialApprovals['accounts']?['approvedBy'];
                final debtCollectionApprover =
                    partialApprovals['debtCollection']?['approvedBy'];

                if (accountsApprover != null &&
                    debtCollectionApprover != null) {
                  if (partialPayment != null) {
                    final proposedBy = partialPayment['proposedBy'];
                    final proposedByTeam = partialPayment['proposedByTeam'];
                    final approverTeam = proposedByTeam == 'accounts'
                        ? 'debtCollection'
                        : 'accounts';
                    final approver = approverTeam == 'accounts'
                        ? accountsApprover
                        : debtCollectionApprover;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partial Proposed by: $proposedByTeam ($proposedBy)',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Partial Approved by: $approverTeam ($approver)',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  } else {
                    return Text(
                      'Partial approved by: Accounts($accountsApprover), DebtCollection($debtCollectionApprover)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    );
                  }
                }
              }

              if (status == 'pending_approval') {
                final accountsApprover = approvals['accounts']?['approvedBy'];
                final debtCollectionApprover =
                    approvals['debtCollection']?['approvedBy'];

                if (accountsApprover != null &&
                    debtCollectionApprover == null) {
                  return Text(
                    'Proposed by Accounts ($accountsApprover), waiting for DebtCollection approval',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  );
                } else if (debtCollectionApprover != null &&
                    accountsApprover == null) {
                  return Text(
                    'Proposed by DebtCollection ($debtCollectionApprover), waiting for Accounts approval',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  );
                }
              }

              if (status == 'pending_partial_approval') {
                final accountsApprover =
                    partialApprovals['accounts']?['approvedBy'];
                final debtCollectionApprover =
                    partialApprovals['debtCollection']?['approvedBy'];

                if (accountsApprover != null &&
                    debtCollectionApprover == null) {
                  return Text(
                    'Partial proposed by Accounts ($accountsApprover), waiting for DebtCollection approval',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  );
                } else if (debtCollectionApprover != null &&
                    accountsApprover == null) {
                  return Text(
                    'Partial proposed by DebtCollection ($debtCollectionApprover), waiting for Accounts approval',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  );
                }
              }

              return const Text(
                'No approvals recorded yet',
                style: TextStyle(color: Colors.grey),
              );
            })(),
          ]),
          // Deductions section (always show)
          _section(context, 'Deductions', [
            (() {
              // Collect all deductions from both main deductions field and payments
              List<Map<String, dynamic>> allDeductions = [];

              // 1. Get deductions from main deductions field
              final mainDeductionsList = data['deductions'] as List?;
              if (mainDeductionsList != null && mainDeductionsList.isNotEmpty) {
                for (final deduction in mainDeductionsList) {
                  final deductionMap = deduction as Map<String, dynamic>;
                  allDeductions.add({
                    ...deductionMap,
                    'source': 'main', // Mark source for display
                  });
                }
              }

              // 2. Get deductions from payments list
              final payments = (data['payments'] as List?) ?? [];
              for (
                int paymentIndex = 0;
                paymentIndex < payments.length;
                paymentIndex++
              ) {
                final payment = payments[paymentIndex] as Map<String, dynamic>;
                final paymentDeductions = payment['deductions'] as List?;
                if (paymentDeductions != null && paymentDeductions.isNotEmpty) {
                  for (final deduction in paymentDeductions) {
                    final deductionMap = deduction as Map<String, dynamic>;
                    allDeductions.add({
                      ...deductionMap,
                      'source': 'payment',
                      'paymentIndex': paymentIndex + 1, // 1-based for display
                    });
                  }
                }
              }

              // Check for old single deduction format (backward compatibility)
              final hasOldDeductionReason =
                  data['deduction'] != null &&
                  data['deduction'].toString().isNotEmpty &&
                  data['deduction'].toString() != 'N/A';

              if (allDeductions.isNotEmpty) {
                // Show all deductions from both sources
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deduction Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...allDeductions.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final deduction = entry.value;
                      final deductionType =
                          deduction['type']?.toString() ?? 'Unknown';
                      final deductionNotes =
                          deduction['notes']?.toString() ?? 'No notes';
                      final deductionAmount =
                          deduction['amount']?.toString() ?? '0';
                      final source = deduction['source'] ?? 'unknown';
                      final paymentIndex = deduction['paymentIndex'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: source == 'payment'
                              ? Colors.orange.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: source == 'payment'
                                ? Colors.orange.shade300
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$index. $deductionType',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (source == 'payment')
                                        Text(
                                          'From Payment $paymentIndex',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹$deductionAmount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              deductionNotes,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    // Calculate and display total deduction amount from all sources
                    (() {
                      double totalDeductionAmount = 0.0;
                      for (final deduction in allDeductions) {
                        final amount =
                            double.tryParse(
                              deduction['amount']?.toString() ?? '0',
                            ) ??
                            0.0;
                        totalDeductionAmount += amount;
                      }
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total Deduction Amount:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              '₹${formatIndianCurrency(totalDeductionAmount, withSymbol: false)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    })(),
                    if (data['deductionNote']?.toString().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      _row(
                        'General Notes',
                        data['deductionNote']?.toString() ?? 'N/A',
                      ),
                    ],
                  ],
                );
              } else if (hasOldDeductionReason) {
                // Show old single deduction format (backward compatibility)
                final totalAmount =
                    double.tryParse(data['totalAmount']?.toString() ?? '0') ??
                    0.0;
                final receivedAmount =
                    double.tryParse(
                      data['receivedAmount']?.toString() ?? '0',
                    ) ??
                    0.0;
                final deductionAmount = receivedAmount < totalAmount
                    ? totalAmount - receivedAmount
                    : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(
                      'Deduction Amount',
                      deductionAmount > 0
                          ? formatIndianCurrency(
                              deductionAmount,
                              withSymbol: false,
                            )
                          : '0.00',
                    ),
                    _row('Deduction Reason', data['deduction'].toString()),
                    _row(
                      'Deduction Notes',
                      data['deductionNote']?.toString() ?? 'N/A',
                    ),
                  ],
                );
              } else {
                // No deductions found
                return const Text(
                  'No deductions applied',
                  style: TextStyle(color: Colors.grey),
                );
              }
            })(),
          ]),
          // Partial Payments section (always show individual payments)
          _section(context, 'Partial Payments', [
            (() {
              // Filter payments to show only partial payments
              final partialPayments = payments.where((payment) {
                final p = payment as Map<String, dynamic>;
                return p['type']?.toString().toLowerCase() == 'partial';
              }).toList();

              if (partialPayments.isEmpty) {
                return const Text(
                  'No partial payments made yet.',
                  style: TextStyle(color: Colors.blueGrey),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < partialPayments.length; i++)
                    (() {
                      final payment =
                          partialPayments[i] as Map<String, dynamic>;
                      final amount = payment['amount'];
                      final receivedAt = _d(payment['receivedAt']);
                      final expected = _d(
                        payment['expectedRemainingDate'] ?? payment['expected'],
                      );
                      final marked = _d(payment['markedAt']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment ${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _row(
                              'Amount',
                              amount == null
                                  ? 'N/A'
                                  : formatIndianCurrency(
                                      double.tryParse(amount.toString()) ?? 0.0,
                                      withSymbol: false,
                                    ),
                            ),
                            _row(
                              'Received At',
                              receivedAt != null
                                  ? receivedAt.toLocal().toString()
                                  : 'N/A',
                            ),
                            _row(
                              'Expected Remaining Date',
                              expected != null ? _fmt(expected) : 'N/A',
                            ),
                            _row(
                              'Marked At',
                              marked != null
                                  ? marked.toLocal().toString()
                                  : 'N/A',
                            ),
                            // Add approval information if available
                            (() {
                              final approvedBy =
                                  payment['approvedBy'] as List<dynamic>?;
                              if (approvedBy != null && approvedBy.isNotEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    _row('Approved By', approvedBy.join(', ')),
                                  ],
                                );
                              }

                              // If no approvedBy field, try to get from partialApprovals
                              final partialApprovals =
                                  data['partialApprovals']
                                      as Map<String, dynamic>? ??
                                  {};
                              final partialPayment =
                                  data['partialPayment']
                                      as Map<String, dynamic>?;
                              final accountsApprover =
                                  partialApprovals['accounts']?['approvedBy'];
                              final debtCollectionApprover =
                                  partialApprovals['debtCollection']?['approvedBy'];

                              if (accountsApprover != null &&
                                  debtCollectionApprover != null) {
                                if (partialPayment != null) {
                                  final proposedBy =
                                      partialPayment['proposedBy'];
                                  final proposedByTeam =
                                      partialPayment['proposedByTeam'];
                                  final approverTeam =
                                      proposedByTeam == 'accounts'
                                      ? 'debtCollection'
                                      : 'accounts';
                                  final approver = approverTeam == 'accounts'
                                      ? accountsApprover
                                      : debtCollectionApprover;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      _row(
                                        'Proposed By',
                                        '$proposedByTeam ($proposedBy)',
                                      ),
                                      _row(
                                        'Approved By',
                                        '$approverTeam ($approver)',
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      _row(
                                        'Approved By',
                                        'Accounts($accountsApprover), DebtCollection($debtCollectionApprover)',
                                      ),
                                    ],
                                  );
                                }
                              }

                              return const SizedBox.shrink();
                            })(),
                          ],
                        ),
                      );
                    })(),
                ],
              );
            })(),
          ]),
          // Payments history table (always show)
          _section(context, 'Payments (${payments.length})', [
            payments.isEmpty
                ? const Text(
                    'No payments recorded yet.',
                    style: TextStyle(color: Colors.blueGrey),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        Colors.blue.shade50,
                      ),
                      columns: const [
                        DataColumn(label: Text('S.No')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Received At')),
                        DataColumn(label: Text('Expected')),
                        DataColumn(label: Text('Marked At')),
                        DataColumn(label: Text('Proof')),
                      ],
                      rows: [
                        for (int i = 0; i < payments.length; i++)
                          (() {
                            final m = payments[i] as Map<String, dynamic>;
                            final receivedAt = _d(m['receivedAt']);
                            final expected = _d(
                              m['expectedRemainingDate'] ?? m['expected'],
                            );
                            final marked = _d(m['markedAt']);
                            final amt = m['amount'];
                            return DataRow(
                              cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(m['type']?.toString() ?? '')),
                                DataCell(
                                  Text(
                                    amt == null
                                        ? ''
                                        : formatIndianCurrency(
                                            double.tryParse(amt.toString()) ??
                                                0.0,
                                            withSymbol: false,
                                          ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    receivedAt == null ? '' : _fmt(receivedAt),
                                  ),
                                ),
                                DataCell(
                                  Text(expected == null ? '' : _fmt(expected)),
                                ),
                                DataCell(
                                  Text(marked == null ? '' : _fmt(marked)),
                                ),
                                DataCell(
                                  m['photoProofUrl'] != null
                                      ? TextButton.icon(
                                          onPressed: () => _showPhotoDialog(
                                            context,
                                            m['photoProofUrl'],
                                            m['submittedBy'] ?? 'Unknown',
                                          ),
                                          icon: const Icon(
                                            Icons.photo,
                                            size: 16,
                                          ),
                                          label: const Text('View'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                        )
                                      : const Text('-'),
                                ),
                              ],
                            );
                          })(),
                      ],
                    ),
                  ),
          ]),
          _section(
            context,
            'Follow Ups (${followUps.length})',
            followUps.isEmpty
                ? [
                    const Text(
                      'No follow ups yet.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ]
                : [
                    // Responsive table with horizontal scroll if needed
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 40,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll(
                            Colors.blue.shade50,
                          ),
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('S.No')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Commitment Date')),
                            DataColumn(label: Text('Who Called')),
                            DataColumn(label: Text('Whom Called')),
                            DataColumn(label: Text('Notes')),
                          ],
                          rows: [
                            for (int i = 0; i < followUps.length; i++)
                              (() {
                                final m = followUps[i] as Map<String, dynamic>;
                                final date = _d(m['date']);
                                final due = _d(m['dueDate']);
                                final notes = m['notes']?.toString() ?? '';
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${i + 1}')),
                                    DataCell(
                                      Text(date == null ? '' : _fmt(date)),
                                    ),
                                    DataCell(
                                      Text(due == null ? '' : _fmt(due)),
                                    ),
                                    DataCell(
                                      Text(m['whoCalled']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      Text(m['whomCalled']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 280,
                                        child: Text(
                                          notes,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              })(),
                          ],
                        ),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: .4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  void _showPhotoDialog(
    BuildContext context,
    String photoUrl,
    String submittedBy,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Payment Proof'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submitted by: $submittedBy',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImageWidget(photoUrl),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (!photoUrl.startsWith('data:'))
                        TextButton.icon(
                          onPressed: () async {
                            await launchUrl(Uri.parse(photoUrl));
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open in Browser'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(String imageSource) {
    if (imageSource.startsWith('data:')) {
      // Base64 data URL
      try {
        final base64String = imageSource.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load base64 image',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ],
              ),
            );
          },
        );
      } catch (e) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 8),
              Text(
                'Invalid image format',
                style: TextStyle(color: Colors.red.shade600),
              ),
            ],
          ),
        );
      }
    } else {
      // Network URL
      return Image.network(
        imageSource,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          );
        },
      );
    }
  }
}
