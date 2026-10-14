import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = 'Sales';
  String _selectedEmoji = '💰';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final Map<String, String> _categoryEmojis = {
    'Sales': '💰',
    'Service': '🛠️',
    'Investment': '📈',
    'Refund': '↩️',
    'Other': '⭐',
  };

  final Map<String, String> _categoryColorHex = {
    'Sales': 'FF66bb6a',
    'Service': 'FF42a5f5',
    'Investment': 'FF764ba2',
    'Refund': 'FFffa726',
    'Other': 'FF26a69a',
  };

  final List<Color> _categoryColors = [
    const Color(0xFF66bb6a),
    const Color(0xFF42a5f5),
    const Color(0xFF764ba2),
    const Color(0xFFffa726),
    const Color(0xFF26a69a),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
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

  String get _selectedColorHex => _categoryColorHex[_selectedCategory] ?? 'FF66bb6a';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add Income', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF43a047),
        foregroundColor: Colors.white,
        elevation: 0,
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
                  label: 'Income Title',
                  hint: 'e.g., Wholesale order payment',
                  icon: Icons.description_rounded,
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 20),
                _buildCategorySection(),
                const SizedBox(height: 20),
                _buildDateSection(),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes (Optional)',
                  hint: 'Additional details about this income',
                  icon: Icons.notes_rounded,
                  maxLines: 4,
                ),
                const SizedBox(height: 32),
                _buildSaveButton(),
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
        gradient: LinearGradient(colors: [_selectedColor, _selectedColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _selectedColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Center(child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48))),
          ),
          const SizedBox(height: 20),
          const Text('Amount', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -2),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 48, fontWeight: FontWeight.w800),
              prefixText: 'PKR ',
              prefixStyle: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800),
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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2d3748))),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _selectedColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2d3748))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _categoryEmojis.keys.map((category) {
              final isSelected = category == _selectedCategory;
              final index = _categoryEmojis.keys.toList().indexOf(category);
              final color = _categoryColors[index % _categoryColors.length];

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCategory = category;
                  _selectedEmoji = _categoryEmojis[category]!;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                  ),
                  child: Text(
                    '${_categoryEmojis[category]} $category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2d3748))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: _selectedColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveIncome,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 22),
                  SizedBox(width: 8),
                  Text('Add Income', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _selectedColor, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final String id = DateTime.now().millisecondsSinceEpoch.toString();

      final Map<String, dynamic> income = {
        'id': id,
        'title': _titleController.text.trim(),
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'category': _selectedCategory,
        'icon': _selectedEmoji,
        'colorHex': _selectedColorHex,
        'date': Timestamp.fromDate(_selectedDate),
        'notes': _notesController.text.trim(),
      };

      bool timedOut = false;
      await DatabaseService.addIncome(income).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          timedOut = true;
          debugPrint('Save income timed out waiting for server confirmation. '
              'Data is already in the local cache and will sync automatically.');
        },
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(timedOut ? 'Income added (syncing...)' : 'Income added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        navigator.pop(income);
      }
    } catch (e) {
      debugPrint('Firestore error: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}