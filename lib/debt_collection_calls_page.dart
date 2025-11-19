import 'package:flutter/material.dart';
import 'user_service.dart';
import 'call_view_page.dart';
import 'call_follow_up_page.dart';

class DebtCollectionCallsPage extends StatefulWidget {
  final String username;
  const DebtCollectionCallsPage({super.key, required this.username});

  @override
  State<DebtCollectionCallsPage> createState() =>
      _DebtCollectionCallsPageState();
}

class _DebtCollectionCallsPageState extends State<DebtCollectionCallsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls - Debt Collection'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CallRequest>>(
        stream: UserService.getCallRequestsForDebtCollection(widget.username),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading calls'));
          }
          final calls = snapshot.data ?? [];
          final completed = calls
              .where((c) => c.status == CallRequestStatus.completed)
              .toList();
          final poPending = calls
              .where((c) => c.status == CallRequestStatus.poPending)
              .toList();
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.blue.shade700,
                  tabs: [
                    Tab(
                      text: 'Completed (${completed.length})',
                      icon: const Icon(Icons.check),
                    ),
                    Tab(
                      text: 'PO Pending (${poPending.length})',
                      icon: const Icon(Icons.pending_actions),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCallsTableUI(context, completed, showPOPI: true),
                      _buildCallsTableUI(
                        context,
                        poPending,
                        showFollowUp: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallsTableUI(
    BuildContext context,
    List<CallRequest> calls, {
    bool showPOPI = false,
    bool showFollowUp = false,
  }) {
    if (calls.isEmpty) {
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
                  _tableHeaderCell('Call User'),
                  _tableHeaderCell('Call Period'),
                  _tableHeaderCell('Duration'),
                  _tableHeaderCell('Amount'),
                  _tableHeaderCell('Status'),
                  if (showFollowUp) _tableHeaderCell('Follow-up Due Date'),
                  _tableHeaderCell('Actions'),
                ],
              ),
              ...calls.map(
                (call) => TableRow(
                  children: [
                    _tableCell(
                      Text(
                        call.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    _tableCell(Text(call.requestedBy)),
                    _tableCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From: ${_formatDateOnly(call.callFromDate)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'To: ${_formatDateOnly(call.callToDate)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _tableCell(
                      Text(
                        call.durationText,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _tableCell(
                      Text(
                        '₹${call.finalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _tableCell(_buildStatusChip(call.status)),
                    if (showFollowUp) _tableCell(_getNextFollowUpDueDate(call)),
                    _tableCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_red_eye,
                              color: Colors.indigo,
                            ),
                            tooltip: 'View Details',
                            onPressed: () async {
                              // ignore: use_build_context_synchronously
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CallViewPage(callRequest: call),
                                ),
                              );
                            },
                          ),
                          if (showPOPI)
                            ElevatedButton(
                              onPressed: () => _showPOPIDialog(context, call),
                              child: const Text('PO/PI'),
                            ),
                          if (showFollowUp)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'View/Add Follow Ups',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CallFollowUpPage(
                                      username: widget.username,
                                      userType: 'debtCollection',
                                      callId: call.id,
                                      callRequest: call,
                                    ),
                                  ),
                                );
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

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

  Widget _getNextFollowUpDueDate(CallRequest call) {
    if (call.followUps.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    // Find the latest follow-up with a due date
    DateTime? nextDueDate;
    for (final followUp in call.followUps) {
      final dueDateRaw = followUp['dueDate'];
      DateTime? dueDate;

      if (dueDateRaw is String) {
        dueDate = DateTime.tryParse(dueDateRaw);
      } else if (dueDateRaw != null) {
        // Handle Timestamp if needed
        dueDate = DateTime.tryParse(dueDateRaw.toString());
      }

      if (dueDate != null) {
        if (nextDueDate == null || dueDate.isAfter(nextDueDate)) {
          nextDueDate = dueDate;
        }
      }
    }

    if (nextDueDate == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final now = DateTime.now();
    final isOverdue = nextDueDate.isBefore(now);
    final daysDiff = nextDueDate.difference(now).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDateOnly(nextDueDate),
          style: TextStyle(
            fontSize: 13,
            color: isOverdue ? Colors.red : Colors.black,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          isOverdue
              ? '${daysDiff.abs()} days overdue'
              : daysDiff == 0
              ? 'Due today'
              : 'Due in $daysDiff days',
          style: TextStyle(
            fontSize: 11,
            color: isOverdue
                ? Colors.red
                : daysDiff <= 1
                ? Colors.orange
                : Colors.grey,
          ),
        ),
      ],
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
        return 'Draft';
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
        return Colors.amber;
      case CallRequestStatus.pendingInvoice:
        return Colors.indigo;
      case CallRequestStatus.invoiceCreated:
        return Colors.cyan;
    }
  }

  void _showPOPIDialog(BuildContext context, CallRequest call) {
    showDialog(
      context: context,
      builder: (ctx) {
        String? type;
        final controller = TextEditingController();
        bool _listenerAttached = false;
        return StatefulBuilder(
          builder: (context, setState) {
            // Attach a listener that triggers the StatefulBuilder's setState
            // so the Save button re-evaluates when text changes.
            if (!_listenerAttached) {
              controller.addListener(() {
                setState(() {});
              });
              _listenerAttached = true;
            }

            return AlertDialog(
              title: const Text('PO/PI Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Does this call have a PO or PI?'),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('PO'),
                          value: 'PO',
                          groupValue: type,
                          onChanged: (v) => setState(() => type = v),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('PI'),
                          value: 'PI',
                          groupValue: type,
                          onChanged: (v) => setState(() => type = v),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: type == 'PO' ? 'PO Number' : 'PI Number',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    controller.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: type == null || controller.text.trim().isEmpty
                      ? null
                      : () async {
                          await UserService.savePOPIAndUpdateStatus(
                            callId: call.id,
                            type: type!,
                            number: controller.text.trim(),
                            givenBy: widget.username,
                          );
                          controller.dispose();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${type == 'PO' ? 'PO' : 'PI'} saved and status updated!',
                              ),
                            ),
                          );
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
