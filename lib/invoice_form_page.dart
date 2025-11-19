import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InvoiceFormPage extends StatefulWidget {
  final String username;
  final String userType;
  final String? invoiceId; // null when creating new
  final Map<String, dynamic>? initialData; // Existing data when editing
  const InvoiceFormPage({
    super.key,
    required this.username,
    required this.userType,
    this.invoiceId,
    this.initialData,
  });

  @override
  State<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends State<InvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNoCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  DateTime? _invoiceDate = DateTime.now();
  DateTime? _dueDate = DateTime.now();
  DateTime? _serviceFrom;
  DateTime? _serviceTo;
  String? _serviceType; // 'AMC' or 'Call'
  String? _company; // Company field
  bool _saving = false;
  String? _error;
  bool get _editing => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _invoiceNoCtrl.text = data['invoiceNo']?.toString() ?? '';
      _customerNameCtrl.text = data['customerName']?.toString() ?? '';
      _descriptionCtrl.text = data['description']?.toString() ?? '';
      _totalAmountCtrl.text = (data['totalAmount'] != null)
          ? data['totalAmount'].toString()
          : '';
      _invoiceDate = _readTs(data['invoiceDate']) ?? _invoiceDate;
      _dueDate = _readTs(data['dueDate']) ?? _dueDate;
      _serviceFrom = _readTs(data['serviceFrom']);
      _serviceTo = _readTs(data['serviceTo']);
      _serviceType = data['serviceType']?.toString();
      _company = data['company']?.toString();
    }
  }

  DateTime? _readTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDate: _invoiceDate ?? now,
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
    }
  }

  Future<void> _pickDueDate() async {
    final base = _invoiceDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: base.subtract(const Duration(days: 365)),
      lastDate: base.add(const Duration(days: 365 * 5)),
      initialDate: _dueDate ?? base,
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _setDueDateFromDays(int days) {
    if (_invoiceDate != null) {
      setState(() {
        _dueDate = _invoiceDate!.add(Duration(days: days));
      });
    }
  }

  Widget _quickDayButton(BuildContext context, String label, int days) {
    final isEnabled = _invoiceDate != null;
    return Expanded(
      child: Tooltip(
        message: isEnabled
            ? 'Set due date to $days days from invoice date'
            : 'Select invoice date first',
        child: OutlinedButton(
          onPressed: isEnabled ? () => _setDueDateFromDays(days) : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            side: BorderSide(
              color: isEnabled ? Colors.blue.shade300 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isEnabled ? Colors.blue.shade700 : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickServiceFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDate: _serviceFrom ?? now,
    );
    if (picked != null) {
      setState(() {
        _serviceFrom = picked;
        if (_serviceTo != null && _serviceTo!.isBefore(picked)) {
          _serviceTo = picked;
        }
      });
    }
  }

  Future<void> _pickServiceTo() async {
    final ref = _serviceFrom ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: ref,
      lastDate: DateTime(ref.year + 3),
      initialDate: _serviceTo ?? ref,
    );
    if (picked != null) {
      setState(() => _serviceTo = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Manual field-level validations not covered by per-field validators
    if (_invoiceDate == null) {
      setState(() => _error = 'Pick an invoice date');
      return;
    }
    if (_dueDate == null) {
      setState(() => _error = 'Pick a due date');
      return;
    }
    if (_serviceFrom == null || _serviceTo == null) {
      setState(() => _error = 'Select service from & to dates');
      return;
    }
    if (_serviceFrom!.isAfter(_serviceTo!)) {
      setState(() => _error = 'Service From must be before Service To');
      return;
    }
    if (_serviceType == null) {
      setState(() => _error = 'Select service type');
      return;
    }
    if (_company == null) {
      setState(() => _error = 'Select company');
      return;
    }
    // Validate amount
    final amtText = _totalAmountCtrl.text.trim();
    double? parsedAmount;
    if (amtText.isEmpty) {
      setState(() => _error = 'Enter total amount');
      return;
    } else {
      parsedAmount = double.tryParse(amtText.replaceAll(',', ''));
      if (parsedAmount == null) {
        setState(() => _error = 'Enter a valid numeric amount');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final newInvoiceNo = _invoiceNoCtrl.text.trim();
      // Uniqueness check if creating OR invoice number changed
      if (!_editing ||
          (widget.initialData?['invoiceNo']?.toString() != newInvoiceNo)) {
        final dup = await FirebaseFirestore.instance
            .collection('invoices')
            .where('invoiceNo', isEqualTo: newInvoiceNo)
            .limit(1)
            .get();
        if (dup.docs.isNotEmpty) {
          setState(() => _error = 'Invoice number already exists');
          return;
        }
      }

      final data = <String, dynamic>{
        'invoiceNo': newInvoiceNo,
        'invoiceDate': Timestamp.fromDate(_invoiceDate!),
        'dueDate': Timestamp.fromDate(_dueDate!),
        'serviceFrom': Timestamp.fromDate(_serviceFrom!),
        'serviceTo': Timestamp.fromDate(_serviceTo!),
        'serviceType': _serviceType,
        'company': _company,
        'totalAmount': parsedAmount,
        'customerName': _customerNameCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'createdBy': widget.username,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_editing) {
        // Preserve original createdAt if present
        final existingCreatedAt = widget.initialData?['createdAt'];
        if (existingCreatedAt != null) {
          data['createdAt'] = existingCreatedAt;
        }
        // Preserve existing status if present
        if (widget.initialData?['status'] != null) {
          data['status'] = widget.initialData!['status'];
        }
        await FirebaseFirestore.instance
            .collection('invoices')
            .doc(widget.invoiceId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['status'] = 'pending';
        await FirebaseFirestore.instance.collection('invoices').add(data);

        // Notification functionality has been removed
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _invoiceNoCtrl.dispose();
    _customerNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _totalAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Invoice' : 'New Invoice')),
      body: Stack(
        children: [
          // Soft background gradient reusing blue/white palette
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                  Colors.blue.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.blue.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.blue.shade600,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _editing ? 'Edit Invoice' : 'Invoice Details',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blue.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _invoiceNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Invoice No.',
                            prefixIcon: Icon(Icons.tag),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Invoice Date',
                                prefixIcon: const Icon(
                                  Icons.date_range_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: _pickDate,
                                  icon: const Icon(
                                    Icons.edit_calendar_outlined,
                                  ),
                                ),
                              ),
                              validator: (_) =>
                                  _invoiceDate == null ? 'Pick a date' : null,
                              controller: TextEditingController(
                                text: _invoiceDate == null
                                    ? ''
                                    : '${_invoiceDate!.year}-${_invoiceDate!.month.toString().padLeft(2, '0')}-${_invoiceDate!.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: _pickDueDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Due Date',
                                prefixIcon: const Icon(
                                  Icons.event_note_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: _pickDueDate,
                                  icon: const Icon(
                                    Icons.edit_calendar_outlined,
                                  ),
                                ),
                              ),
                              validator: (_) =>
                                  _dueDate == null ? 'Pick due date' : null,
                              controller: TextEditingController(
                                text: _dueDate == null
                                    ? ''
                                    : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Quick due date options
                        Text(
                          'Quick Due Date Options${_invoiceDate == null ? ' (select invoice date first)' : ''}:',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _quickDayButton(context, '15 days', 15),
                            const SizedBox(width: 8),
                            _quickDayButton(context, '30 days', 30),
                            const SizedBox(width: 8),
                            _quickDayButton(context, '45 days', 45),
                            const SizedBox(width: 8),
                            _quickDayButton(context, '60 days', 60),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickServiceFrom,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Service From',
                                      prefixIcon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                    ),
                                    validator: (_) => _serviceFrom == null
                                        ? 'Required'
                                        : null,
                                    controller: TextEditingController(
                                      text: _serviceFrom == null
                                          ? ''
                                          : '${_serviceFrom!.year}-${_serviceFrom!.month.toString().padLeft(2, '0')}-${_serviceFrom!.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickServiceTo,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Service To',
                                      prefixIcon: const Icon(
                                        Icons.stop_rounded,
                                      ),
                                    ),
                                    validator: (_) =>
                                        _serviceTo == null ? 'Required' : null,
                                    controller: TextEditingController(
                                      text: _serviceTo == null
                                          ? ''
                                          : '${_serviceTo!.year}-${_serviceTo!.month.toString().padLeft(2, '0')}-${_serviceTo!.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: _serviceType,
                          decoration: const InputDecoration(
                            labelText: 'Service Type',
                            prefixIcon: Icon(Icons.build_circle_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'AMC', child: Text('AMC')),
                            DropdownMenuItem(
                              value: 'Call',
                              child: Text('Call'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _serviceType = v),
                          validator: (v) => v == null ? 'Select type' : null,
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: _company,
                          decoration: const InputDecoration(
                            labelText: 'Company',
                            prefixIcon: Icon(Icons.business),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ACME',
                              child: Text('ACME'),
                            ),
                            DropdownMenuItem(
                              value: 'AAMS',
                              child: Text('AAMS'),
                            ),
                            DropdownMenuItem(
                              value: 'ALMAS',
                              child: Text('ALMAS'),
                            ),
                            DropdownMenuItem(
                              value: 'ACME Pvt.LTD.',
                              child: Text('ACME Pvt.LTD.'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _company = v),
                          validator: (v) => v == null ? 'Select company' : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _customerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _totalAmountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Total Amount',
                            prefixIcon: Icon(Icons.paid_outlined),
                            hintText: 'e.g. 1250.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter amount'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _descriptionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                          maxLines: 4,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 26),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: cs.errorContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: cs.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: cs.error,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _GradientActionButton(
                                onTap: _saving ? null : _save,
                                label: _saving
                                    ? 'Saving...'
                                    : _editing
                                    ? 'Update Invoice'
                                    : 'Save Invoice',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  const _GradientActionButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final gradient = LinearGradient(
      colors: enabled
          ? [Colors.blue.shade700, Colors.blue.shade500, Colors.blue.shade400]
          : [Colors.blueGrey.shade300, Colors.blueGrey.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1 : .6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade800.withValues(alpha: .30),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
