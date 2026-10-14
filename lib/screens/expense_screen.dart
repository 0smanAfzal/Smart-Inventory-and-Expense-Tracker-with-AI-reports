import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../screens/add_expense_screen.dart';
import '../services/database_service.dart';

class ExpenseScreen extends StatefulWidget {
  final bool isRoot;
  const ExpenseScreen({super.key, this.isRoot = false});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  String _selectedFilter = 'All Time';
  String _selectedCategory = 'All';

  List<Map<String, dynamic>> _expenses = [];
  StreamSubscription<List<Map<String, dynamic>>>? _expensesSubscription;

  // Defensive helper: Firestore (especially on Flutter Web) can round-trip a
  // whole-number double back as an int. DatabaseService already normalizes
  // this on read, but this guards against any stale/legacy data too, so a
  // single bad document can never crash the whole expenses list again.
  double _safeAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  DateTime _safeDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }

  List<String> get _categories {
    final cats = _expenses.map((e) => e['category'] as String).toSet().toList();
    cats.insert(0, 'All');
    return cats;
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((expense) {
      final matchesCategory = _selectedCategory == 'All' ||
          expense['category'] == _selectedCategory;
      return matchesCategory;
    }).toList()..sort((a, b) =>
        _safeDate(b['date']).compareTo(_safeDate(a['date'])));
  }

  double get _totalExpenses {
    return _filteredExpenses.fold(0.0, (sum, expense) =>
    sum + _safeAmount(expense['amount']));
  }

  Map<String, double> get _monthlyExpenseTotals {
    final Map<String, double> totals = {};
    for (final expense in _expenses) {
      final dateValue = expense['date'];
      DateTime? expenseDate;
      if (dateValue is DateTime) {
        expenseDate = dateValue;
      } else if (dateValue is String) {
        expenseDate = DateTime.tryParse(dateValue);
      }
      if (expenseDate == null) continue;
      final key = '${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}';
      totals[key] = (totals[key] ?? 0) + _safeAmount(expense['amount']);
    }
    return totals;
  }

  String get _expenseTrendLabel {
    if (_expenses.isEmpty) {
      return 'No expenses yet';
    }

    final totals = _monthlyExpenseTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (totals.length < 2) {
      return 'Need 2+ months of data';
    }

    final current = totals.last.value;
    final previous = totals[totals.length - 2].value;
    if (previous == 0) {
      return current == 0 ? 'No change' : 'New expense activity';
    }
    final percent = ((current - previous) / previous) * 100;
    final sign = percent >= 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(0)}% vs last month';
  }

  bool get _showExpenseTrendBadge {
    return _expenses.isNotEmpty && _expenseTrendLabel.contains('%');
  }

  Map<String, double> get _expensesByCategory {
    final Map<String, double> categoryTotals = {};
    for (var expense in _expenses) {
      final category = expense['category'] as String;
      final amount = _safeAmount(expense['amount']);
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }
    return categoryTotals;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadExpenses();
    _expensesSubscription = DatabaseService.streamExpenses().listen((expenses) {
      if (!mounted) return;
      setState(() => _expenses = expenses);
    });
  }

  Future<void> _loadExpenses() async {
    final expenses = await DatabaseService.getExpenses();
    if (!mounted) return;
    setState(() => _expenses = expenses);
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
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
                _buildFilterChips(),
                _buildCategoryPieChart(),
                _buildCategoryBreakdown(),
              ],
            ),
          ),
          _buildExpensesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          ).then((_) => _loadExpenses());
        },
        backgroundColor: const Color(0xFFffa726),
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
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFe43a15), Color(0xFFe65245)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                showBack ? 24 : 12,
                showBack ? 50 : 0,
                24,
                20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expenses',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredExpenses.length} transactions',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
          onPressed: () => _showDatePicker(),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: () => _showOptionsMenu(),
        ),
      ],
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
          colors: [Color(0xFFe43a15), Color(0xFFe65245)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffe61a1a).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Total Expenses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedFilter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _totalExpenses),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                'PKR ${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_showExpenseTrendBadge)
                      Icon(
                        _expenseTrendLabel.startsWith('-') ? Icons.arrow_downward : Icons.arrow_upward,
                        color: Colors.white,
                        size: 14,
                      ),
                    if (_showExpenseTrendBadge) const SizedBox(width: 4),
                    Text(
                      _expenseTrendLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All Time', 'Today', 'This Week', 'This Month'];
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == _selectedFilter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFffa726) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFffa726).withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: isSelected ? 8 : 5,
                    offset: Offset(0, isSelected ? 4 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  filter,
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

  Widget _buildCategoryPieChart() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 20),
          _expensesByCategory.isEmpty
              ? SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'No expenses yet.\nAdd one to see the breakdown.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                )
              : SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: _buildPieChartSections(),
                      pieTouchData: PieTouchData(enabled: true),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildLegend(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final categoryData = _expensesByCategory;
    final total = categoryData.values.fold(0.0, (sum, val) => sum + val);
    if (total == 0) return [];

    final colors = [
      const Color(0xFF667eea),
      const Color(0xFFffa726),
      const Color(0xFF66bb6a),
      const Color(0xFFf5576c),
      const Color(0xFF764ba2),
      const Color(0xFF42a5f5),
    ];

    return categoryData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final percentage = (category.value / total * 100);

      return PieChartSectionData(
        value: category.value,
        title: '${percentage.toStringAsFixed(0)}%',
        color: colors[index % colors.length],
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildLegend() {
    final categoryData = _expensesByCategory;
    final colors = [
      const Color(0xFF667eea),
      const Color(0xFFffa726),
      const Color(0xFF66bb6a),
      const Color(0xFFf5576c),
      const Color(0xFF764ba2),
      const Color(0xFF42a5f5),
    ];

    return categoryData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildCategoryBreakdown() {
    if (_expensesByCategory.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'By Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 16),
          ..._expensesByCategory.entries.map((entry) {
            final percentage = _totalExpenses == 0
                ? 0.0
                : (entry.value / _totalExpenses * 100);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'PKR ${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFffa726),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFffa726)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    if (_filteredExpenses.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No expenses yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add your first expense',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2d3748),
                  ),
                ),
              );
            }

            final expense = _filteredExpenses[index - 1];
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animController,
                curve: Interval(
                  index * 0.1,
                  (index * 0.1) + 0.3,
                  curve: Curves.easeOut,
                ),
              )),
              child: _buildExpenseCard(expense),
            );
          },
          childCount: _filteredExpenses.length + 1,
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExpenseDetails(expense),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (expense['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      expense['icon'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense['title'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2d3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (expense['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              expense['category'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: expense['color'] as Color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(_safeDate(expense['date'])),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR ${_safeAmount(expense['amount']).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFf5576c),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: (expense['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      expense['icon'] as String,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense['title'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expense['category'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildExpenseDetailRow('Amount', 'PKR ${_safeAmount(expense['amount']).toStringAsFixed(2)}'),
            _buildExpenseDetailRow('Date', DateFormat('MMM d, yyyy').format(_safeDate(expense['date']))),
            _buildExpenseDetailRow('Time', DateFormat('h:mm a').format(_safeDate(expense['date']))),
            if (expense['notes'] != null && (expense['notes'] as String).isNotEmpty)
              _buildExpenseDetailRow('Notes', expense['notes'] as String),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(expense: expense),
                        ),
                      ).then((_) => _loadExpenses());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFffa726),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteExpense(expense);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

  Widget _buildExpenseDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await DatabaseService.deleteExpense(expense['id']).timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    debugPrint('Delete expense timed out waiting for server confirmation. '
                        'Data is already removed from the local cache and will sync automatically.');
                  },
                );
                if (!mounted) return;
                await _loadExpenses();
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Expense deleted successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to delete expense: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() {
    // Implement date picker
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuOption('Export to PDF', Icons.picture_as_pdf_rounded),
            _buildMenuOption('Export to Excel', Icons.file_download_rounded),
            _buildMenuOption('Generate Report', Icons.analytics_rounded),
            _buildMenuOption('Set Budget', Icons.savings_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFffa726)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}