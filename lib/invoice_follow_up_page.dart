import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'invoice_form_page.dart';
import 'utils/indian_format.dart';

class InvoiceFollowUpPage extends StatefulWidget {
  final String username;
  final String userType;
  final String invoiceId;
  final Map<String, dynamic> initialData;
  const InvoiceFollowUpPage({
    super.key,
    required this.username,
    required this.userType,
    required this.invoiceId,
    required this.initialData,
  });

  @override
  State<InvoiceFollowUpPage> createState() => _InvoiceFollowUpPageState();
}

class _InvoiceFollowUpPageState extends State<InvoiceFollowUpPage> {
  final _whoCalledCtrl = TextEditingController();
  final _whomCalledCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scrollController = ScrollController();
  // Separate controller for the horizontal table scrolling and scrollbar
  final _tableScrollController = ScrollController();
  DateTime _callDate = DateTime.now();
  DateTime? _followUpDueDate;
  bool _markPaid = false;
  bool _partial = false;
  bool _saving = false;

  // Photo proof related variables
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _whoCalledCtrl.dispose();
    _whomCalledCtrl.dispose();
    _notesCtrl.dispose();
    _scrollController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  /// Check if current user can change completion status
  bool _canChangeCompletionStatus(String status, Map<String, dynamic> data) {
    // Admin and call users cannot change payment status (read-only)
    if (widget.userType == 'admin' || widget.userType == 'call') return false;

    // If already complete, no one can change
    if (status == 'complete') return false;

    // Accounts team must wait for payment advice decision from debt collection
    if (widget.userType == 'accounts') {
      final paymentAdviceProvided = data['paymentAdviceProvided'] as bool?;
      if (paymentAdviceProvided == null) {
        return false; // Must wait for debt collection to decide on payment advice
      }
    }

    // If invoice is already partial, allow completion (collecting remaining payment)
    if (status == 'partial') {
      // For partial invoices, allow accounts to complete if debtCollection hasn't approved completion yet
      if (widget.userType == 'accounts') {
        final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
        final debtCollectionApproval = approvals['debtCollection'];
        return debtCollectionApproval?['approved'] != true;
      }
      // For debtCollection, allow completion if accounts has approved completion first
      if (widget.userType == 'debtCollection') {
        final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
        final accountsApproval = approvals['accounts'];
        return accountsApproval?['approved'] == true;
      }
      return false;
    }

    // For pending_approval status, check if it's a completion of partial payment
    if (status == 'pending_approval') {
      // If accounts has already approved completion, debtCollection can complete
      final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
      final accountsApproval = approvals['accounts'];

      if (widget.userType == 'debtCollection' &&
          accountsApproval?['approved'] == true) {
        return true;
      }

      // For accounts, if they haven't approved yet, they can
      if (widget.userType == 'accounts' &&
          accountsApproval?['approved'] != true) {
        return true;
      }

      return false;
    }

    // Check if accounts team has already chosen partial payment for other statuses
    final partialApprovals =
        data['partialApprovals'] as Map<String, dynamic>? ?? {};
    final accountsPartialApproval = partialApprovals['accounts'];
    if (accountsPartialApproval?['approved'] == true &&
        status != 'pending_approval') {
      return false;
    }

    // For other statuses, accounts can initiate the approval process
    return widget.userType == 'accounts';
  }

  /// Check if current user can change partial payment status
  bool _canChangePartialStatus(String status, Map<String, dynamic> data) {
    // Admin and call users cannot change payment status (read-only)
    if (widget.userType == 'admin' || widget.userType == 'call') return false;

    // If complete, no one can change to partial
    if (status == 'complete') return false;

    // Accounts team must wait for payment advice decision from debt collection
    if (widget.userType == 'accounts') {
      final paymentAdviceProvided = data['paymentAdviceProvided'] as bool?;
      if (paymentAdviceProvided == null) {
        return false; // Must wait for debt collection to decide on payment advice
      }
    }

    // Check if accounts team has already chosen complete payment - if so, can't choose partial
    final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
    final accountsApproval = approvals['accounts'];
    if (accountsApproval?['approved'] == true) return false;

    // Sequential approval: Accounts must approve first
    if (widget.userType == 'debtCollection') {
      // DebtCollection can only approve if accounts has approved first
      final partialApprovals =
          data['partialApprovals'] as Map<String, dynamic>? ?? {};
      final accountsPartialApproval = partialApprovals['accounts'];
      if (accountsPartialApproval?['approved'] != true) return false;
    }

    // If not in pending_partial_approval state, accounts can initiate
    if (status != 'pending_partial_approval') {
      return widget.userType == 'accounts';
    }

    final partialApprovals =
        data['partialApprovals'] as Map<String, dynamic>? ?? {};
    final currentUserTeamApproval = partialApprovals[widget.userType];
    final otherTeamType = widget.userType == 'accounts'
        ? 'debtCollection'
        : 'accounts';
    final otherTeamApproval = partialApprovals[otherTeamType];

    // If current user's team hasn't approved yet, they can approve
    if (currentUserTeamApproval?['approved'] != true) return true;

    // If current user's team has approved but other team hasn't,
    // current team cannot change until other team approves
    if (otherTeamApproval?['approved'] != true) return false;

    // If both have approved, it should be partial already
    return true;
  }

  /// Get appropriate subtitle text for completion switch
  String _getCompletionSubtitle(String status, Map<String, dynamic> data) {
    if (widget.userType == 'admin' || widget.userType == 'call') {
      return 'Only Accounts and Debt Collection can approve payments';
    }

    if (_markPaid || status == 'complete') {
      // Show who proposed and who approved
      final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
      final completionPayment =
          data['completionPayment'] as Map<String, dynamic>?;
      final accountsApprover = approvals['accounts']?['approvedBy'];
      final debtCollectionApprover = approvals['debtCollection']?['approvedBy'];

      if (accountsApprover != null && debtCollectionApprover != null) {
        if (completionPayment != null) {
          final proposedBy = completionPayment['proposedBy'];
          final proposedByTeam = completionPayment['proposedByTeam'];
          final approverTeam = proposedByTeam == 'accounts'
              ? 'debtCollection'
              : 'accounts';
          final approver = approverTeam == 'accounts'
              ? accountsApprover
              : debtCollectionApprover;
          return 'Proposed by $proposedByTeam ($proposedBy), Approved by $approverTeam ($approver)';
        } else {
          return 'Completed by: Accounts($accountsApprover), DebtCollection($debtCollectionApprover)';
        }
      }
      return 'Invoice marked as complete';
    }

    // Handle partial payment completion
    if (status == 'partial') {
      if (widget.userType == 'accounts') {
        final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
        final debtCollectionApproval = approvals['debtCollection'];
        if (debtCollectionApproval?['approved'] == true) {
          return 'DebtCollection has already approved completion';
        }
        return 'Mark remaining payment as complete';
      }
      if (widget.userType == 'debtCollection') {
        final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
        final accountsApproval = approvals['accounts'];
        if (accountsApproval?['approved'] != true) {
          return 'Waiting for Accounts team to approve completion first';
        }
        return 'Complete the remaining payment';
      }
    }

    // Handle pending approval status (including completion of partial payments)
    if (status == 'pending_approval') {
      final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
      final accountsApproval = approvals['accounts'];
      final debtCollectionApproval = approvals['debtCollection'];

      if (accountsApproval?['approved'] == true &&
          debtCollectionApproval?['approved'] != true) {
        final accountsApprover = accountsApproval?['approvedBy'];
        return 'Accounts approved by $accountsApprover. Waiting for Debt Collection approval.';
      }

      if (widget.userType == 'debtCollection') {
        if (accountsApproval?['approved'] != true) {
          return 'Waiting for Accounts team to approve completion first';
        }
        return 'Approve completion to finalize payment';
      }
    }

    // Check if accounts has already chosen partial payment (only for non-pending invoices)
    if (status != 'pending_approval') {
      final partialApprovals =
          data['partialApprovals'] as Map<String, dynamic>? ?? {};
      final accountsPartialApproval = partialApprovals['accounts'];
      if (accountsPartialApproval?['approved'] == true) {
        return 'Cannot select complete - Accounts already chose partial payment';
      }
    }

    return widget.userType == 'accounts'
        ? 'Mark payment as complete'
        : 'Invoice currently: $status';
  }

  /// Get appropriate subtitle text for partial payment switch
  String _getPartialSubtitle(String status, Map<String, dynamic> data) {
    if (widget.userType == 'admin' || widget.userType == 'call') {
      return 'Only Accounts and Debt Collection can approve payments';
    }

    if (_partial || status == 'partial') {
      // Show who proposed and who approved
      final partialApprovals =
          data['partialApprovals'] as Map<String, dynamic>? ?? {};
      final partialPayment = data['partialPayment'] as Map<String, dynamic>?;
      final accountsApprover = partialApprovals['accounts']?['approvedBy'];
      final debtCollectionApprover =
          partialApprovals['debtCollection']?['approvedBy'];

      if (accountsApprover != null && debtCollectionApprover != null) {
        if (partialPayment != null) {
          final proposedBy = partialPayment['proposedBy'];
          final proposedByTeam = partialPayment['proposedByTeam'];
          final approverTeam = proposedByTeam == 'accounts'
              ? 'debtCollection'
              : 'accounts';
          final approver = approverTeam == 'accounts'
              ? accountsApprover
              : debtCollectionApprover;
          return 'Proposed by $proposedByTeam ($proposedBy), Approved by $approverTeam ($approver)';
        } else {
          return 'Partial approved by: Accounts($accountsApprover), DebtCollection($debtCollectionApprover)';
        }
      }
      return 'Invoice marked partial';
    }

    // Check if accounts has already chosen complete payment
    final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
    final accountsApproval = approvals['accounts'];
    if (accountsApproval?['approved'] == true) {
      return 'Cannot select partial - Accounts already chose complete payment';
    }

    if (widget.userType == 'debtCollection') {
      final partialApprovals =
          data['partialApprovals'] as Map<String, dynamic>? ?? {};
      final accountsPartialApproval = partialApprovals['accounts'];
      if (accountsPartialApproval?['approved'] != true) {
        return 'Waiting for Accounts team to approve partial payment first';
      }
    }

    if (status == 'pending_partial_approval') {
      final partialApprovals =
          data['partialApprovals'] as Map<String, dynamic>? ?? {};
      final partialPayment = data['partialPayment'] as Map<String, dynamic>?;
      final proposedAmount = partialPayment?['amount'];
      final amountText = proposedAmount != null
          ? proposedAmount.toString()
          : 'Unknown';

      final accountsPartialApproval = partialApprovals['accounts'];
      final debtCollectionPartialApproval = partialApprovals['debtCollection'];

      if (accountsPartialApproval?['approved'] == true &&
          debtCollectionPartialApproval?['approved'] != true) {
        final accountsApprover = accountsPartialApproval?['approvedBy'];
        return 'Accounts($accountsApprover) proposed ₹$amountText. Approve to finalize.';
      }
      if (debtCollectionPartialApproval?['approved'] == true &&
          accountsPartialApproval?['approved'] != true) {
        final debtCollectionApprover =
            debtCollectionPartialApproval?['approvedBy'];
        return 'DebtCollection($debtCollectionApprover) proposed ₹$amountText. Waiting for Accounts approval.';
      }
    }

    return widget.userType == 'accounts'
        ? 'Mark a partial payment'
        : 'Waiting for approval process';
  }

  /// Check if current user can edit invoice details
  bool _canEditInvoiceDetails(String status, Map<String, dynamic> data) {
    // Admin and call users cannot edit (read-only)
    if (widget.userType == 'admin' || widget.userType == 'call') return false;

    // If invoice is complete, no one can edit
    if (status == 'complete') return false;

    // If status is pending_approval or pending_partial_approval,
    // check if current user's team has already approved
    if (status == 'pending_approval') {
      final approvals = data['approvals'] as Map<String, dynamic>? ?? {};
      final currentUserTeamApproval = approvals[widget.userType];
      // If current team has approved, they can't edit until process completes
      if (currentUserTeamApproval?['approved'] == true) return false;
    }

    if (status == 'pending_partial_approval') {
      final partialApprovals =
          data['partialApprovals'] as Map<String, dynamic>? ?? {};
      final currentUserTeamApproval = partialApprovals[widget.userType];
      // If current team has approved partial, they can't edit until process completes
      if (currentUserTeamApproval?['approved'] == true) return false;
    }

    // For all other statuses, user can edit
    return true;
  }

  Future<void> _handlePartialToggle(bool v, String status) async {
    if (status == 'complete') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice already marked complete')),
      );
      return;
    }
    if (!v) {
      setState(() => _partial = false);
      return;
    }

    // For accounts team, require photo proof before proceeding (only for new proposals)
    final docRefCheck = FirebaseFirestore.instance
        .collection('invoices')
        .doc(widget.invoiceId);
    final snapCheck = await docRefCheck.get();
    if (!mounted) return;
    final invCheck = snapCheck.data() ?? {};
    final existingPartialPaymentCheck =
        invCheck['partialPayment'] as Map<String, dynamic>?;
    final isApprovalModeCheck = existingPartialPaymentCheck != null;

    if (widget.userType == 'accounts' && !isApprovalModeCheck) {
      final hasPhotoProof = await _showPhotoProofDialog();
      if (!hasPhotoProof) {
        setState(() => _partial = false);
        return;
      }
    } else if (isApprovalModeCheck) {
    } else {
      // Debt collection team - no photo required
    }

    final docRef = FirebaseFirestore.instance
        .collection('invoices')
        .doc(widget.invoiceId);
    final snap = await docRef.get();
    if (!mounted) return;
    final inv = snap.data() ?? {};
    final total = (inv['totalAmount'] is num)
        ? (inv['totalAmount'] as num).toDouble()
        : (inv['totalAmount'] != null
              ? double.tryParse(inv['totalAmount'].toString())
              : null);

    // Determine the effective total - prefer pendingAmount when invoice has partial payments
    double? effectiveTotal;
    final hasPendingAmount = inv['pendingAmount'] != null;
    if (status == 'partial' ||
        (status == 'pending_approval' && hasPendingAmount)) {
      final p = (inv['pendingAmount'] is num)
          ? (inv['pendingAmount'] as num).toDouble()
          : (inv['pendingAmount'] != null
                ? double.tryParse(inv['pendingAmount'].toString())
                : null);
      if (p != null) {
        effectiveTotal = p;
      } else {
        // Fallback: calculate from cumulative partial payments
        final payments = inv['payments'] as List<dynamic>? ?? [];
        double cumulativeReceived = 0.0;
        for (final payment in payments) {
          if (payment is Map &&
              payment['type'] == 'partial' &&
              payment['amount'] != null) {
            final amount = payment['amount'];
            if (amount is num) {
              cumulativeReceived += amount.toDouble();
            }
          }
        }
        if (total != null) {
          effectiveTotal = total - cumulativeReceived;
        }
      }
    } else {
      effectiveTotal = total;
    }

    // Check if there's already a proposed partial payment
    final existingPartialPayment =
        inv['partialPayment'] as Map<String, dynamic>?;
    final isApprovalMode = existingPartialPayment != null;

    final map = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        if (isApprovalMode) {
          // Show approval dialog for existing proposal
          final proposedAmount = existingPartialPayment['amount'];
          final proposedBy = existingPartialPayment['proposedBy'];
          final proposedByTeam = existingPartialPayment['proposedByTeam'];
          final photoProofUrl =
              existingPartialPayment['photoProofUrl'] as String?;
          final proposedDeductions =
              existingPartialPayment['deductions'] as List?;

          // Initialize expected date from existing partial payment if available
          DateTime? expectedDate =
              existingPartialPayment['expectedRemainingDate'] != null
              ? (existingPartialPayment['expectedRemainingDate'] is Timestamp
                    ? (existingPartialPayment['expectedRemainingDate']
                              as Timestamp)
                          .toDate()
                    : existingPartialPayment['expectedRemainingDate']
                          as DateTime?)
              : null;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              // expectedDate is declared in the outer closure so it persists across setDialogState calls
              return AlertDialog(
                title: const Text('Approve Partial Payment'),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (effectiveTotal != null)
                          Text(
                            'Invoice total: ₹${formatIndianCurrency(effectiveTotal, withSymbol: false)}',
                          ),
                        const SizedBox(height: 8),
                        Text('Proposed by: $proposedByTeam ($proposedBy)'),
                        const SizedBox(height: 8),
                        Text('Proposed amount: ₹${proposedAmount.toString()}'),

                        // Show deductions (new format)
                        if (proposedDeductions != null &&
                            proposedDeductions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Deductions:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...proposedDeductions.map((deduction) {
                            final deductionMap =
                                deduction as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('• ${deductionMap['type']}'),
                                      if (deductionMap['amount'] != null &&
                                          deductionMap['amount']
                                              .toString()
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Text(
                                            '(₹${deductionMap['amount']})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (deductionMap['notes'] != null &&
                                      deductionMap['notes']
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: Text(
                                        deductionMap['notes'],
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],

                        if (photoProofUrl != null) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () async {
                              await _showPhotoVerificationDialog(
                                photoProofUrl,
                                proposedBy,
                              );
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('View Payment Proof'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                            ),
                          ),
                        ],

                        // Add expected date field for debt collection when approving accounts proposal
                        if (widget.userType == 'debtCollection' &&
                            proposedByTeam == 'accounts') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Set Expected Remaining Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        expectedDate == null
                                            ? 'Expected remaining date: not set'
                                            : 'Expected: ${_fmt(expectedDate!)}',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final pick = await showDatePicker(
                                          context: ctx,
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 365 * 2),
                                          ),
                                          initialDate: DateTime.now(),
                                        );
                                        if (pick != null) {
                                          setDialogState(
                                            () => expectedDate = pick,
                                          );
                                        }
                                        print(expectedDate);
                                      },
                                      child: const Text('Pick Date'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Text(
                          photoProofUrl != null
                              ? 'Please verify the payment proof before approving.'
                              : 'Do you approve this partial payment?',
                          style: TextStyle(
                            fontWeight: photoProofUrl != null
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      // Validate expected date for debt collection approving accounts proposal
                      if (widget.userType == 'debtCollection' &&
                          proposedByTeam == 'accounts' &&
                          expectedDate == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please set expected remaining date'),
                          ),
                        );
                        return;
                      }

                      // Use the expected date set by debt collection, or fallback to original
                      DateTime expectedDateToUse;

                      if (expectedDate != null) {
                        expectedDateToUse = expectedDate!;
                      } else {
                        final originalExpectedDate =
                            existingPartialPayment['expectedRemainingDate'];

                        if (originalExpectedDate is Timestamp) {
                          expectedDateToUse = originalExpectedDate.toDate();
                        } else if (originalExpectedDate is DateTime) {
                          expectedDateToUse = originalExpectedDate;
                        } else {
                          // Fallback to 30 days from now if no date found
                          expectedDateToUse = DateTime.now().add(
                            const Duration(days: 30),
                          );
                        }
                      }

                      Navigator.of(ctx).pop({
                        'received': proposedAmount is num
                            ? proposedAmount.toDouble()
                            : 0.0,
                        'expectedDate': expectedDateToUse,
                      });
                    },
                    child: const Text('Approve'),
                  ),
                ],
              );
            },
          );
        }

        // Show input dialog for new proposal
        final recvCtrl = TextEditingController();
        DateTime? expectedDate;

        // Multi-deduction system with amount fields
        Set<String> selectedDeductions = <String>{};
        Map<String, TextEditingController> deductionNotesControllers = {};
        Map<String, TextEditingController> deductionAmountControllers = {};
        TextEditingController othersController = TextEditingController();
        TextEditingController othersNotesController = TextEditingController();
        TextEditingController othersAmountController = TextEditingController();

        final deductionOptions = [
          'TDS',
          'Manpower Absent',
          'Instrument Not Working',
          'Security Deposit',
          'Others',
        ];

        return StatefulBuilder(
          builder: (ctx2, setState2) {
            return AlertDialog(
              title: const Text('Partial Payment'),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 600),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (effectiveTotal != null)
                        Text(
                          'Invoice total: ₹${formatIndianCurrency(effectiveTotal, withSymbol: false)}',
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: recvCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount received now',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState2(() {}),
                      ),
                      const SizedBox(height: 8),

                      // Deductions section (always visible for partial payments)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount is less than total. Select deduction(s) and add notes for each.',
                          ),
                          const SizedBox(height: 12),
                          // Multiple deduction selection
                          ...deductionOptions.map((deductionOption) {
                            final isSelected = selectedDeductions.contains(
                              deductionOption,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    title: Text(deductionOption),
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState2(() {
                                        if (value == true) {
                                          selectedDeductions.add(
                                            deductionOption,
                                          );
                                          if (deductionOption != 'Others') {
                                            deductionNotesControllers[deductionOption] =
                                                TextEditingController();
                                            deductionAmountControllers[deductionOption] =
                                                TextEditingController();
                                          }
                                        } else {
                                          selectedDeductions.remove(
                                            deductionOption,
                                          );
                                          if (deductionOption != 'Others') {
                                            deductionNotesControllers[deductionOption]
                                                ?.dispose();
                                            deductionNotesControllers.remove(
                                              deductionOption,
                                            );
                                            deductionAmountControllers[deductionOption]
                                                ?.dispose();
                                            deductionAmountControllers.remove(
                                              deductionOption,
                                            );
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  if (isSelected) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        children: [
                                          if (deductionOption == 'Others') ...[
                                            TextField(
                                              controller: othersController,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Specify Other Deduction',
                                                hintText:
                                                    'Enter custom deduction type',
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: othersNotesController,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Notes for Other Deduction',
                                              ),
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller:
                                                  othersAmountController,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Amount for Other Deduction',
                                                hintText:
                                                    'Enter amount deducted',
                                                prefixText: '₹',
                                              ),
                                              keyboardType:
                                                  TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                            ),
                                          ] else ...[
                                            TextField(
                                              controller:
                                                  deductionNotesControllers[deductionOption]!,
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Notes for $deductionOption',
                                                hintText:
                                                    'Enter details about this deduction',
                                              ),
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller:
                                                  deductionAmountControllers[deductionOption]!,
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Amount for $deductionOption',
                                                hintText:
                                                    'Enter amount deducted',
                                                prefixText: '₹',
                                              ),
                                              keyboardType:
                                                  TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.userType == 'debtCollection') ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                expectedDate == null
                                    ? 'Expected remaining date: not set'
                                    : 'Expected: ${_fmt(expectedDate!)}',
                                style: TextStyle(
                                  color: expectedDate != null
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final pick = await showDatePicker(
                                  context: ctx2,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 2),
                                  ),
                                  initialDate: expectedDate ?? DateTime.now(),
                                );
                                if (pick != null) {
                                  setState2(() {
                                    expectedDate = pick;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Pick Date'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Expected remaining date will be set by the Debt Collection team during approval.',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, null),
                  child: const Text('Cancel'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final recv = double.tryParse(
                      recvCtrl.text.trim().replaceAll(',', ''),
                    );
                    if (recv == null) {
                      ScaffoldMessenger.of(ctx2).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }
                    if (widget.userType == 'debtCollection' &&
                        expectedDate == null) {
                      ScaffoldMessenger.of(ctx2).showSnackBar(
                        const SnackBar(
                          content: Text('Pick expected remaining date'),
                        ),
                      );
                      return;
                    }

                    // Validate deduction selections if any are selected
                    if (selectedDeductions.isNotEmpty) {
                      for (final selectedDeduction in selectedDeductions) {
                        if (selectedDeduction == 'Others') {
                          if (othersController.text.trim().isEmpty ||
                              othersAmountController.text.trim().isEmpty ||
                              othersNotesController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx2).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please specify the "Others" deduction type, amount, and add notes',
                                ),
                              ),
                            );
                            return;
                          }
                        } else {
                          final notesController =
                              deductionNotesControllers[selectedDeduction];
                          final amountController =
                              deductionAmountControllers[selectedDeduction];
                          if (notesController == null ||
                              notesController.text.trim().isEmpty ||
                              amountController == null ||
                              amountController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx2).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please add amount and notes for $selectedDeduction deduction',
                                ),
                              ),
                            );
                            return;
                          }
                        }
                      }
                    }

                    // Prepare deductions data with amounts
                    List<Map<String, String>> deductionsData = [];
                    for (final selectedDeduction in selectedDeductions) {
                      if (selectedDeduction == 'Others') {
                        deductionsData.add({
                          'type': othersController.text.trim(),
                          'amount': othersAmountController.text.trim(),
                          'notes': othersNotesController.text.trim(),
                        });
                      } else {
                        deductionsData.add({
                          'type': selectedDeduction,
                          'amount':
                              deductionAmountControllers[selectedDeduction]!
                                  .text
                                  .trim(),
                          'notes': deductionNotesControllers[selectedDeduction]!
                              .text
                              .trim(),
                        });
                      }
                    }

                    Navigator.pop(ctx2, {
                      'received': recv,
                      'expectedDate': expectedDate,
                      'deductions': deductionsData,
                    });
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    if (map == null) return;
    if (!mounted) return;

    final received = map['received'] as double;
    final expectedDate = map['expectedDate'] as DateTime?;
    final deductionsData = map['deductions'] as List<Map<String, String>>?;

    // Upload photo proof if accounts team has selected one
    String? photoProofUrl;
    if (widget.userType == 'accounts' && _selectedImageBytes != null) {
      photoProofUrl = await _convertImageToBase64();
      if (photoProofUrl == null || photoProofUrl.isEmpty) {
        photoProofUrl =
            'PENDING_UPLOAD_${DateTime.now().millisecondsSinceEpoch}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo upload failed but continuing with payment. Please contact admin.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {}
      // Clear the selected photo after attempting upload
      _clearSelectedPhoto();
    } else if (widget.userType == 'accounts') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo proof is required for accounts team'),
          ),
        );
      }
      setState(() => _partial = false);
      return;
    } else {}

    try {
      final snap3 = await docRef.get();
      final ex3 = snap3.data() ?? {};

      // Get existing partial approvals
      final currentPartialApprovals =
          ex3['partialApprovals'] as Map<String, dynamic>? ?? {};

      // Check if this is the first partial payment proposal or approval of existing
      final existingPartialPayment =
          ex3['partialPayment'] as Map<String, dynamic>?;
      final isFirstProposal = existingPartialPayment == null;

      if (isFirstProposal) {
        // This is the first team proposing a partial payment amount
        final partialObj = {
          'amount': received,
          'receivedAt': FieldValue.serverTimestamp(),
          if (expectedDate != null) 'expectedRemainingDate': expectedDate,
          'markedAt': FieldValue.serverTimestamp(),
          'proposedBy': widget.username,
          'proposedByTeam': widget.userType,
          if (photoProofUrl != null) 'photoProofUrl': photoProofUrl,
          if (deductionsData != null && deductionsData.isNotEmpty)
            'deductions': deductionsData,
        };

        // Add current user's approval for partial payment
        currentPartialApprovals[widget.userType] = {
          'approved': true,
          'approvedBy': widget.username,
          'approvedAt': FieldValue.serverTimestamp(),
          'amount': received,
        };

        await docRef.update({
          'status': 'pending_partial_approval',
          'partialApprovals': currentPartialApprovals,
          'partialPayment': partialObj,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // This is the second team approving the existing partial payment
        final proposedAmount = existingPartialPayment['amount'];
        // Extract the photo proof URL from the existing partial payment proposal
        final proposedPhotoProofUrl =
            existingPartialPayment['photoProofUrl'] as String?;

        // The second team must approve the same amount (or we could allow different amounts)
        // For now, let's use the originally proposed amount

        // Add current user's approval
        currentPartialApprovals[widget.userType] = {
          'approved': true,
          'approvedBy': widget.username,
          'approvedAt': FieldValue.serverTimestamp(),
          'amount': proposedAmount, // Use the originally proposed amount
        };

        // Check if both teams have now approved
        final hasAccountsPartialApproval =
            currentPartialApprovals['accounts']?['approved'] == true;
        final hasDebtCollectionPartialApproval =
            currentPartialApprovals['debtCollection']?['approved'] == true;

        if (hasAccountsPartialApproval && hasDebtCollectionPartialApproval) {
          // Both teams approved - finalize the partial payment
          final finalAmount = proposedAmount is num
              ? proposedAmount.toDouble()
              : 0.0;

          // Add to payments history
          final List payments3 = List.from(ex3['payments'] ?? []);
          final paymentPhotoProofUrl = proposedPhotoProofUrl ?? photoProofUrl;

          // Extract deductions from existing partial payment proposal
          final proposedDeductions =
              existingPartialPayment['deductions'] as List?;

          payments3.add({
            'type': 'partial',
            'amount': finalAmount,
            'receivedAt': Timestamp.fromDate(DateTime.now()),
            if (expectedDate != null) 'expectedRemainingDate': expectedDate,
            'markedAt': Timestamp.fromDate(DateTime.now()),
            if (paymentPhotoProofUrl != null)
              'photoProofUrl': paymentPhotoProofUrl,
            'approvedBy': [
              currentPartialApprovals['accounts']?['approvedBy'],
              currentPartialApprovals['debtCollection']?['approvedBy'],
            ].where((x) => x != null).toList(),
            if (proposedDeductions != null && proposedDeductions.isNotEmpty)
              'deductions': proposedDeductions,
          });

          // Calculate total deduction amount from existing partial payment proposal
          double totalDeductionAmount = 0.0;
          if (proposedDeductions != null && proposedDeductions.isNotEmpty) {
            for (final deduction in proposedDeductions) {
              final deductionMap = deduction as Map<String, dynamic>;
              final amount =
                  double.tryParse(deductionMap['amount']?.toString() ?? '0') ??
                  0.0;
              totalDeductionAmount += amount;
            }
          }

          await docRef.update({
            'status': 'partial',
            'partialApprovals': currentPartialApprovals,
            'receivedAmount': finalAmount,
            'pendingAmount': total != null
                ? (total - finalAmount - totalDeductionAmount)
                : null,
            if (expectedDate != null) 'expectedRemainingDate': expectedDate,
            'partialPayment': existingPartialPayment,
            'payments': payments3,
            'updatedAt': FieldValue.serverTimestamp(),
            if (proposedDeductions != null && proposedDeductions.isNotEmpty)
              'deductions': proposedDeductions,
          });
        } else {
          // Still waiting for the other team
          await docRef.update({
            'partialApprovals': currentPartialApprovals,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      if (!mounted) return;
      setState(() => _partial = true);

      // Show appropriate message based on whether this was first proposal or final approval
      String partialMessage;
      Color messageColor;

      if (isFirstProposal) {
        partialMessage =
            'Your partial payment proposal recorded. Waiting for ${widget.userType == 'accounts' ? 'Debt Collection' : 'Accounts'} approval.';
        messageColor = Colors.amber;
      } else {
        // Check current status to see if it was finalized
        final snap4 = await docRef.get();
        final currentStatus = snap4.data()?['status'];
        if (currentStatus == 'partial') {
          partialMessage = 'Partial payment approved with dual approval!';
          messageColor = Colors.blue;
        } else {
          partialMessage =
              'Your partial payment approval recorded. Waiting for other team.';
          messageColor = Colors.amber;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partialMessage), backgroundColor: messageColor),
      );
      Future.microtask(() {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark partial: $e')));
    }
  }

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
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

  DataRow _followUpRow(Map<String, dynamic> m, int index) {
    DateTime? date;
    final raw = m['date'];
    if (raw is Timestamp) date = raw.toDate();
    final notes = m['notes']?.toString() ?? '';
    DateTime? dueDate;
    final rawDue = m['dueDate'];
    if (rawDue is Timestamp) dueDate = rawDue.toDate();
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(m['whoCalled']?.toString() ?? '')),
        DataCell(Text(m['whomCalled']?.toString() ?? '')),
        DataCell(Text(date == null ? '' : _fmt(date))),
        DataCell(Text(dueDate == null ? '' : _fmt(dueDate))),
        DataCell(
          SizedBox(
            width: 160,
            child: Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () => _viewFollowUp(m),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.redAccent,
                ),
                onPressed: () => _deleteFollowUp(index),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Handle marking invoice as paid. This is a stateful method (not a local function)
  Future<void> _handleMarkPaidToggle(bool v, String status) async {
    // if already complete, notify and return
    if (status == 'complete') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice already marked complete')),
      );
      return;
    }
    if (!v) {
      // unchecking locally allowed before permanent mark
      setState(() => _markPaid = false);
      return;
    }

    // For accounts team, require photo proof before proceeding
    if (widget.userType == 'accounts') {
      final hasPhotoProof = await _showPhotoProofDialog();
      if (!hasPhotoProof) {
        setState(() => _markPaid = false);
        return;
      }
    } else {}

    // Confirm irreversible action and collect received amount in a single dialog.
    final docRef = FirebaseFirestore.instance
        .collection('invoices')
        .doc(widget.invoiceId);
    final snap = await docRef.get();
    if (!mounted) return;
    final inv = snap.data() ?? {};
    final total = (inv['totalAmount'] is num)
        ? (inv['totalAmount'] as num).toDouble()
        : (inv['totalAmount'] != null
              ? double.tryParse(inv['totalAmount'].toString())
              : null);

    // Compute effectiveTotal: if invoice has partial payments, prefer pendingAmount, else total
    double? effectiveTotal;
    final hasPendingAmount = inv['pendingAmount'] != null;
    if (status == 'partial' ||
        (status == 'pending_approval' && hasPendingAmount)) {
      final pRaw = inv['pendingAmount'];
      double? p;
      if (pRaw is num) {
        p = pRaw.toDouble();
      } else if (pRaw != null) {
        p = double.tryParse(pRaw.toString());
      }
      if (p != null) {
        effectiveTotal = p;
      } else {
        // Fallback: calculate from cumulative partial payments
        final payments = inv['payments'] as List<dynamic>? ?? [];
        double cumulativeReceived = 0.0;
        for (final payment in payments) {
          if (payment is Map &&
              payment['type'] == 'partial' &&
              payment['amount'] != null) {
            final amount = payment['amount'];
            if (amount is num) {
              cumulativeReceived += amount.toDouble();
            }
          }
        }
        if (total != null) {
          effectiveTotal = total - cumulativeReceived;
        }
      }
    } else {
      effectiveTotal = total;
    }

    // Check if there's already a proposed completion payment
    final existingCompletionPayment =
        inv['completionPayment'] as Map<String, dynamic>?;
    final isApprovalMode = existingCompletionPayment != null;

    final map = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        if (isApprovalMode) {
          // Show approval dialog for existing completion proposal
          final proposedAmount = existingCompletionPayment['amount'];
          final proposedBy = existingCompletionPayment['proposedBy'];
          final proposedByTeam = existingCompletionPayment['proposedByTeam'];
          final proposedDeduction = existingCompletionPayment['deduction'];
          final proposedDeductions =
              existingCompletionPayment['deductions'] as List?;
          final proposedNotes = existingCompletionPayment['deductionNote'];
          final photoProofUrl =
              existingCompletionPayment['photoProofUrl'] as String?;

          return AlertDialog(
            title: const Text('Approve Payment Completion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (effectiveTotal != null)
                  Text(
                    'Invoice total: ₹${formatIndianCurrency(effectiveTotal, withSymbol: false)}',
                  ),
                const SizedBox(height: 8),
                Text('Proposed by: $proposedByTeam ($proposedBy)'),
                const SizedBox(height: 8),
                Text('Proposed amount: ₹${proposedAmount.toString()}'),

                // Show deductions (new format)
                if (proposedDeductions != null &&
                    proposedDeductions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Deductions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...proposedDeductions.map((deduction) {
                    final deductionMap = deduction as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('• ${deductionMap['type']}'),
                              if (deductionMap['amount'] != null &&
                                  deductionMap['amount'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '(₹${deductionMap['amount']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (deductionMap['notes'] != null &&
                              deductionMap['notes'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                deductionMap['notes'],
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ]
                // Show deduction (old format for backward compatibility)
                else if (proposedDeduction != null) ...[
                  const SizedBox(height: 8),
                  Text('Deduction: $proposedDeduction'),
                ],

                if (proposedNotes != null && proposedNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('General Notes: $proposedNotes'),
                ],
                if (photoProofUrl != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      await _showPhotoVerificationDialog(
                        photoProofUrl,
                        proposedBy,
                      );
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('View Payment Proof'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  photoProofUrl != null
                      ? 'Please verify the payment proof before approving.'
                      : 'Do you approve this payment completion?',
                  style: TextStyle(
                    fontWeight: photoProofUrl != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // Convert proposedDeductions to proper type if it exists
                  List<Map<String, String>>? convertedDeductions;
                  if (proposedDeductions != null) {
                    convertedDeductions = proposedDeductions
                        .map((e) => Map<String, String>.from(e as Map))
                        .toList();
                  }

                  Navigator.of(ctx).pop({
                    'received': proposedAmount is num
                        ? proposedAmount.toDouble()
                        : 0.0,
                    'deductions': convertedDeductions,
                    'deduction':
                        proposedDeduction, // Keep for backward compatibility
                    'notes': proposedNotes,
                  });
                },
                child: const Text('Approve'),
              ),
            ],
          );
        }

        // Show input dialog for new completion proposal
        final recvCtrl = TextEditingController();
        final notesCtrl = TextEditingController();
        List<String> selectedDeductions = [];
        Map<String, TextEditingController> deductionNotesControllers = {};
        Map<String, TextEditingController> deductionAmountControllers = {};
        TextEditingController othersController = TextEditingController();
        TextEditingController othersNotesController = TextEditingController();
        TextEditingController othersAmountController = TextEditingController();

        final deductionOptions = [
          'TDS',
          'Manpower Absent',
          'Instrument Not Working',
          'Security Deposit',
          'Others',
        ];

        return StatefulBuilder(
          builder: (ctx2, setState2) {
            double? parsedRecv = double.tryParse(
              recvCtrl.text.trim().replaceAll(',', ''),
            );
            final requiresDeduction =
                parsedRecv != null &&
                effectiveTotal != null &&
                (parsedRecv - effectiveTotal) < -0.009; // received < total

            return AlertDialog(
              title: const Text('Confirm Payment Received'),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 600),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (effectiveTotal != null)
                        Text(
                          'Invoice total: ₹${formatIndianCurrency(effectiveTotal, withSymbol: false)}',
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: recvCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Received amount',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState2(() {}),
                      ),
                      const SizedBox(height: 8),
                      if (requiresDeduction)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount is less than total. Select deduction(s) and add notes for each.',
                            ),
                            const SizedBox(height: 12),
                            // Multiple deduction selection
                            ...deductionOptions.map((deductionOption) {
                              final isSelected = selectedDeductions.contains(
                                deductionOption,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      title: Text(deductionOption),
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setState2(() {
                                          if (value == true) {
                                            selectedDeductions.add(
                                              deductionOption,
                                            );
                                            if (deductionOption != 'Others') {
                                              deductionNotesControllers[deductionOption] =
                                                  TextEditingController();
                                              deductionAmountControllers[deductionOption] =
                                                  TextEditingController();
                                            }
                                          } else {
                                            selectedDeductions.remove(
                                              deductionOption,
                                            );
                                            if (deductionOption != 'Others') {
                                              deductionNotesControllers[deductionOption]
                                                  ?.dispose();
                                              deductionNotesControllers.remove(
                                                deductionOption,
                                              );
                                              deductionAmountControllers[deductionOption]
                                                  ?.dispose();
                                              deductionAmountControllers.remove(
                                                deductionOption,
                                              );
                                            }
                                          }
                                        });
                                      },
                                    ),
                                    if (isSelected) ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        child: Column(
                                          children: [
                                            if (deductionOption ==
                                                'Others') ...[
                                              TextField(
                                                controller: othersController,
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Specify Other Deduction',
                                                  hintText:
                                                      'Enter custom deduction type',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller:
                                                    othersNotesController,
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Notes for Other Deduction',
                                                ),
                                                maxLines: 2,
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller:
                                                    othersAmountController,
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Amount for Other Deduction',
                                                  hintText:
                                                      'Enter amount deducted',
                                                  prefixText: '₹',
                                                ),
                                                keyboardType:
                                                    TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                onChanged: (_) =>
                                                    setState2(() {}),
                                              ),
                                            ] else ...[
                                              TextField(
                                                controller:
                                                    deductionNotesControllers[deductionOption]!,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Notes for $deductionOption',
                                                  hintText:
                                                      'Enter details about this deduction',
                                                ),
                                                maxLines: 2,
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller:
                                                    deductionAmountControllers[deductionOption]!,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Amount for $deductionOption',
                                                  hintText:
                                                      'Enter amount deducted',
                                                  prefixText: '₹',
                                                ),
                                                keyboardType:
                                                    TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                onChanged: (_) =>
                                                    setState2(() {}),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, null),
                  child: const Text('Cancel'),
                ),
                Builder(
                  builder: (context) {
                    final recv = double.tryParse(
                      recvCtrl.text.trim().replaceAll(',', ''),
                    );

                    // Calculate total deductions
                    double totalDeductions = 0.0;
                    for (final selectedDeduction in selectedDeductions) {
                      if (selectedDeduction == 'Others') {
                        final deductionAmount = double.tryParse(
                          othersAmountController.text.trim().replaceAll(
                            ',',
                            '',
                          ),
                        );
                        if (deductionAmount != null) {
                          totalDeductions += deductionAmount;
                        }
                      } else {
                        final deductionAmount = double.tryParse(
                          deductionAmountControllers[selectedDeduction]?.text
                                  .trim()
                                  .replaceAll(',', '') ??
                              '',
                        );
                        if (deductionAmount != null) {
                          totalDeductions += deductionAmount;
                        }
                      }
                    }

                    // Check if can complete: received + deductions should be within 5 of total
                    final bool canComplete =
                        recv != null &&
                        (effectiveTotal == null ||
                            ((recv + totalDeductions) - effectiveTotal).abs() <=
                                5.0);

                    return Tooltip(
                      message: !canComplete && recv != null
                          ? 'Difference between total (₹${formatIndianCurrency(effectiveTotal ?? 0.0, withSymbol: false)}) and received+deductions (₹${formatIndianCurrency(recv + totalDeductions, withSymbol: false)}) exceeds ₹5.00'
                          : '',
                      child: FilledButton.tonal(
                        onPressed: !canComplete
                            ? null
                            : () {
                                final recv = double.tryParse(
                                  recvCtrl.text.trim().replaceAll(',', ''),
                                );
                                if (recv == null) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a valid received amount',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // This validation is now redundant since button is disabled,
                                // but keeping as a safety check
                                if (effectiveTotal != null) {
                                  // Calculate total deductions
                                  double totalDeductions = 0.0;
                                  for (final selectedDeduction
                                      in selectedDeductions) {
                                    if (selectedDeduction == 'Others') {
                                      final deductionAmount = double.tryParse(
                                        othersAmountController.text
                                            .trim()
                                            .replaceAll(',', ''),
                                      );
                                      if (deductionAmount != null) {
                                        totalDeductions += deductionAmount;
                                      }
                                    } else {
                                      final deductionAmount = double.tryParse(
                                        deductionAmountControllers[selectedDeduction]
                                                ?.text
                                                .trim()
                                                .replaceAll(',', '') ??
                                            '',
                                      );
                                      if (deductionAmount != null) {
                                        totalDeductions += deductionAmount;
                                      }
                                    }
                                  }

                                  final difference =
                                      ((recv + totalDeductions) -
                                              effectiveTotal)
                                          .abs();
                                  if (difference > 5.0) {
                                    ScaffoldMessenger.of(ctx2).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Difference between total (₹${formatIndianCurrency(effectiveTotal, withSymbol: false)}) and received+deductions (₹${formatIndianCurrency(recv + totalDeductions, withSymbol: false)}) is ₹${formatIndianCurrency(difference, withSymbol: false)}. Cannot mark as complete unless difference is ≤ ₹5.00',
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                if (requiresDeduction) {
                                  // Validate selected deductions
                                  if (selectedDeductions.isEmpty) {
                                    ScaffoldMessenger.of(ctx2).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select at least one deduction',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // Validate amounts and notes for each selected deduction
                                  for (final selectedDeduction
                                      in selectedDeductions) {
                                    if (selectedDeduction == 'Others') {
                                      if (othersController.text
                                              .trim()
                                              .isEmpty ||
                                          othersAmountController.text
                                              .trim()
                                              .isEmpty ||
                                          othersNotesController.text
                                              .trim()
                                              .isEmpty) {
                                        ScaffoldMessenger.of(ctx2).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please specify the "Others" deduction type, amount, and add notes',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                    } else {
                                      final notesController =
                                          deductionNotesControllers[selectedDeduction];
                                      final amountController =
                                          deductionAmountControllers[selectedDeduction];
                                      if (notesController == null ||
                                          notesController.text.trim().isEmpty ||
                                          amountController == null ||
                                          amountController.text
                                              .trim()
                                              .isEmpty) {
                                        ScaffoldMessenger.of(ctx2).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Please add amount and notes for $selectedDeduction deduction',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                    }
                                  }
                                }

                                // Prepare deductions data with amounts
                                List<Map<String, String>> deductionsData = [];
                                for (final selectedDeduction
                                    in selectedDeductions) {
                                  if (selectedDeduction == 'Others') {
                                    deductionsData.add({
                                      'type': othersController.text.trim(),
                                      'amount': othersAmountController.text
                                          .trim(),
                                      'notes': othersNotesController.text
                                          .trim(),
                                    });
                                  } else {
                                    deductionsData.add({
                                      'type': selectedDeduction,
                                      'amount':
                                          deductionAmountControllers[selectedDeduction]!
                                              .text
                                              .trim(),
                                      'notes':
                                          deductionNotesControllers[selectedDeduction]!
                                              .text
                                              .trim(),
                                    });
                                  }
                                }

                                Navigator.pop(ctx2, {
                                  'received': recv,
                                  'deductions': deductionsData,
                                  'notes': notesCtrl.text
                                      .trim(), // Keep general notes for backward compatibility
                                });
                              },
                        child: const Text('Mark as done'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (map == null) return;
    if (!mounted) return; // guard before using context later

    final received = map['received'] as double;
    final deductionsList = map['deductions'] as List?;
    final deductions = deductionsList
        ?.map((e) => Map<String, String>.from(e as Map))
        .toList();
    final notes = map['notes'] as String?;

    // Upload photo proof if accounts team has selected one
    String? photoProofUrl;
    if (widget.userType == 'accounts' && _selectedImageBytes != null) {
      photoProofUrl = await _convertImageToBase64();
      if (photoProofUrl == null || photoProofUrl.isEmpty) {
        // For now, continue with a placeholder to test the flow
        // In production, you might want to fail here
        photoProofUrl =
            'PENDING_UPLOAD_${DateTime.now().millisecondsSinceEpoch}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo upload failed but continuing with payment. Please contact admin.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {}
      // Clear the selected photo after attempting upload
      _clearSelectedPhoto();
    } else if (widget.userType == 'accounts') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo proof is required for accounts team'),
          ),
        );
      }
      setState(() => _markPaid = false);
      return;
    } else {}

    try {
      final snap3 = await docRef.get();
      final ex3 = snap3.data() ?? {};

      // Get existing completion approvals
      final currentCompletionApprovals =
          ex3['approvals'] as Map<String, dynamic>? ?? {};

      // Check if this is the first completion proposal or approval of existing
      final existingCompletionPayment =
          ex3['completionPayment'] as Map<String, dynamic>?;
      final isFirstProposal = existingCompletionPayment == null;

      // Extract the photo proof URL from the existing completion payment if available
      final proposedPhotoProofUrl =
          existingCompletionPayment?['photoProofUrl'] as String?;

      String finalStatus;

      if (isFirstProposal) {
        // This is the first team proposing a completion payment
        final completionObj = {
          'amount': received,
          if (deductions != null && deductions.isNotEmpty)
            'deductions': deductions,
          'deductionNote': notes,
          'proposedAt': FieldValue.serverTimestamp(),
          'proposedBy': widget.username,
          'proposedByTeam': widget.userType,
          if (photoProofUrl != null) 'photoProofUrl': photoProofUrl,
        };

        // Add current user's approval for completion
        currentCompletionApprovals[widget.userType] = {
          'approved': true,
          'approvedBy': widget.username,
          'approvedAt': FieldValue.serverTimestamp(),
        };

        await docRef.update({
          'status': 'pending_approval',
          'approvals': currentCompletionApprovals,
          'completionPayment': completionObj,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        finalStatus = 'pending_approval';
      } else {
        // This is the second team approving the existing completion payment
        final proposedAmount = existingCompletionPayment['amount'];
        final proposedDeduction = existingCompletionPayment['deduction'];
        final proposedDeductions =
            existingCompletionPayment['deductions'] as List?;
        final proposedNotes = existingCompletionPayment['deductionNote'];

        // Add current user's approval
        currentCompletionApprovals[widget.userType] = {
          'approved': true,
          'approvedBy': widget.username,
          'approvedAt': FieldValue.serverTimestamp(),
        };

        // Check if both teams have now approved
        final hasAccountsApproval =
            currentCompletionApprovals['accounts']?['approved'] == true;
        final hasDebtCollectionApproval =
            currentCompletionApprovals['debtCollection']?['approved'] == true;

        if (hasAccountsApproval && hasDebtCollectionApproval) {
          // Both teams approved - finalize the completion
          final finalAmount = proposedAmount is num
              ? proposedAmount.toDouble()
              : 0.0;

          // Handle completion based on current status - check for both partial and pending_approval
          // since status changes to pending_approval when first team proposes completion
          if (status == 'partial' ||
              (status == 'pending_approval' && ex3['receivedAmount'] != null)) {
            // If invoice was partial, aggregate with existing received and clear pending fields
            final existingRecvRaw = ex3['receivedAmount'];
            final double existingRecv = existingRecvRaw == null
                ? 0.0
                : (existingRecvRaw is num
                      ? existingRecvRaw.toDouble()
                      : double.tryParse(existingRecvRaw.toString()) ?? 0.0);
            final newRecv = existingRecv + finalAmount;

            // push payments history: start with existing payments
            final exPayments = List.from(inv['payments'] ?? []);
            // if there was a partialPayment object, only push it if payments
            // don't already contain an equivalent partial entry (avoid duplicates)
            if (inv['partialPayment'] != null) {
              final pp = inv['partialPayment'] as Map<String, dynamic>;
              final ppAmt = pp['amount'];
              final alreadyHasPartial = exPayments.any((e) {
                if (e is Map<String, dynamic>) {
                  final t = e['type']?.toString();
                  final a = e['amount'];
                  if (t == 'partial' && a != null) {
                    try {
                      final aNum = a is num
                          ? a.toDouble()
                          : double.parse(a.toString());
                      final ppNum = ppAmt is num
                          ? ppAmt.toDouble()
                          : double.parse(ppAmt.toString());
                      return (aNum - ppNum).abs() < 0.0001;
                    } catch (_) {
                      return false;
                    }
                  }
                }
                return false;
              });
              if (!alreadyHasPartial) {
                exPayments.add({
                  'type': 'partial',
                  'amount': pp['amount'],
                  'receivedAt': pp['receivedAt'],
                  'expectedRemainingDate': pp['expectedRemainingDate'],
                  'markedAt': pp['markedAt'],
                });
              }
            }
            // add an entry for the amount being collected now. For a previously
            // partial invoice we record this as another 'partial' payment (per user
            // request) rather than creating a 'final' type to avoid duplicate
            // semantics in the payments history.
            final paymentPhotoProofUrl = proposedPhotoProofUrl ?? photoProofUrl;
            exPayments.add({
              'type': 'partial',
              'amount': finalAmount,
              'receivedAt': Timestamp.fromDate(DateTime.now()),
              if (paymentPhotoProofUrl != null)
                'photoProofUrl': paymentPhotoProofUrl,
              'submittedBy': widget.username,
              'submittedByTeam': widget.userType,
            });

            // Get existing approvals
            final currentApprovals =
                inv['approvals'] as Map<String, dynamic>? ?? {};

            // Add current user's approval
            currentApprovals[widget.userType] = {
              'approved': true,
              'approvedBy': widget.username,
              'approvedAt': FieldValue.serverTimestamp(),
            };

            // Check if both accounts and debtCollection have approved
            final hasAccountsApproval =
                currentApprovals['accounts']?['approved'] == true;
            final hasDebtCollectionApproval =
                currentApprovals['debtCollection']?['approved'] == true;
            finalStatus = (hasAccountsApproval && hasDebtCollectionApproval)
                ? 'complete'
                : 'pending_approval';

            final updateMap = <String, dynamic>{
              'status': finalStatus,
              'approvals': currentApprovals,
              'receivedAmount': newRecv,
              if (proposedDeduction != null) 'deduction': proposedDeduction,
              if (proposedDeductions != null && proposedDeductions.isNotEmpty)
                'deductions': proposedDeductions,
              if (proposedNotes != null && proposedNotes.isNotEmpty)
                'deductionNote': proposedNotes,
              'payments': exPayments,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            // remove pending fields
            updateMap['pendingAmount'] = FieldValue.delete();
            updateMap['expectedRemainingDate'] = FieldValue.delete();
            // clear partialPayment object
            updateMap['partialPayment'] = FieldValue.delete();
            // clear completionPayment object
            updateMap['completionPayment'] = FieldValue.delete();

            await docRef.update(updateMap);
          } else {
            // completed directly: create payments array entry for full payment
            final exPayments = List.from(inv['payments'] ?? []);
            final paymentPhotoProofUrl = proposedPhotoProofUrl ?? photoProofUrl;
            exPayments.add({
              'type': 'full',
              'amount': finalAmount,
              'receivedAt': Timestamp.fromDate(DateTime.now()),
              if (paymentPhotoProofUrl != null)
                'photoProofUrl': paymentPhotoProofUrl,
              'submittedBy': widget.username,
              'submittedByTeam': widget.userType,
            });
            // Get existing approvals
            final currentApprovals =
                inv['approvals'] as Map<String, dynamic>? ?? {};

            // Add current user's approval
            currentApprovals[widget.userType] = {
              'approved': true,
              'approvedBy': widget.username,
              'approvedAt': FieldValue.serverTimestamp(),
            };

            // Check if both accounts and debtCollection have approved
            final hasAccountsApproval =
                currentApprovals['accounts']?['approved'] == true;
            final hasDebtCollectionApproval =
                currentApprovals['debtCollection']?['approved'] == true;
            finalStatus = (hasAccountsApproval && hasDebtCollectionApproval)
                ? 'complete'
                : 'pending_approval';

            final updateMap = <String, dynamic>{
              'status': finalStatus,
              'approvals': currentApprovals,
              'receivedAmount': finalAmount,
              'payments': exPayments,
              if (proposedDeduction != null) 'deduction': proposedDeduction,
              if (proposedDeductions != null && proposedDeductions.isNotEmpty)
                'deductions': proposedDeductions,
              if (proposedNotes != null && proposedNotes.isNotEmpty)
                'deductionNote': proposedNotes,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            // Remove pending fields if they exist
            updateMap['pendingAmount'] = FieldValue.delete();
            updateMap['expectedRemainingDate'] = FieldValue.delete();
            // clear completionPayment object
            updateMap['completionPayment'] = FieldValue.delete();

            await docRef.update(updateMap);
          }

          if (!mounted) return;

          setState(() => _markPaid = true);

          // Show appropriate message based on final status
          final message = finalStatus == 'complete'
              ? 'Invoice completed successfully with dual approval!'
              : 'Your approval recorded. Waiting for ${widget.userType == 'accounts' ? 'Debt Collection' : 'Accounts'} approval.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: finalStatus == 'complete'
                  ? Colors.green
                  : Colors.orange,
            ),
          );

          Future.microtask(() {
            if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark complete: $e')));
    }
  }

  Future<void> _saveFollowUp() async {
    setState(() => _saving = true);
    try {
      // Validate required fields
      if (_followUpDueDate == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commitment Date is required')),
        );
        setState(() => _saving = false);
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId);
      final snapshot = await docRef.get();
      final existing = snapshot.data() ?? {};
      final List followUps = List.from(existing['followUps'] ?? []);
      followUps.add({
        'whoCalled': _whoCalledCtrl.text.trim(),
        'whomCalled': _whomCalledCtrl.text.trim(),
        'date': Timestamp.fromDate(_callDate),
        'dueDate': Timestamp.fromDate(_followUpDueDate!),
        'notes': _notesCtrl.text.trim(),
        'createdAt': Timestamp.fromDate(
          DateTime.now(),
        ), // client timestamp instead of serverTimestamp inside array
      });
      await docRef.update({
        'followUps': followUps,
        'dueDate': Timestamp.fromDate(
          _followUpDueDate!,
        ), // Update invoice due date to match commitment date
        'expectedRemainingDate': Timestamp.fromDate(
          _followUpDueDate!,
        ), // Update expected remaining date for partial payments
        if (_markPaid)
          'status': 'complete'
        else
          'status': existing['status'] ?? 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up saved and dates updated')),
      );
      _whoCalledCtrl.clear();
      _whomCalledCtrl.clear();
      _notesCtrl.clear();
      _followUpDueDate = null;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteFollowUp(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Follow-up'),
        content: const Text(
          'Are you sure you want to delete this follow-up entry?',
        ),
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
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.runTransaction((trx) async {
        final ref = FirebaseFirestore.instance
            .collection('invoices')
            .doc(widget.invoiceId);
        final snap = await trx.get(ref);
        final data = snap.data() ?? {};
        final list = List.from(data['followUps'] ?? []);
        if (index >= 0 && index < list.length) {
          list.removeAt(index);
          trx.update(ref, {
            'followUps': list,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Follow-up deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _viewFollowUp(Map<String, dynamic> m) {
    DateTime? date;
    final raw = m['date'];
    if (raw is Timestamp) date = raw.toDate();
    DateTime? due;
    final rawDue = m['dueDate'];
    if (rawDue is Timestamp) due = rawDue.toDate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Follow-up Details'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Who called', m['whoCalled']?.toString() ?? ''),
              _kv('Whom called', m['whomCalled']?.toString() ?? ''),
              _kv('Date', date == null ? '' : _fmt(date)),
              _kv('Commitment Date', due == null ? '' : _fmt(due)),
              const SizedBox(height: 8),
              Text('Notes', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(m['notes']?.toString() ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  Future<void> _pickCallDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDate: _callDate,
    );
    if (picked != null) setState(() => _callDate = picked);
  }

  Future<void> _pickPhotoProof() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = imageBytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<String?> _convertImageToBase64() async {
    if (_selectedImageBytes == null || _selectedImageName == null) {
      return null;
    }

    setState(() => _uploadingPhoto = true);

    try {
      // Convert to base64
      final base64String = base64Encode(_selectedImageBytes!);

      // Create a data URL with proper MIME type
      final fileExtension = _selectedImageName!.split('.').last.toLowerCase();
      String mimeType = 'image/png'; // default
      if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (fileExtension == 'gif') {
        mimeType = 'image/gif';
      } else if (fileExtension == 'webp') {
        mimeType = 'image/webp';
      }

      final dataUrl = 'data:$mimeType;base64,$base64String';
      return dataUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process image: $e')));
      }
      return null;
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  void _clearSelectedPhoto() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<bool> _showPhotoProofDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Upload Payment Proof'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'As an accounts team member, you must provide photo proof of payment before marking as paid.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedImageBytes != null) ...[
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selected: $_selectedImageName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _clearSelectedPhoto();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: () async {
                                await _pickPhotoProof();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Change Photo'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InkWell(
                            onTap: () async {
                              await _pickPhotoProof();
                              setDialogState(() {});
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to select payment proof',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_uploadingPhoto) ...[
                        const SizedBox(height: 16),
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Uploading photo proof...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: _selectedImageBytes == null || _uploadingPhoto
                          ? null
                          : () => Navigator.of(ctx).pop(true),
                      child: const Text('Continue'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _showPhotoVerificationDialog(
    String photoUrl,
    String submittedBy,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Verify Payment Proof'),
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
                          'Payment proof submitted by: $submittedBy',
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
                              child: Image.network(
                                photoUrl,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 48,
                                          color: Colors.red.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'As a debt collection team member, please verify this payment proof before approving the payment.',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
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

  Future<void> _sendPaymentReminder() async {
    try {
      // Get current invoice data
      final invoiceData = widget.initialData;
      final invoiceNo = invoiceData['invoiceNo']?.toString() ?? '';
      final customerName = invoiceData['customerName']?.toString() ?? '';
      final totalAmount = invoiceData['totalAmount']?.toString() ?? '';

      // Get user's email from users collection
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User information not found')),
        );
        return;
      }

      final userData = userQuery.docs.first.data();
      final senderEmail = userData['email']?.toString();

      if (senderEmail == null || senderEmail.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sender email not found in user profile'),
          ),
        );
        return;
      }

      // Ask for recipient email
      if (!mounted) return;
      final recipientEmail = await showDialog<String>(
        context: context,
        builder: (context) {
          final emailController = TextEditingController();
          return AlertDialog(
            title: const Text('Send Payment Reminder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Send reminder to customer for Invoice #$invoiceNo'),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Email',
                    hintText: 'customer@example.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final email = emailController.text.trim();
                  if (email.isNotEmpty) {
                    Navigator.of(context).pop(email);
                  }
                },
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      if (recipientEmail == null || recipientEmail.isEmpty) return;

      // Compose email body
      final emailBody =
          '''Dear $customerName,

This is a reminder to send the payment for Invoice #$invoiceNo.

Invoice Details:
- Invoice Number: $invoiceNo
- Total Amount: $totalAmount
- Customer: $customerName

Please process the payment at your earliest convenience.

Thank you for your business.

Best regards,
${widget.username}''';

      final subject = 'Payment Reminder - Invoice #$invoiceNo';

      // Create Gmail URL
      final gmailUrl = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(recipientEmail)}&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}',
      );

      // Try to launch Gmail URL
      if (await canLaunchUrl(gmailUrl)) {
        await launchUrl(gmailUrl, mode: LaunchMode.externalApplication);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gmail opened with payment reminder'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Fallback to mailto
        final mailtoUrl = Uri.parse(
          'mailto:$recipientEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}',
        );

        if (await canLaunchUrl(mailtoUrl)) {
          await launchUrl(mailtoUrl);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email client opened with payment reminder'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('No email client available');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePaymentAdviceAvailable(bool? hasAdvice) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId);

      if (hasAdvice == null) {
        // Reset the decision
        await docRef.update({
          'paymentAdviceProvided': FieldValue.delete(),
          'paymentAdviceUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (hasAdvice == false) {
        // Mark as not available
        await docRef.update({
          'paymentAdviceProvided': false,
          'paymentAdviceUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Mark as available (will need to upload)
        await docRef.update({
          'paymentAdviceProvided': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasAdvice == null
                  ? 'Payment advice status reset'
                  : hasAdvice
                  ? 'Marked as available. Please upload the payment advice.'
                  : 'Marked as not available',
            ),
            backgroundColor: hasAdvice == true ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment advice status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPaymentAdvice() async {
    try {
      await _pickPhotoProof();
      if (_selectedImageBytes != null) {
        final photoUrl = await _convertImageToBase64();
        if (photoUrl != null) {
          final docRef = FirebaseFirestore.instance
              .collection('invoices')
              .doc(widget.invoiceId);

          await docRef.update({
            'paymentAdviceUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          _clearSelectedPhoto();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment advice uploaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading payment advice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPaymentAdviceDialog(String photoUrl) async {
    await _showPhotoVerificationDialog(photoUrl, 'Payment Advice');
  }

  Widget _buildPaymentAdviceSection(Map<String, dynamic> data) {
    final paymentAdviceProvided = data['paymentAdviceProvided'] as bool?;
    final paymentAdviceUrl = data['paymentAdviceUrl'] as String?;

    return _card(context, 'Payment Advice', [
      if (widget.userType == 'debtCollection') ...[
        // Debt Collection UI
        const Text(
          'Do you have payment advice?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),

        if (paymentAdviceProvided == null) ...[
          // Initial state - show buttons
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handlePaymentAdviceAvailable(true),
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text('Yes, I have it'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handlePaymentAdviceAvailable(false),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Not available'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ] else if (paymentAdviceProvided == true) ...[
          // Payment advice is available - show upload/view
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment advice is available',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (paymentAdviceUrl != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showPaymentAdviceDialog(paymentAdviceUrl),
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Uploaded Advice'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploadPaymentAdvice,
                    icon: Icon(
                      _uploadingPhoto ? Icons.hourglass_empty : Icons.upload,
                    ),
                    label: Text(
                      _uploadingPhoto
                          ? 'Uploading...'
                          : 'Upload Payment Advice',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _handlePaymentAdviceAvailable(null),
                  child: const Text('Change Decision'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Payment advice not available
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment advice not available',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _handlePaymentAdviceAvailable(null),
                  child: const Text('Change Decision'),
                ),
              ],
            ),
          ),
        ],
      ] else if (widget.userType == 'accounts') ...[
        // Accounts UI
        if (paymentAdviceProvided == null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waiting for debt collection team to confirm payment advice availability',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (paymentAdviceProvided == true) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment advice is available',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (paymentAdviceUrl != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showPaymentAdviceDialog(paymentAdviceUrl),
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Payment Advice'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No payment advice available',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final baseData = widget.initialData;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final data = snap.data?.data() ?? baseData;
        final status = data['status']?.toString() ?? 'pending';

        final followUps = (data['followUps'] as List?) ?? [];
        return Scaffold(
          appBar: AppBar(
            title: Text('Edit / Follow-up #${baseData['invoiceNo']}'),
          ),
          body: LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 1000; // breakpoint
              final formSection = SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Advice section
                    _buildPaymentAdviceSection(data),
                    const SizedBox(height: 16),

                    _card(context, 'Payment', [
                      SwitchListTile(
                        value: _markPaid || status == 'complete',
                        onChanged: !_canChangeCompletionStatus(status, data)
                            ? null
                            : (v) => _handleMarkPaidToggle(v, status),
                        title: const Text('Payment is done'),
                        subtitle: Text(_getCompletionSubtitle(status, data)),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _partial || status == 'partial',
                        onChanged: !_canChangePartialStatus(status, data)
                            ? null
                            : (v) => _handlePartialToggle(v, status),
                        title: const Text('Partial payment'),
                        subtitle: Text(_getPartialSubtitle(status, data)),
                      ),
                    ]),
                    // Send Mail - only for debtCollection users
                    if (widget.userType == 'debtCollection')
                      _card(context, 'Send Mail', [
                        FilledButton.icon(
                          onPressed: _sendPaymentReminder,
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Send payment reminder email'),
                        ),
                      ]),
                    // Call Follow-up - only for debtCollection users
                    if (widget.userType == 'debtCollection')
                      _card(context, 'Call Follow-up', [
                        TextField(
                          controller: _whoCalledCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Who called',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _whomCalledCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Whom he called',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _pickCallDate,
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Call Date',
                                prefixIcon: Icon(Icons.event_outlined),
                              ),
                              controller: TextEditingController(
                                text: _fmt(_callDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(DateTime.now().year - 1),
                              lastDate: DateTime(DateTime.now().year + 2),
                              initialDate: _followUpDueDate ?? DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _followUpDueDate = picked);
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Commitment Date *',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              controller: TextEditingController(
                                text: _followUpDueDate == null
                                    ? ''
                                    : _fmt(_followUpDueDate!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The invoice due date and expected remaining date will be updated to match the commitment date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _saving ? null : _saveFollowUp,
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save Follow-up'),
                          ),
                        ),
                      ]),
                  ],
                ),
              );

              Widget table = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Previous Follow-ups (${followUps.length})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade700,
                              ),
                        ),
                        const SizedBox(width: 12),
                        if (followUps.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '${followUps.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: followUps.isEmpty
                          ? const Center(
                              child: Text(
                                'No follow-ups yet',
                                style: TextStyle(color: Colors.blueGrey),
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade100.withValues(
                                      alpha: .35,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Scrollbar(
                                controller: _tableScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _tableScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: wide
                                          ? 780
                                          : constraints.maxWidth - 60,
                                    ),
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor: WidgetStatePropertyAll(
                                          Colors.blue.shade50,
                                        ),
                                        columnSpacing: 32,
                                        dataRowMinHeight: 44,
                                        dataRowMaxHeight: 68,
                                        columns: const [
                                          DataColumn(label: Text('S.No')),
                                          DataColumn(label: Text('Who Called')),
                                          DataColumn(
                                            label: Text('Whom Called'),
                                          ),
                                          DataColumn(label: Text('Date')),
                                          DataColumn(
                                            label: Text('Commitment Date'),
                                          ),
                                          DataColumn(label: Text('Notes')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows: [
                                          for (
                                            int i = 0;
                                            i < followUps.length;
                                            i++
                                          )
                                            _followUpRow(
                                              followUps[i]
                                                  as Map<String, dynamic>,
                                              i,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  children: [
                    SizedBox(width: 420, child: formSection),
                    const VerticalDivider(width: 1),
                    Expanded(child: table),
                  ],
                );
              }
              // Narrow: stack vertically in a CustomScroll (simpler: Column + Expanded)
              return Column(
                children: [
                  SizedBox(height: 420, child: formSection),
                  Expanded(child: table),
                ],
              );
            },
          ),
          floatingActionButton: _canEditInvoiceDetails(status, data)
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoiceFormPage(
                          username: widget.username,
                          userType: widget.userType,
                          invoiceId: widget.invoiceId,
                          initialData: widget.initialData,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Edit Details'),
                )
              : null,
        );
      },
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
