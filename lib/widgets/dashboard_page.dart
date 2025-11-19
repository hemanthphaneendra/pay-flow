import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pay_flow/widgets/pie_chart.dart';
import 'package:pay_flow/utils/indian_format.dart';

// Dashboard page and helpers extracted from home_screen.dart

class DashboardPage extends StatelessWidget {
  final String username;
  final String userType;

  const DashboardPage({
    required this.username,
    required this.userType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        // Filter for Msml user in accounts team - only show ACME company invoices
        // Filter for Kalyani user - exclude ACME company invoices
        final filteredDocs =
            (username.toLowerCase() == 'msml' && userType == 'accounts')
            ? docs.where((doc) {
                final data = doc.data();
                final company = data['company']?.toString() ?? '';
                return company == 'ACME';
              }).toList()
            : (username.toLowerCase() == 'kalyani')
            ? docs.where((doc) {
                final data = doc.data();
                final company = data['company']?.toString() ?? '';
                return company != 'ACME';
              }).toList()
            : docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overall Statistics
            _buildStatsSection(
              context,
              'Overall Statistics',
              filteredDocs,
              null,
              null,
            ),
            const SizedBox(height: 20),

            // AMC vs Call Statistics
            _buildStatsSection(
              context,
              'AMC Invoices',
              filteredDocs,
              'serviceType',
              'AMC',
            ),
            const SizedBox(height: 20),
            _buildStatsSection(
              context,
              'Call Invoices',
              filteredDocs,
              'serviceType',
              'Call',
            ),
            const SizedBox(height: 20),

            // Company-wise Statistics - show only ACME for Msml user, hide ACME for Kalyani
            if (username.toLowerCase() == 'msml' && userType == 'accounts') ...[
              _buildStatsSection(
                context,
                'ACME Invoices',
                filteredDocs,
                'company',
                'ACME',
              ),
            ] else if (username.toLowerCase() == 'kalyani') ...[
              _buildStatsSection(
                context,
                'AAMS Invoices',
                filteredDocs,
                'company',
                'AAMS',
              ),
              const SizedBox(height: 20),
              _buildStatsSection(
                context,
                'ALMAS Invoices',
                filteredDocs,
                'company',
                'ALMAS',
              ),
              const SizedBox(height: 20),
              _buildStatsSection(
                context,
                'ACME Pvt.LTD. Invoices',
                filteredDocs,
                'company',
                'ACME Pvt.LTD.',
              ),
            ] else ...[
              _buildStatsSection(
                context,
                'ACME Invoices',
                filteredDocs,
                'company',
                'ACME',
              ),
              const SizedBox(height: 20),
              _buildStatsSection(
                context,
                'AAMS Invoices',
                filteredDocs,
                'company',
                'AAMS',
              ),
              const SizedBox(height: 20),
              _buildStatsSection(
                context,
                'ALMAS Invoices',
                filteredDocs,
                'company',
                'ALMAS',
              ),
              const SizedBox(height: 20),
              _buildStatsSection(
                context,
                'ACME Pvt.LTD. Invoices',
                filteredDocs,
                'company',
                'ACME Pvt.LTD.',
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    String title,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? filterField,
    String? filterValue,
  ) {
    // Filter documents if filterField and filterValue are provided
    final filteredDocs = filterField != null && filterValue != null
        ? docs.where((doc) => doc.data()[filterField] == filterValue).toList()
        : docs;

    // Calculate statistics
    final stats = _calculateStats(filteredDocs);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Pie Chart and Status Breakdown
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 200,
                    child: CountPieChart(
                      pending: stats['pendingCount'],
                      pendingApproval: stats['pendingApprovalCount'],
                      partial: stats['partialCount'],
                      complete: stats['completeCount'],
                      onTapIndex: (idx) {},
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildStatTile(
                        context,
                        'Total Expected',
                        '₹${formatIndianCurrency(stats['totalExpected'], withSymbol: false)}',
                        Colors.blue,
                      ),
                      _buildStatTile(
                        context,
                        'Amount Received',
                        '₹${formatIndianCurrency(stats['amountReceived'], withSymbol: false)}',
                        Colors.green,
                      ),
                      _buildStatTile(
                        context,
                        'Amount Pending',
                        '₹${formatIndianCurrency(stats['amountPending'], withSymbol: false)}',
                        Colors.orange,
                      ),
                      _buildStatTile(
                        context,
                        'Amount Deducted',
                        '₹${formatIndianCurrency(stats['amountDeducted'], withSymbol: false)}',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double totalExpected = 0;
    double amountReceived = 0;
    double amountPending = 0;
    double amountDeducted = 0;
    double partialAmount = 0;

    int pendingCount = 0;
    int pendingApprovalCount = 0;
    int partialCount = 0;
    int completeCount = 0;

    for (final doc in docs) {
      final data = doc.data();
      final status = data['status']?.toString() ?? 'pending';

      // Count statuses
      if (status == 'pending') {
        pendingCount++;
      } else if (status == 'pending_approval' ||
          status == 'pending_partial_approval') {
        pendingApprovalCount++;
      } else if (status == 'partial') {
        partialCount++;
      } else if (status == 'complete') {
        completeCount++;
      }

      // Calculate amounts
      final total = _parseDouble(data['totalAmount']);
      final received = _parseDouble(data['receivedAmount']);

      // Calculate deduction amount using same logic as your view page
      // Check for new multi-deduction format
      final deductionsList = data['deductions'] as List?;
      final hasNewDeductions =
          deductionsList != null && deductionsList.isNotEmpty;

      // Check for old single deduction format (backward compatibility)
      final hasOldDeductionReason =
          data['deduction'] != null &&
          data['deduction'].toString().isNotEmpty &&
          data['deduction'].toString() != 'N/A';

      final deduction =
          (hasNewDeductions || hasOldDeductionReason) && received < total
          ? total - received
          : 0.0;

      totalExpected += total;
      amountReceived += received;

      // Calculate pending amount and deductions based on status
      if (status == 'pending' ||
          status == 'pending_approval' ||
          status == 'pending_partial_approval') {
        // For pending invoices, full amount is pending
        amountPending += total;
      } else if (status == 'partial') {
        // For partial invoices, use the pendingAmount field if available, otherwise calculate
        final pendingFromField = _parseDouble(data['pendingAmount']);
        amountPending += pendingFromField > 0
            ? pendingFromField
            : (total - received);
        partialAmount += received;
        // Deductions can apply to partial invoices too
        amountDeducted += deduction;
      } else if (status == 'complete') {
        // For complete invoices, count deductions
        amountDeducted += deduction;
      }
    }

    return {
      'totalExpected': totalExpected,
      'amountReceived': amountReceived,
      'amountPending': amountPending,
      'amountDeducted': amountDeducted,
      'partialAmount': partialAmount,
      'pendingCount': pendingCount,
      'pendingApprovalCount': pendingApprovalCount,
      'partialCount': partialCount,
      'completeCount': completeCount,
    };
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
