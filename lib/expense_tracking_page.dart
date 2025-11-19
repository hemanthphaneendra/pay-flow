import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class ExpenseTrackingPage extends StatefulWidget {
  final String username;

  const ExpenseTrackingPage({super.key, required this.username});

  @override
  State<ExpenseTrackingPage> createState() => _ExpenseTrackingPageState();
}

class _ExpenseTrackingPageState extends State<ExpenseTrackingPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? selectedUser;
  List<String> callUsers = [];
  List<CallRequest> filteredCalls = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCallUsers();
  }

  Future<void> _loadCallUsers() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('call_requests')
          .get();

      final users = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final user = data['requestedBy']?.toString();
        if (user != null && user.isNotEmpty) {
          users.add(user);
        }
      }

      setState(() {
        callUsers = users.toList()..sort();
        if (callUsers.isNotEmpty && selectedUser == null) {
          selectedUser = callUsers.first;
        }
      });

      if (selectedUser != null) {
        await _loadCallsForUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCallsForUser() async {
    if (selectedUser == null) return;

    setState(() => isLoading = true);
    try {
      final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final monthEnd = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        1,
      ).subtract(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('call_requests')
          .where('requestedBy', isEqualTo: selectedUser)
          .get();

      final calls = <CallRequest>[];
      for (final doc in snapshot.docs) {
        final call = CallRequest.fromFirestore(doc);

        // Filter by status
        if (![
          CallRequestStatus.completed,
          CallRequestStatus.poPending,
          CallRequestStatus.pendingInvoice,
          CallRequestStatus.invoiceCreated,
        ].contains(call.status)) {
          continue;
        }

        // Filter by month
        if (call.callFromDate.isBefore(monthStart) ||
            call.callFromDate.isAfter(monthEnd)) {
          continue;
        }

        calls.add(call);
      }

      setState(() {
        filteredCalls = calls;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading calls: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (date != null) {
      setState(() {
        selectedMonth = DateTime(date.year, date.month);
      });
      await _loadCallsForUser();
    }
  }

  double _calculateTotalExpenses() {
    return filteredCalls.fold(
      0.0,
      (sum, call) =>
          sum + call.expenses.fold(0.0, (expSum, exp) => expSum + exp.amount),
    );
  }

  double _calculateTotalCredited() {
    return filteredCalls
        .where((call) => call.isCredited)
        .fold(0.0, (sum, call) => sum + call.finalAmount);
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildSummaryCard() {
    final totalExpenses = _calculateTotalExpenses();
    final totalCredited = _calculateTotalCredited();
    final balance = totalCredited - totalExpenses;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary for ${selectedUser ?? 'Unknown'} - ${selectedMonth.month}/${selectedMonth.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Expenses',
                    '₹${_formatAmount(totalExpenses)}',
                    Colors.red.shade600,
                    Icons.money_off,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Credited',
                    '₹${_formatAmount(totalCredited)}',
                    Colors.green.shade600,
                    Icons.account_balance_wallet,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    balance >= 0 ? 'User Owes' : 'We Owe',
                    '₹${_formatAmount(balance.abs())}',
                    balance >= 0
                        ? Colors.blue.shade600
                        : Colors.orange.shade600,
                    balance >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallsTable() {
    if (filteredCalls.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_disabled, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No calls found for selected criteria',
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

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Call Details (${filteredCalls.length} calls)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height:
                MediaQuery.of(context).size.height *
                0.6, // Limit height to 60% of screen
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 32,
                  ),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: MaterialStateProperty.all(
                      Colors.grey.shade100,
                    ),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    dataTextStyle: const TextStyle(color: Colors.black87),
                    columns: const [
                      DataColumn(
                        label: Expanded(child: Text('Customer')),
                        tooltip: 'Customer Name',
                      ),
                      DataColumn(
                        label: Expanded(child: Text('Call Period')),
                        tooltip: 'From Date - To Date',
                      ),
                      DataColumn(
                        label: Text('Status'),
                        tooltip: 'Current Status',
                      ),
                      DataColumn(
                        label: Text('Call Amount'),
                        numeric: true,
                        tooltip: 'Final Amount',
                      ),
                      DataColumn(
                        label: Text('Expenses'),
                        numeric: true,
                        tooltip: 'Total Expenses',
                      ),
                      DataColumn(
                        label: Text('Credited'),
                        numeric: true,
                        tooltip: 'Amount Credited',
                      ),
                    ],
                    rows: filteredCalls.map((call) {
                      final expenses = call.expenses.fold(
                        0.0,
                        (sum, exp) => sum + exp.amount,
                      );
                      return DataRow(
                        color: MaterialStateProperty.resolveWith<Color?>((
                          states,
                        ) {
                          if (states.contains(MaterialState.hovered)) {
                            return Colors.blue.shade50;
                          }
                          return null;
                        }),
                        cells: [
                          DataCell(
                            Container(
                              width: 180,
                              child: Tooltip(
                                message: call.customerName,
                                child: Text(
                                  call.customerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 160,
                              child: Text(
                                '${_formatDate(call.callFromDate)} -\n${_formatDate(call.callToDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 120,
                              child: _buildStatusChip(call.status),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 100,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '₹${_formatAmount(call.finalAmount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 100,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '₹${_formatAmount(expenses)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: expenses > 0
                                      ? Colors.red.shade600
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 100,
                              alignment: Alignment.centerRight,
                              child: Text(
                                call.isCredited
                                    ? '₹${_formatAmount(call.finalAmount)}'
                                    : '₹0.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: call.isCredited
                                      ? Colors.green.shade600
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(CallRequestStatus status) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  String _getStatusText(CallRequestStatus status) {
    switch (status) {
      case CallRequestStatus.completed:
        return 'Completed';
      case CallRequestStatus.poPending:
        return 'PO Pending';
      case CallRequestStatus.pendingInvoice:
        return 'Pending Invoice';
      case CallRequestStatus.invoiceCreated:
        return 'Invoice Created';
      default:
        return status.name;
    }
  }

  Color _getStatusColor(CallRequestStatus status) {
    switch (status) {
      case CallRequestStatus.completed:
        return Colors.teal;
      case CallRequestStatus.poPending:
        return Colors.brown;
      case CallRequestStatus.pendingInvoice:
        return Colors.orangeAccent;
      case CallRequestStatus.invoiceCreated:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Expenses'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Controls
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUser,
                        decoration: const InputDecoration(
                          labelText: 'Select User',
                          border: OutlineInputBorder(),
                        ),
                        items: callUsers
                            .map(
                              (user) => DropdownMenuItem(
                                value: user,
                                child: Text(user),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedUser = value;
                          });
                          if (value != null) {
                            _loadCallsForUser();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectMonth,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          '${selectedMonth.month}/${selectedMonth.year}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Summary
            if (selectedUser != null && !isLoading) _buildSummaryCard(),

            // Loading indicator or Calls Table
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else
              _buildCallsTable(),
          ],
        ),
      ),
    );
  }
}
