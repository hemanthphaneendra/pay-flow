import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_service.dart';
import 'widgets/image_upload.dart';

/// Formatter that limits number input to an optional number of decimal places.
class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({this.decimalRange})
    : assert(decimalRange == null || decimalRange >= 0);

  final int? decimalRange;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Only allow digits and a single decimal point
    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(text)) return oldValue;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue; // more than one dot

    if (decimalRange != null &&
        parts.length == 2 &&
        parts[1].length > decimalRange!) {
      return oldValue; // exceeded decimal places
    }

    return newValue;
  }
}

class ExpenseEditorPage extends StatefulWidget {
  final CallRequest callRequest;
  final void Function(List<Expense>)? onSave;

  const ExpenseEditorPage({super.key, required this.callRequest, this.onSave});

  @override
  State<ExpenseEditorPage> createState() => _ExpenseEditorPageState();
}

class _ExpenseEditorPageState extends State<ExpenseEditorPage> {
  late List<Expense> _expenses;
  late List<TextEditingController> _amountControllers;
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _expenses = List.from(widget.callRequest.expenses);
    _amountControllers = _expenses
        .map(
          (e) => TextEditingController(
            text: (e.amount == 0.0) ? '' : e.amount.toStringAsFixed(2),
          ),
        )
        .toList();
    _loadExpensesWithImages();
  }

  Future<void> _loadExpensesWithImages() async {
    try {
      // Load receipt images from separate collection
      final receiptImages = await UserService.getExpenseImages(
        callRequestId: widget.callRequest.id,
        imageType: 'receipt',
      );

      // Update expenses with loaded images
      final updatedExpenses = <Expense>[];
      for (int i = 0; i < _expenses.length; i++) {
        final expense = _expenses[i];
        final receiptBase64 = i < receiptImages.length
            ? receiptImages[i]
            : null;

        updatedExpenses.add(
          Expense(
            id: expense.id,
            type: expense.type,
            amount: expense.amount,
            description: expense.description,
            date: expense.date,
            receiptBase64: receiptBase64,
          ),
        );
      }

      setState(() {
        _expenses = updatedExpenses;
        _isLoadingImages = false;
      });
    } catch (e) {
      print('Error loading expense images: $e');
      setState(() {
        _isLoadingImages = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _amountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

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
      _amountControllers.add(TextEditingController(text: ''));
    });
  }

  void _removeExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
      _amountControllers[index].dispose();
      _amountControllers.removeAt(index);
    });
  }

  Future<void> _saveExpenses() async {
    // Save to Firestore
    await UserService.updateCallRequestExpenses(
      widget.callRequest.id,
      _expenses,
    );
    if (widget.onSave != null) widget.onSave!(_expenses);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expenses'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _isLoadingImages
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading expense images...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expenses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Total: ₹${_totalExpenses.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addExpense,
                            tooltip: 'Add Expense',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _expenses.isEmpty
                        ? const Center(child: Text('No expenses added.'))
                        : ListView.builder(
                            key: ValueKey(
                              _isLoadingImages,
                            ), // Force rebuild when images load
                            itemCount: _expenses.length,
                            itemBuilder: (context, idx) {
                              final expense = _expenses[idx];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Expense type
                                          DropdownButton<ExpenseType>(
                                            value: expense.type,
                                            items: ExpenseType.values.map((
                                              type,
                                            ) {
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
                                                  description:
                                                      expense.description,
                                                  date: expense.date,
                                                  receiptBase64:
                                                      expense.receiptBase64,
                                                );
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          // Amount
                                          SizedBox(
                                            width: 120,
                                            child: Focus(
                                              onFocusChange: (hasFocus) {
                                                if (hasFocus) {
                                                  // select-all when focused for quick replacement
                                                  _amountControllers[idx]
                                                      .selection = TextSelection(
                                                    baseOffset: 0,
                                                    extentOffset:
                                                        _amountControllers[idx]
                                                            .text
                                                            .length,
                                                  );
                                                }
                                              },
                                              child: TextFormField(
                                                controller:
                                                    _amountControllers[idx],
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Amount',
                                                      isDense: true,
                                                    ),
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'[0-9.]'),
                                                  ),
                                                  DecimalTextInputFormatter(
                                                    decimalRange: 2,
                                                  ),
                                                ],
                                                onChanged: (val) {
                                                  setState(() {
                                                    _expenses[idx] = Expense(
                                                      id: expense.id,
                                                      type: expense.type,
                                                      amount:
                                                          double.tryParse(
                                                            val,
                                                          ) ??
                                                          0.0,
                                                      description:
                                                          expense.description,
                                                      date: expense.date,
                                                      receiptBase64:
                                                          expense.receiptBase64,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _removeExpense(idx),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
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
                                              receiptBase64:
                                                  expense.receiptBase64,
                                            );
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text('Receipt: '),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ImageUpload(
                                              key: ValueKey(
                                                '${expense.id}_${expense.receiptBase64?.hashCode ?? 0}',
                                              ),
                                              initialBase64:
                                                  expense.receiptBase64,
                                              onImageUploaded: (base64) {
                                                setState(() {
                                                  _expenses[idx] = Expense(
                                                    id: expense.id,
                                                    type: expense.type,
                                                    amount: expense.amount,
                                                    description:
                                                        expense.description,
                                                    date: expense.date,
                                                    receiptBase64: base64,
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: _saveExpenses,
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
