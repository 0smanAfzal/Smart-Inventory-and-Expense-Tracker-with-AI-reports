import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Screen for manually selling inventory items (as opposed to barcode scan sell).
/// Shows a searchable / filterable list of current inventory, lets the user
/// pick an item and a quantity to sell, then decreases that item's stock
/// in the backend (Firestore via DatabaseService, with mock fallback).
class SellItemScreen extends StatefulWidget {
  const SellItemScreen({super.key});

  @override
  State<SellItemScreen> createState() => _SellItemScreenState();
}

class _SellItemScreenState extends State<SellItemScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  bool _didSell = false;

  List<Map<String, dynamic>> _inventoryItems = [];
  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;

  List<String> get _categories {
    final cats = _inventoryItems.map((item) => item['category'] as String).toSet().toList();
    cats.insert(0, 'All');
    return cats;
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _inventoryItems.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          (item['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
    _inventorySubscription = DatabaseService.streamItems().listen((items) {
      if (!mounted) return;
      setState(() => _inventoryItems = items);
    });
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.getItems();
    if (!mounted) return;
    setState(() {
      _inventoryItems = items;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _didSell);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchBar(),
                  _buildCategoryFilter(),
                ],
              ),
            ),
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFffa726)),
                    ),
                  )
                : _buildItemList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context, _didSell),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFffa726), Color(0xFFef6c00)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sell Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an item to sell • ${_filteredItems.length} in stock list',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search item to sell...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFFffa726), Color(0xFFef6c00)])
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? const Color(0xFFffa726).withOpacity(0.3) : Colors.black.withOpacity(0.05),
                    blurRadius: isSelected ? 8 : 5,
                    offset: Offset(0, isSelected ? 4 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemList() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No items found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildItemCard(items[index]),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final int qty = item['quantity'] as int;
    final bool outOfStock = qty <= 0;
    final bool isLowStock = qty < (item['lowStockThreshold'] as int);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: outOfStock ? null : () => _showSellDialog(item),
          borderRadius: BorderRadius.circular(20),
          child: Opacity(
            opacity: outOfStock ? 0.5 : 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFffa726).withOpacity(0.2),
                          const Color(0xFFef6c00).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(item['image'] as String, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2d3748)),
                        ),
                        const SizedBox(height: 4),
                        Text(item['category'] as String,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.inventory, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              outOfStock ? 'Out of stock' : 'In stock: $qty',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: outOfStock
                                    ? Colors.red.shade600
                                    : (isLowStock ? Colors.orange.shade700 : Colors.grey.shade700),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'PKR ${item['price']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFffa726)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!outOfStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFffa726).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFFffa726), size: 20),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSellDialog(Map<String, dynamic> item) {
    final int availableQty = item['quantity'] as int;
    int sellQty = 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final double total = sellQty * (item['price'] as double);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Sell ${item['name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available stock: $availableQty', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: const Color(0xFFffa726),
                      onPressed: sellQty > 1 ? () => setDialogState(() => sellQty--) : null,
                    ),
                    Container(
                      width: 60,
                      alignment: Alignment.center,
                      child: Text(
                        '$sellQty',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: const Color(0xFFffa726),
                      onPressed: sellQty < availableQty ? () => setDialogState(() => sellQty++) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total: PKR ${total.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2d3748)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _confirmSell(item, sellQty);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFffa726)),
                child: const Text('Sell'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmSell(Map<String, dynamic> item, int sellQty) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFffa726))),
    );

    try {
      final int currentQty = item['quantity'] as int;
      final int newQty = currentQty - sellQty;

      final updatedItem = Map<String, dynamic>.from(item);
      updatedItem['quantity'] = newQty < 0 ? 0 : newQty;
      updatedItem['lastUpdated'] = DateTime.now();

      // Timeout guards against Firestore's write-ack stalling indefinitely on a slow
      // connection — the write is already in the local cache by the time this fires,
      // so a timeout is treated the same as success.
      bool timedOut = false;
      await DatabaseService.updateItem(updatedItem).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          timedOut = true;
          debugPrint('Sell operation timed out waiting for server confirmation. '
              'Data is already in the local cache and will sync automatically.');
        },
      );

      // Record this sale as income so it shows up in the Income screen and
      // dashboard, instead of only ever reducing stock silently.
      final double saleAmount = sellQty * (item['price'] as double);
      final Map<String, dynamic> incomeEntry = {
        'id': '${DateTime.now().millisecondsSinceEpoch}_sale',
        'title': 'Sale: ${item['name']} x$sellQty',
        'amount': saleAmount,
        'category': 'Sales',
        'icon': '💰',
        'colorHex': 'FF66bb6a',
        'date': DateTime.now(),
        'notes': 'Auto-recorded from inventory sale',
      };
      try {
        await DatabaseService.addIncome(incomeEntry).timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } catch (e) {
        debugPrint('Failed to record income for sale: $e');
      }

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      _didSell = true;
      await _loadItems();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timedOut
                      ? 'Sold $sellQty × ${item['name']} (syncing...)'
                      : 'Sold $sellQty × ${item['name']}. Stock left: ${updatedItem['quantity']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to complete sale: $e')),
      );
    }
  }
}