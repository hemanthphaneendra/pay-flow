import 'package:flutter/material.dart';

import 'invoices_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _isSameDate(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

class WorkProcessPage extends StatefulWidget {
  final String username;
  final String userType;

  const WorkProcessPage({
    required this.username,
    required this.userType,
    super.key,
  });

  @override
  State<WorkProcessPage> createState() => _WorkProcessPageState();
}

class _WorkProcessPageState extends State<WorkProcessPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Filter controllers
  final TextEditingController _invoiceNoController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  DateTime? _selectedDueDate;
  bool _showOnlyWithPaymentAdvice = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceNoController.dispose();
    _companyController.dispose();
    _customerController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _invoiceNoController.clear();
      _companyController.clear();
      _customerController.clear();
      _dueDateController.clear();
      _selectedDueDate = null;
      _showOnlyWithPaymentAdvice = false;
    });
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _selectedDueDate = date;
        _dueDateController.text = _fmt(date);
      });
    }
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Filter Invoices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _invoiceNoController,
                    decoration: InputDecoration(
                      labelText: 'Invoice Number',
                      prefixIcon: Icon(
                        Icons.receipt_long,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _companyController,
                    decoration: InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(
                        Icons.business,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _customerController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: Icon(
                        Icons.person,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _dueDateController,
                    decoration: InputDecoration(
                      labelText: 'Due Date',
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    readOnly: true,
                    onTap: _selectDueDate,
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: Material(
                    color: _showOnlyWithPaymentAdvice
                        ? Colors.blue.shade600
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: _showOnlyWithPaymentAdvice ? 2 : 0,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showOnlyWithPaymentAdvice =
                              !_showOnlyWithPaymentAdvice;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 47,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _showOnlyWithPaymentAdvice
                                ? Colors.blue.shade600
                                : Colors.grey.shade300,
                            width: _showOnlyWithPaymentAdvice ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              _showOnlyWithPaymentAdvice
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: _showOnlyWithPaymentAdvice
                                  ? Colors.white
                                  : Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Payment Advice Provided',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _showOnlyWithPaymentAdvice
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  fontWeight: _showOnlyWithPaymentAdvice
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String filterStatus) {
    return InvoicesTab(
      filterStatus: filterStatus,
      username: widget.username,
      userType: widget.userType,
      invoiceNoFilter: _invoiceNoController.text,
      companyFilter: _companyController.text,
      customerFilter: _customerController.text,
      dueDateFilter: _selectedDueDate,
      paymentAdviceFilter: _showOnlyWithPaymentAdvice,
    );
  }

  // Build a Tab that displays a live count for the given invoice status.
  Widget _tabWithCount(String label, String filterStatus) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Tab(text: label);
        final docs = snapshot.data!.docs;

        int count = 0;
        for (final doc in docs) {
          final data = doc.data();

          // Filter for Msml user in accounts team - only count ACME company invoices
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

          final status = data['status']?.toString() ?? '';

          bool matchesStatus = false;
          if (filterStatus == 'pending') {
            matchesStatus = status == 'pending';
          } else if (filterStatus == 'pending_approval') {
            matchesStatus =
                status == 'pending_approval' ||
                status == 'pending_partial_approval';
          } else {
            matchesStatus = status == filterStatus;
          }

          if (!matchesStatus) continue;

          // Apply client-side filters same as InvoicesTab
          final invoiceNo = (data['invoiceNo'] ?? '').toString();
          final company = (data['company'] ?? '').toString();
          final customer = (data['customerName'] ?? '').toString();

          bool matchesFilters = true;
          if (_invoiceNoController.text.isNotEmpty) {
            matchesFilters =
                matchesFilters &&
                invoiceNo.toLowerCase().contains(
                  _invoiceNoController.text.toLowerCase(),
                );
          }
          if (_companyController.text.isNotEmpty) {
            matchesFilters =
                matchesFilters &&
                company.toLowerCase().contains(
                  _companyController.text.toLowerCase(),
                );
          }
          if (_customerController.text.isNotEmpty) {
            matchesFilters =
                matchesFilters &&
                customer.toLowerCase().contains(
                  _customerController.text.toLowerCase(),
                );
          }

          if (_selectedDueDate != null) {
            DateTime? target;
            final dueTs = data['dueDate'];
            if (dueTs is Timestamp) target = dueTs.toDate();
            if (filterStatus == 'partial') {
              final expTs = data['expectedRemainingDate'];
              if (expTs is Timestamp) target = expTs.toDate();
            }
            if (target == null) {
              matchesFilters = false;
            } else {
              if (!_isSameDate(target, _selectedDueDate!))
                matchesFilters = false;
            }
          }

          if (_showOnlyWithPaymentAdvice) {
            final paymentAdviceProvided = data['paymentAdviceProvided'] == true;
            if (!paymentAdviceProvided) matchesFilters = false;
          }

          if (matchesFilters) count++;
        }

        return Tab(text: '$label (${count})');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          // Filter section as a sliver
          SliverToBoxAdapter(child: _buildFilterSection()),
          // Sticky TabBar
          SliverAppBar(
            pinned: true,
            floating: false,
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                _tabWithCount('Pending', 'pending'),
                _tabWithCount('Pending Approval', 'pending_approval'),
                _tabWithCount('Partial', 'partial'),
                _tabWithCount('Completed', 'complete'),
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('pending'),
          _buildTabContent('pending_approval'),
          _buildTabContent('partial'),
          _buildTabContent('complete'),
        ],
      ),
    );
  }
}
