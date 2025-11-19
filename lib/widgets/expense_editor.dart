import 'package:flutter/material.dart';
import '../user_service.dart';

class ExpenseEditor extends StatefulWidget {
  final List<Expense> initialExpenses;
  final void Function(List<Expense>) onSave;

  const ExpenseEditor({
    super.key,
    required this.initialExpenses,
    required this.onSave,
  });

  @override
  State<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<ExpenseEditor> {
  late List<Expense> _expenses;

  @override
  void initState() {
    super.initState();
    _expenses = List.from(widget.initialExpenses);
  }

  void _addExpense() {
    setState(() {
      _expenses.add(
        Expense(
          id: UniqueKey().toString(),
          type: ExpenseType.other,
          amount: 0.0,
          description: '',
          date: DateTime.now(),
          receiptBase64: null,
        ),
      );
    });
  }

  void _removeExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addExpense,
                  tooltip: 'Add Expense',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_expenses.isEmpty) const Text('No expenses added.'),
            ..._expenses.asMap().entries.map((entry) {
              final idx = entry.key;
              final expense = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DropdownButton<ExpenseType>(
                            value: expense.type,
                            items: ExpenseType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _expenses[idx] = Expense(
                                  id: expense.id,
                                  type: val ?? expense.type,
                                  amount: expense.amount,
                                  description: expense.description,
                                  date: expense.date,
                                  receiptBase64: expense.receiptBase64,
                                );
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: expense.amount.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setState(() {
                                  _expenses[idx] = Expense(
                                    id: expense.id,
                                    type: expense.type,
                                    amount: double.tryParse(val) ?? 0.0,
                                    description: expense.description,
                                    date: expense.date,
                                    receiptBase64: expense.receiptBase64,
                                  );
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeExpense(idx),
                          ),
                        ],
                      ),
                      TextFormField(
                        initialValue: expense.description,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        onChanged: (val) {
                          setState(() {
                            _expenses[idx] = Expense(
                              id: expense.id,
                              type: expense.type,
                              amount: expense.amount,
                              description: val,
                              date: expense.date,
                              receiptBase64: expense.receiptBase64,
                            );
                          });
                        },
                      ),
                      // TODO: Add image upload for receiptUrl
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Receipt: '),
                          expense.receiptBase64 != null
                              ? Image.network(
                                  expense.receiptBase64!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : const Text('No image'),
                          // TODO: Add upload button
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(_expenses);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
