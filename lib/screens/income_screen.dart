import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/add_income_screen.dart';
import '../services/database_service.dart';

/// Mirrors ExpenseScreen but for the money coming IN — both sales recorded
/// automatically by SellItemScreen / barcode sell, and any manually added
/// income (investment, service revenue, etc).
class IncomeScreen extends StatefulWidget {
  final bool isRoot;
  const IncomeScreen({super.key, this.isRoot = false});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  String _selectedCategory = 'All';

  List<Map<String, dynamic>> _income = [];
  StreamSubscription<List<Map<String, dynamic>>>? _incomeSubscription;

  double _safeAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  DateTime _safeDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }

  List<String> get _categories {
    final cats = _income.map((e) => e['category'] as String).toSet().toList();
    cats.insert(0, 'All');
    return cats;
  }

  List<Map<String, dynamic>> get _filteredIncome {
    return _income.where((entry) {
      return _selectedCategory == 'All' || entry['category'] == _selectedCategory;
    }).toList()
      ..sort((a, b) => _safeDate(b['date']).compareTo(_safeDate(a['date'])));
  }

  double get _totalIncome {
    return _filteredIncome.fold(0.0, (sum, e) => sum + _safeAmount(e['amount']));
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadIncome();
    _incomeSubscription = DatabaseService.streamIncome().listen((income) {
      if (!mounted) return;
      setState(() => _income = income);
    });
  }

  Future<void> _loadIncome() async {
    final income = await DatabaseService.getIncome();
    if (!mounted) return;
    setState(() => _income = income);
  }

  @override
  void dispose() {
    _incomeSubscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showBack = !widget.isRoot;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(showBack),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTotalCard(),
                _buildCategoryFilter(),
              ],
            ),
          ),
          _buildIncomeList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
          ).then((_) => _loadIncome());
        },
        backgroundColor: const Color(0xFF43a047),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildAppBar(bool showBack) {
    return SliverAppBar(
      expandedHeight: showBack ? 150 : 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: showBack
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF00b09b), Color(0xFF43a047)]),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(showBack ? 24 : 12, showBack ? 50 : 0, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Income',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredIncome.length} transactions',
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

  Widget _buildTotalCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00b09b), Color(0xFF43a047)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00b09b).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Total Income', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _totalIncome),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Text(
              'PKR ${value.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
          ),
        ],
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
                color: isSelected ? const Color(0xFF43a047) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? const Color(0xFF43a047).withOpacity(0.3) : Colors.black.withOpacity(0.05),
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

  Widget _buildIncomeList() {
    final items = _filteredIncome;
    if (items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up_rounded, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No income yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text(
                'Sales are recorded here automatically',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildIncomeCard(items[index]),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildIncomeCard(Map<String, dynamic> entry) {
    final Color color = entry['color'] is Color ? entry['color'] as Color : const Color(0xFF66bb6a);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showIncomeDetails(entry),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(entry['icon'] as String? ?? '💰', style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['title'] as String? ?? 'Income',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2d3748)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          entry['category'] as String? ?? 'Other',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'PKR ${_safeAmount(entry['amount']).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF43a047)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showIncomeDetails(Map<String, dynamic> entry) {
    final bool isAutoRecorded = entry['notes'] == 'Auto-recorded from inventory sale';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(entry['title'] as String? ?? 'Income', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(entry['category'] as String? ?? 'Other', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            _buildDetailRow('Amount', 'PKR ${_safeAmount(entry['amount']).toStringAsFixed(2)}'),
            _buildDetailRow('Date', DateFormat('MMM d, yyyy • h:mm a').format(_safeDate(entry['date']))),
            if (entry['notes'] != null && (entry['notes'] as String).isNotEmpty)
              _buildDetailRow('Notes', entry['notes'] as String),
            const SizedBox(height: 16),
            if (isAutoRecorded)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This was recorded automatically from a sale.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(entry);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Income'),
        content: Text('Are you sure you want to delete "${entry['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await DatabaseService.deleteIncome(entry['id']).timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {},
                );
                if (!mounted) return;
                await _loadIncome();
                Navigator.pop(context);
                messenger.showSnackBar(const SnackBar(content: Text('Income deleted successfully')));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}