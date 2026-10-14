import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? expense;

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = 'Purchase';
  String _selectedEmoji = '🛒';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  final Map<String, List<String>> _categoryEmojis = {
    'Purchase': ['🛒', '📦', '🛍️', '🏪'],
    'Utilities': ['⚡', '💡', '🌐', '📡'],
    'Maintenance': ['🔧', '🔨', '⚙️', '🪛'],
    'Supplies': ['📦', '📋', '✏️', '📌'],
    'Marketing': ['📱', '📊', '💼', '📢'],
    'Salary': ['💰', '💵', '💳', '🏦'],
    'Transport': ['🚗', '🚌', '✈️', '🚢'],
    'Other': ['💡', '🎯', '📌', '⭐'],
  };

  // ✅ Store color as hex string — Flutter Color objects crash Firestore on Web
  final Map<String, String> _categoryColorHex = {
    'Purchase': 'FF667eea',
    'Utilities': 'FFffa726',
    'Maintenance': 'FFf5576c',
    'Supplies': 'FF66bb6a',
    'Marketing': 'FF764ba2',
    'Salary': 'FF42a5f5',
    'Transport': 'FFec407a',
    'Other': 'FF26a69a',
  };

  final List<Color> _categoryColors = [
    const Color(0xFF667eea),
    const Color(0xFFffa726),
    const Color(0xFFf5576c),
    const Color(0xFF66bb6a),
    const Color(0xFF764ba2),
    const Color(0xFF42a5f5),
    const Color(0xFFec407a),
    const Color(0xFF26a69a),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    if (widget.expense != null) {
      _titleController.text = widget.expense!['title'] ?? '';
      _amountController.text = widget.expense!['amount']?.toString() ?? '';
      _notesController.text = widget.expense!['notes'] ?? '';
      _selectedCategory = widget.expense!['category'] ?? 'Purchase';
      _selectedEmoji = widget.expense!['icon'] ?? '🛒';

      // ✅ Safely handle Firestore Timestamp or DateTime
      final dynamic rawDate = widget.expense!['date'];
      if (rawDate is DateTime) {
        _selectedDate = rawDate;
      } else if (rawDate != null) {
        try {
          _selectedDate = (rawDate as Timestamp).toDate();
        } catch (_) {
          _selectedDate = DateTime.now();
        }
      }
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color get _selectedColor {
    final categories = _categoryEmojis.keys.toList();
    final index = categories.indexOf(_selectedCategory);
    return _categoryColors[index % _categoryColors.length];
  }

  String get _selectedColorHex =>
      _categoryColorHex[_selectedCategory] ?? 'FF667eea';

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Expense' : 'Add Expense',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFffa726),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _animController,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAmountCard(),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _titleController,
                  label: 'Expense Title',
                  hint: 'e.g., Office Supplies Purchase',
                  icon: Icons.receipt_long_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter expense title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildCategorySection(),
                const SizedBox(height: 20),
                _buildDateTimeSection(),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes (Optional)',
                  hint: 'Additional details about this expense',
                  icon: Icons.notes_rounded,
                  maxLines: 4,
                ),
                const SizedBox(height: 32),
                _buildSaveButton(isEditing),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_selectedColor, _selectedColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 48,
                fontWeight: FontWeight.w800,
              ),
              prefixText: 'PKR ',
              prefixStyle: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter amount';
              if (double.tryParse(value) == null) return 'Invalid amount';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: _selectedColor),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _selectedColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _categoryEmojis.keys.map((category) {
                  final isSelected = category == _selectedCategory;
                  final index =
                  _categoryEmojis.keys.toList().indexOf(category);
                  final color =
                  _categoryColors[index % _categoryColors.length];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _selectedEmoji = _categoryEmojis[category]![0];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected ? color : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: _categoryEmojis[_selectedCategory]!.map((emoji) {
                  final isSelected = emoji == _selectedEmoji;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withOpacity(0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _selectedColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child:
                          Text(emoji, style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date & Time',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: _selectedColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: _selectedColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Time',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveExpense(isEditing),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isEditing ? Icons.save_rounded : Icons.add_rounded,
                size: 22),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Save Changes' : 'Add Expense',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _selectedColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _selectedColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveExpense(bool isEditing) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // guard against double-submit taps

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final String id = widget.expense?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final Map<String, dynamic> expense = {
        'id': id,
        'title': _titleController.text.trim(),
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'category': _selectedCategory,
        'icon': _selectedEmoji,
        // ✅ Store as hex string — NOT a Flutter Color object (crashes Firestore on Web)
        'colorHex': _selectedColorHex,
        // ✅ Store as Firestore Timestamp — NOT a raw DateTime
        'date': Timestamp.fromDate(dateTime),
        'notes': _notesController.text.trim(),
      };

      // Persist via DatabaseService (uses Firestore when available, otherwise mock fallback).
      // Timeout guards against Firestore's write-ack stalling indefinitely on a slow
      // connection — the write is already in the local cache by the time this fires,
      // so a timeout is treated the same as success (same fix as Add Item screen).
      final saveFuture = isEditing
          ? DatabaseService.updateExpense(expense)
          : DatabaseService.addExpense(expense);

      bool timedOut = false;
      await saveFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          timedOut = true;
          debugPrint(
            'Save operation timed out waiting for server confirmation. '
            'Data is already in the local cache and will sync automatically.',
          );
        },
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              timedOut
                  ? (isEditing ? 'Expense updated (syncing...)' : 'Expense added (syncing...)')
                  : (isEditing
                      ? 'Expense updated successfully'
                      : 'Expense added successfully'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        navigator.pop(expense);
      }
    } catch (e, stack) {
      // ✅ Plain catch — FirebaseException is NOT a Dart Exception on Flutter Web
      debugPrint('Firestore error: $e\n$stack');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense'),
        content:
        Text('Are you sure you want to delete "${_titleController.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await DatabaseService.deleteExpense(widget.expense!['id']).timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    debugPrint('Delete timed out waiting for server confirmation. '
                        'Data is already removed from the local cache and will sync automatically.');
                  },
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Expense deleted successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                    navigator.pop({'action': 'delete', 'id': widget.expense!['id']});
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}