import 'package:flutter/material.dart';
import 'user_service.dart';

class ExpenseForm extends StatefulWidget {
  final String requestId;
  final String requestTitle;

  const ExpenseForm({
    super.key,
    required this.requestId,
    required this.requestTitle,
  });

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  ExpenseType _selectedType = ExpenseType.other;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final expense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _selectedType,
        amount: amount,
        description: _descriptionCtrl.text.trim(),
        date: _selectedDate,
      );

      final success = await UserService.addExpenseToWorkRequest(
        widget.requestId,
        expense,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to add expense');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding expense: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Expense'),
            Text(
              widget.requestTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSection('Expense Type', [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ExpenseType>(
                    value: _selectedType,
                    isExpanded: true,
                    items: ExpenseType.values.map((type) {
                      return DropdownMenuItem<ExpenseType>(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_getExpenseIcon(type), size: 20),
                            const SizedBox(width: 12),
                            Text(_getExpenseLabel(type)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Amount', [
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Description', [
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Date', [
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expense Date',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            _formatDate(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitExpense,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? 'Adding...' : 'Add Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  IconData _getExpenseIcon(ExpenseType type) {
    switch (type) {
      case ExpenseType.flight:
        return Icons.flight;
      case ExpenseType.hotel:
        return Icons.hotel;
      case ExpenseType.meal:
        return Icons.restaurant;
      case ExpenseType.train:
        return Icons.train;
      case ExpenseType.bus:
        return Icons.directions_bus;
      case ExpenseType.cab:
        return Icons.local_taxi;
      case ExpenseType.auto:
        return Icons.directions_car;
      case ExpenseType.other:
        return Icons.receipt;
    }
  }

  String _getExpenseLabel(ExpenseType type) {
    switch (type) {
      case ExpenseType.flight:
        return 'Flight';
      case ExpenseType.hotel:
        return 'Hotel';
      case ExpenseType.meal:
        return 'Meal';
      case ExpenseType.train:
        return 'Train';
      case ExpenseType.bus:
        return 'Bus';
      case ExpenseType.cab:
        return 'Cab';
      case ExpenseType.auto:
        return 'Auto';
      case ExpenseType.other:
        return 'Other';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
