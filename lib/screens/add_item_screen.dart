import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class AddItemScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  final String? barcode;

  const AddItemScreen({super.key, this.item, this.barcode});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = 'Electronics';
  String _selectedEmoji = '💻';
  bool _isLoading = false;

  final List<String> _categories = [
    'Electronics', 'Furniture', 'Stationery', 'Appliances',
    'Clothing', 'Food & Beverages', 'Tools', 'Other',
  ];

  final List<String> _emojis = [
    '💻', '🖥️', '📱', '⌚', '🎧', '📷', '🖨️', '⌨️',
    '🪑', '🛋️', '🛏️', '🚪', '🪟', '💡', '🕯️', '🪴',
    '📓', '✏️', '📚', '📊', '📋', '📌', '✂️', '📎',
    '☕', '🍔', '🍕', '🥗', '🍰', '🧃', '🥤', '🍜',
    '👕', '👔', '👗', '👠', '👜', '🎩', '🧢', '👓',
    '🔧', '🔨', '🪛', '⚙️', '🪚', '🔩', '⛏️', '🪓',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    if (widget.item != null) {
      _nameController.text = widget.item!['name'] ?? '';
      _quantityController.text = widget.item!['quantity']?.toString() ?? '';
      _priceController.text = widget.item!['price']?.toString() ?? '';
      _thresholdController.text = widget.item!['lowStockThreshold']?.toString() ?? '';
      _notesController.text = widget.item!['notes'] ?? '';
      _selectedCategory = widget.item!['category'] ?? 'Electronics';
      _selectedEmoji = widget.item!['image'] ?? '💻';
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Item' : 'Add New Item',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF667eea),
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
                _buildEmojiPicker(),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _nameController,
                  label: 'Item Name',
                  hint: 'e.g., Laptop Dell XPS 15',
                  icon: Icons.inventory_2_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter item name';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildCategoryDropdown(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _quantityController,
                        label: 'Quantity',
                        hint: '0',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _priceController,
                        label: 'Unit Price',
                        hint: '0.00',
                        icon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _thresholdController,
                  label: 'Low Stock Threshold',
                  hint: 'Alert when quantity falls below',
                  icon: Icons.warning_amber_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter threshold';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes (Optional)',
                  hint: 'Additional information about this item',
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

  Widget _buildEmojiPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Icon',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withOpacity(0.2),
                      const Color(0xFF764ba2).withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _emojis[index];
                    final isSelected = emoji == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF667eea).withOpacity(0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF667eea)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
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
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF667eea)),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded, color: Color(0xFF667eea), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        category,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedCategory = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveItem(isEditing),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667eea),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 22),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Save Changes' : 'Add Item',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveItem(bool isEditing) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // guard against double-submit taps

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final String id =
          widget.item?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

      final Map<String, dynamic> item = {
        'id': id,
        'name': _nameController.text.trim(),
        'barcode': widget.barcode ?? widget.item?['barcode'],
        'category': _selectedCategory,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'lowStockThreshold': int.tryParse(_thresholdController.text) ?? 0,
        'image': _selectedEmoji,
        'notes': _notesController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Persist via DatabaseService (uses Firestore when available, otherwise mock fallback).
      // Firestore's offline persistence writes to the local cache instantly, but the
      // returned Future only resolves once the server acknowledges the write. On a slow
      // or flaky connection that ack can stall indefinitely, which used to leave the
      // save button spinning forever even though the item was already saved locally.
      // A timeout guarantees this always resolves within a few seconds; if it times out,
      // the data is already safely in the local cache and will sync automatically.
      final saveFuture = isEditing
          ? DatabaseService.updateItem(item)
          : DatabaseService.addItem(item);

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
                  ? (isEditing ? 'Item updated (syncing...)' : 'Item added (syncing...)')
                  : (isEditing ? 'Item updated successfully' : 'Item added successfully'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        navigator.pop(item);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${_nameController.text}"?'),
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
                await DatabaseService.deleteItem(widget.item!['id'])
                    .timeout(const Duration(seconds: 2), onTimeout: () {});
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Item deleted successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  navigator.pop({'action': 'delete', 'id': widget.item!['id']});
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}