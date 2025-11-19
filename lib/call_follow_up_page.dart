import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_service.dart';

class CallFollowUpPage extends StatefulWidget {
  final String username;
  final String userType;
  final String callId;
  final CallRequest callRequest;

  const CallFollowUpPage({
    super.key,
    required this.username,
    required this.userType,
    required this.callId,
    required this.callRequest,
  });

  @override
  State<CallFollowUpPage> createState() => _CallFollowUpPageState();
}

class _CallFollowUpPageState extends State<CallFollowUpPage> {
  final _whoCalledCtrl = TextEditingController();
  final _whomCalledCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _tableScrollController = ScrollController();
  DateTime _callDate = DateTime.now();
  DateTime? _followUpDueDate;
  bool _poReceived = false;
  final _poNumberCtrl = TextEditingController();
  bool _saving = false;

  // Email follow-up controllers
  final _emailRecipientCtrl = TextEditingController();
  final _emailSubjectCtrl = TextEditingController();
  final _emailBodyCtrl = TextEditingController();
  bool _savingEmail = false;

  @override
  void dispose() {
    _whoCalledCtrl.dispose();
    _whomCalledCtrl.dispose();
    _notesCtrl.dispose();
    _poNumberCtrl.dispose();
    _emailRecipientCtrl.dispose();
    _emailSubjectCtrl.dispose();
    _emailBodyCtrl.dispose();
    _scrollController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  /// Check if current user can add follow ups
  bool _canAddFollowUp() {
    // Only debtCollection team can add follow ups
    return widget.userType == 'debtCollection';
  }

  Future<void> _saveFollowUp() async {
    setState(() => _saving = true);
    try {
      // Validate required fields
      if (_followUpDueDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a follow up due date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final followUpData = <String, dynamic>{
        'whoCalled': _whoCalledCtrl.text.trim(),
        'whomCalled': _whomCalledCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'date': _callDate.toIso8601String(),
        'dueDate': _followUpDueDate!.toIso8601String(),
        'createdBy': widget.username,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Add PO details if PO received
      if (_poReceived && _poNumberCtrl.text.trim().isNotEmpty) {
        followUpData['poReceived'] = _poReceived;
        followUpData['poNumber'] = _poNumberCtrl.text.trim();
      }

      await UserService.addCallFollowUp(
        callId: widget.callId,
        followUp: followUpData,
      );

      // If PO received, update status and PO number in call request
      if (_poReceived && _poNumberCtrl.text.trim().isNotEmpty) {
        await UserService.savePOPIAndUpdateStatus(
          callId: widget.callId,
          type: 'PO',
          number: _poNumberCtrl.text.trim(),
          givenBy: widget.username,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _poReceived
                ? 'PO received and follow up saved!'
                : 'Follow up saved successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _whoCalledCtrl.clear();
      _whomCalledCtrl.clear();
      _notesCtrl.clear();
      _poNumberCtrl.clear();
      _followUpDueDate = null;
      _poReceived = false;
      setState(() {});

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving follow up: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteFollowUp(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Follow Up'),
        content: const Text(
          'Are you sure you want to delete this follow up? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.runTransaction((trx) async {
        final docRef = FirebaseFirestore.instance
            .collection('call_requests')
            .doc(widget.callId);
        final snap = await trx.get(docRef);
        final data = snap.data() ?? {};
        final followUps = List<Map<String, dynamic>>.from(
          data['followUps'] ?? [],
        );

        if (index >= 0 && index < followUps.length) {
          followUps.removeAt(index);
          trx.update(docRef, {
            'followUps': followUps,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow up deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting follow up: $e')));
      }
    }
  }

  Future<void> _saveEmailFollowUp() async {
    if (_emailRecipientCtrl.text.trim().isEmpty ||
        _emailSubjectCtrl.text.trim().isEmpty ||
        _emailBodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all email fields')),
      );
      return;
    }

    setState(() => _savingEmail = true);
    try {
      final followUpData = {
        'type': 'email',
        'recipient': _emailRecipientCtrl.text.trim(),
        'subject': _emailSubjectCtrl.text.trim(),
        'body': _emailBodyCtrl.text.trim(),
        'sentAt': DateTime.now().toIso8601String(),
        'createdBy': widget.username,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await UserService.addCallFollowUp(
        callId: widget.callId,
        followUp: followUpData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email follow-up saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _emailRecipientCtrl.clear();
      _emailSubjectCtrl.clear();
      _emailBodyCtrl.clear();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving email follow-up: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _sendPaymentReminder(CallRequest callRequest) async {
    try {
      // Show dialog to get recipient email
      final email = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Send Payment Reminder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter recipient email address:'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, controller.text.trim());
                  }
                },
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      if (email == null || email.isEmpty) return;

      final customerName = callRequest.customerName;
      final callAmount = callRequest.finalAmount.toStringAsFixed(2);
      final callPeriod =
          '${_fmt(callRequest.callFromDate)} to ${_fmt(callRequest.callToDate)}';

      final emailBody =
          '''Dear $customerName,

This is a reminder regarding payment for the call services provided.

Call Details:
- Customer: $customerName
- Call Period: $callPeriod
- Total Amount: ₹$callAmount
- Status: ${callRequest.status.name}

Please process the payment at your earliest convenience.

If you have any questions or concerns, please don't hesitate to contact us.

Thank you for your business.

Best regards,
${widget.username}''';

      final subject = 'Payment Reminder - Call Services for $customerName';

      // Create Gmail URL
      final gmailUrl = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(email)}&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}',
      );

      // Try to launch Gmail URL
      if (await canLaunchUrl(gmailUrl)) {
        await launchUrl(gmailUrl, mode: LaunchMode.externalApplication);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gmail opened successfully. Please review and send the email.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Fallback to mailto
        final mailtoUrl = Uri.parse(
          'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}',
        );

        if (await canLaunchUrl(mailtoUrl)) {
          await launchUrl(mailtoUrl, mode: LaunchMode.externalApplication);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email client opened. Please review and send the email.',
              ),
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
          content: Text('Error sending reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFollowUpCard(Map<String, dynamic> followUp, int index) {
    DateTime? date;
    final raw = followUp['date'];
    if (raw is String) {
      date = DateTime.tryParse(raw);
    } else if (raw is Timestamp) {
      date = raw.toDate();
    }

    DateTime? dueDate;
    final rawDue = followUp['dueDate'];
    if (rawDue is String) {
      dueDate = DateTime.tryParse(rawDue);
    } else if (rawDue is Timestamp) {
      dueDate = rawDue.toDate();
    }

    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue ? Colors.red.shade200 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Follow Up #${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  if (followUp['poReceived'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: const Text(
                        'PO Received',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_canAddFollowUp())
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteFollowUp(index),
                      tooltip: 'Delete',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kv('Who Called', followUp['whoCalled']?.toString() ?? '-'),
          _kv('Whom Called', followUp['whomCalled']?.toString() ?? '-'),
          if (followUp['notes']?.toString().isNotEmpty == true)
            _kv('Notes', followUp['notes']?.toString() ?? ''),
          _kv('Call Date', date != null ? _fmt(date) : '-'),
          Row(
            children: [
              Expanded(
                child: _kv('Due Date', dueDate != null ? _fmt(dueDate) : '-'),
              ),
              if (dueDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOverdue
                        ? '${DateTime.now().difference(dueDate).inDays} days overdue'
                        : dueDate.difference(DateTime.now()).inDays == 0
                        ? 'Due today'
                        : 'Due in ${dueDate.difference(DateTime.now()).inDays} days',
                    style: TextStyle(
                      fontSize: 10,
                      color: isOverdue
                          ? Colors.red.shade700
                          : Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (followUp['poReceived'] == true &&
              followUp['poNumber']?.toString().isNotEmpty == true)
            _kv('PO Number', followUp['poNumber']?.toString() ?? ''),
          if (followUp['createdBy']?.toString().isNotEmpty == true)
            _kv('Created By', followUp['createdBy']?.toString() ?? ''),
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
          width: 100,
          child: Text(
            '$k:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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

  Future<void> _pickFollowUpDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate:
          _followUpDueDate ?? DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _followUpDueDate = picked);
  }

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CallRequest?>(
      stream: UserService.getCallRequestById(widget.callId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Call Follow Ups'),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final callRequest = snapshot.data ?? widget.callRequest;
        final followUps = callRequest.followUps;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Call Follow Ups'),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Forms and controls
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Call Details Card
                      _card(context, 'Call Details', [
                        _kv('Customer', callRequest.customerName),
                        _kv(
                          'Call Period',
                          '${_fmt(callRequest.callFromDate)} - ${_fmt(callRequest.callToDate)}',
                        ),
                        _kv(
                          'Amount',
                          '₹${callRequest.finalAmount.toStringAsFixed(2)}',
                        ),
                        _kv('Status', callRequest.status.name),
                        if (callRequest.poNumber != null &&
                            callRequest.poNumber!.isNotEmpty)
                          _kv('PO Number', callRequest.poNumber!),
                        if (callRequest.piNumber != null &&
                            callRequest.piNumber!.isNotEmpty)
                          _kv('PI Number', callRequest.piNumber!),
                      ]),

                      // PO Received Toggle (only for debtCollection)
                      if (_canAddFollowUp())
                        _card(context, 'PO Status', [
                          SwitchListTile(
                            value: _poReceived,
                            onChanged: (v) async {
                              if (v) {
                                final result =
                                    await showDialog<Map<String, String>>(
                                      context: context,
                                      builder: (ctx) {
                                        final ctrl = TextEditingController();
                                        return AlertDialog(
                                          title: const Text(
                                            'Confirm PO Received',
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Are you sure you received the PO number?',
                                              ),
                                              const SizedBox(height: 16),
                                              TextField(
                                                controller: ctrl,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'PO Number',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                if (ctrl.text
                                                    .trim()
                                                    .isNotEmpty) {
                                                  Navigator.pop(ctx, {
                                                    'poNumber': ctrl.text
                                                        .trim(),
                                                  });
                                                }
                                              },
                                              child: const Text('Confirm'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                if (result != null &&
                                    result['poNumber'] != null &&
                                    result['poNumber']!.isNotEmpty) {
                                  setState(() {
                                    _poReceived = true;
                                    _poNumberCtrl.text = result['poNumber']!;
                                  });
                                  // Immediately update status to invoice pending
                                  await UserService.savePOPIAndUpdateStatus(
                                    callId: widget.callId,
                                    type: 'PO',
                                    number: result['poNumber']!,
                                    givenBy: widget.username,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'PO marked as received and status set to invoice pending!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                setState(() {
                                  _poReceived = false;
                                  _poNumberCtrl.clear();
                                });
                              }
                            },
                            title: const Text('PO Received'),
                            subtitle: Text(
                              _poReceived
                                  ? 'Mark if PO has been received'
                                  : 'Toggle when PO is received',
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_poReceived) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _poNumberCtrl,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'PO Number',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ]),

                      // Email Follow Up Section
                      if (_canAddFollowUp())
                        _card(context, 'Email Follow Up', [
                          const Text(
                            'Send payment reminder email to customer',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _sendPaymentReminder(callRequest),
                            icon: const Icon(Icons.email),
                            label: const Text('Send Payment Reminder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ]),

                      // Call Follow Up Form
                      if (_canAddFollowUp())
                        _card(context, 'Add Call Follow Up', [
                          TextField(
                            controller: _whoCalledCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Who Called',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _whomCalledCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Whom Called',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            minLines: 2,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: const Text('Follow Up Due Date'),
                                  subtitle: Text(
                                    _followUpDueDate != null
                                        ? _fmt(_followUpDueDate!)
                                        : 'Not set',
                                  ),
                                  trailing: const Icon(Icons.event),
                                  onTap: _pickFollowUpDueDate,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _saveFollowUp,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _saving ? 'Saving...' : 'Save Follow Up',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ]),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Right side - Follow Ups History
                Expanded(
                  flex: 2,
                  child: _card(
                    context,
                    'Follow Ups History (${followUps.length})',
                    [
                      if (followUps.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No follow ups yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: followUps.asMap().entries.map((entry) {
                            final index = entry.key;
                            final followUp = entry.value;
                            return _buildFollowUpCard(followUp, index);
                          }).toList(),
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
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
