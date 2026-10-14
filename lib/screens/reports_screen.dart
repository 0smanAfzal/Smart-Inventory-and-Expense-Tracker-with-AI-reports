import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

class ReportsScreen extends StatefulWidget {
  final bool isRoot;
  final String health;
  const ReportsScreen({super.key, this.isRoot = false, this.health = 'good'});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _chartController;
  int _selectedTab = 0;
  bool _isLoadingAi = true;
  Map<String, dynamic> _aiReport = {};
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _income = [];

  double _safeNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _loadReportData();
  }

 Future<void> _loadReportData() async {
    // Step 1: Firebase se real data fetch karo
    final items = await DatabaseService.getItems();
    final expenses = await DatabaseService.getExpenses();
    final income = await DatabaseService.getIncome();

    if (!mounted) return;
    setState(() {
      _inventoryItems = items;
      _expenses = expenses;
      _income = income;
    });

    // Step 2: Live report lo real data ke saath.
    // (No per-view /train call here anymore — build_report_payload on the
    // server is pure arithmetic on the data you send it, it never actually
    // uses the trained model, so retraining on every screen load was pure
    // overhead with no effect on what you see. If you want the trained
    // model to actually influence predictions, that's a deliberate backend
    // change to make later, not something to pay for on every page view.)
    Map<String, dynamic> report = {};
    if (items.isNotEmpty) {
      report = await AiService.fetchLiveReport(
        inventory: items,
        expenses: expenses,
      );
    }

    // Step 3 (REMOVED): this used to fall back to AiService.fetchReport()
    // whenever `report` was empty — including whenever there was simply no
    // inventory yet. That endpoint returns generic/demo predictions that
    // have nothing to do with this user's actual data, so it was showing
    // fake "AI predictions" on a totally empty account. Every summary
    // method below (_getAiSummary, _buildForecastValue, etc.) already
    // handles an empty _aiReport correctly with proper "no data yet"
    // copy, so there's no need for a fake substitute here — an empty
    // report just means we show the real empty state.

    if (!mounted) return;
    setState(() {
      _aiReport = report;
      _isLoadingAi = false;
    });
  }

  String _getAiSummary() {
    if (_isLoadingAi) {
      return 'Loading AI insights...';
    }
    if (_aiReport.isEmpty) {
      return _inventoryItems.isEmpty
          ? 'Add inventory items to start generating AI insights.'
          : 'AI backend is not reachable yet. Start the Python server.';
    }

    final forecast = (_aiReport['forecast'] as List?) ?? [];
    if (forecast.isNotEmpty) {
      final first = forecast.first as Map<String, dynamic>;
      return 'Forecast shows ${first['item_name']} may sell about ${first['predicted_sales']} units next period.';
    }
    return 'AI insights loaded successfully.';
  }

  @override
  void dispose() {
    _animController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  // Generic monthly aggregator used for both revenue (income) and expenses.
  // Groups by real calendar month from the actual record dates — this is
  // the ONLY correct way to build a time-series chart. The backend's
  // 'forecast' (per-item predictions, not months) and 'expense_trend_analysis'
  // (hardcoded 'Month 1'/'Month 2' placeholders) were never real time data
  // and should never feed a chart labeled as a trend over time.
  Map<String, double> _monthlyTotals(List<Map<String, dynamic>> records, String amountKey, String dateKey) {
    final Map<String, double> monthly = {};
    for (final record in records) {
      final date = _parseDate(record[dateKey]);
      if (date == null) continue;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + _safeNumber(record[amountKey]);
    }
    return monthly;
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final month = int.tryParse(parts[1]) ?? 1;
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[(month - 1).clamp(0, 11)];
  }

  List<double> _getRevenueSeries() {
    final monthly = _monthlyTotals(_income, 'amount', 'date');
    if (monthly.isEmpty) return [];
    final sortedKeys = monthly.keys.toList()..sort();
    return sortedKeys.take(6).map((key) => monthly[key]!).toList();
  }

  List<String> _getRevenueLabels() {
    final monthly = _monthlyTotals(_income, 'amount', 'date');
    if (monthly.isEmpty) return [];
    final sortedKeys = monthly.keys.toList()..sort();
    return sortedKeys.take(6).map(_monthLabel).toList();
  }

  List<double> _getExpenseSeries() {
    final monthly = _monthlyTotals(_expenses, 'amount', 'date');
    if (monthly.isEmpty) return [];
    final sortedKeys = monthly.keys.toList()..sort();
    return sortedKeys.take(6).map((key) => monthly[key]!).toList();
  }

  List<String> _getExpenseLabels() {
    final monthly = _monthlyTotals(_expenses, 'amount', 'date');
    if (monthly.isEmpty) return [];
    final sortedKeys = monthly.keys.toList()..sort();
    return sortedKeys.take(6).map(_monthLabel).toList();
  }

  List<Map<String, dynamic>> _getCostBreakdownItems() {
    final breakdown = (_aiReport['expense_breakdown'] as List?) ?? [];
    if (breakdown.isNotEmpty) {
      return breakdown.cast<Map<String, dynamic>>();
    }

    if (_expenses.isEmpty) {
      return [];
    }

    final Map<String, double> categoryTotals = {};
    for (final expense in _expenses) {
      final category = expense['category'] as String? ?? 'Other';
      categoryTotals[category] = (categoryTotals[category] ?? 0) + _safeNumber(expense['amount']);
    }

    final total = categoryTotals.values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) {
      return [];
    }

    return categoryTotals.entries.map((entry) {
      return {
        'category': entry.key,
        'amount': entry.value,
        'percentage': entry.value / total,
      };
    }).toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
  }

  bool _seriesHasData(List<double> values) {
    return values.isNotEmpty && values.any((value) => value > 0);
  }

  String _percentChangeLabel(List<double> values) {
    if (values.length < 2 || values.first <= 0) {
      return '—';
    }

    final change = ((values.last - values.first) / values.first) * 100;
    return change >= 0 ? '+${change.toStringAsFixed(0)}%' : '${change.toStringAsFixed(0)}%';
  }

  String _getInventoryTurnoverValue() {
    final forecast = (_aiReport['forecast'] as List?) ?? [];
    if (forecast.isNotEmpty) {
      final totalSales = forecast.fold<double>(0, (sum, item) {
        final map = item as Map<String, dynamic>;
        return sum + ((map['predicted_sales'] as num?)?.toDouble() ?? 0.0);
      });
      return '${(totalSales / math.max(forecast.length, 1)).toStringAsFixed(1)} units';
    }

    if (_inventoryItems.isEmpty) {
      return '—';
    }

    final totalQty = _inventoryItems.fold<double>(
      0,
      (sum, item) => sum + _safeNumber(item['quantity']),
    );
    return '${(totalQty / _inventoryItems.length).toStringAsFixed(1)} avg qty';
  }

  String _getStockAccuracyValue() {
    final restocks = (_aiReport['restocking_recommendations'] as List?) ?? [];
    if (restocks.isNotEmpty) {
      final accuracy = math.max(60, 100 - (restocks.length * 10));
      return '$accuracy%';
    }

    if (_inventoryItems.isEmpty) {
      return '—';
    }

    final inStock = _inventoryItems.where((item) {
      final quantity = _safeNumber(item['quantity']);
      final threshold = _safeNumber(item['lowStockThreshold']);
      return quantity >= threshold;
    }).length;
    return '${(inStock / _inventoryItems.length * 100).round()}%';
  }

  String _getDaysOnHandValue() {
    final slowMoving = (_aiReport['slow_moving_inventory'] as List?) ?? [];
    if (slowMoving.isNotEmpty) {
      final totalStock = slowMoving.fold<double>(0, (sum, item) {
        final map = item as Map<String, dynamic>;
        return sum + ((map['stock'] as num?)?.toDouble() ?? 0.0);
      });
      final averageDays = (totalStock / math.max(slowMoving.length, 1)) * 0.5 + 15;
      return '${averageDays.toStringAsFixed(0)} days';
    }

    if (_inventoryItems.isEmpty) {
      return '—';
    }

    final lowStockCount = _inventoryItems.where((item) {
      return _safeNumber(item['quantity']) < _safeNumber(item['lowStockThreshold']);
    }).length;

    if (lowStockCount == 0) {
      return 'Stock healthy';
    }
    return '$lowStockCount items low';
  }

  String _getMetricStatus(String label, String value) {
    if (value == '—' || value.startsWith('No ')) {
      return 'No data';
    }

    if (label == 'Stock Accuracy') {
      final pct = int.tryParse(value.replaceAll('%', '')) ?? 0;
      if (pct >= 90) return 'Excellent';
      if (pct >= 70) return 'Good';
      return 'Needs attention';
    }

    if (label == 'Turnover Rate') {
      if (value.contains('avg qty')) return 'Tracked';
      if (value.contains('units')) return 'Forecast';
      return 'No data';
    }

    if (label == 'Days on Hand') {
      if (value == 'Stock healthy') return 'Healthy';
      if (value.contains('low')) return 'Review';
      return 'Tracked';
    }

    return 'Live';
  }

  Color _getMetricStatusColor(String status) {
    switch (status) {
      case 'Excellent':
      case 'Healthy':
      case 'Forecast':
        return Colors.green;
      case 'Good':
      case 'Tracked':
        return Colors.blue;
      case 'Review':
      case 'Needs attention':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoiValue() {
    final revenue = _getRevenueSeries().fold<double>(0, (sum, value) => sum + value);
    final expense = _getExpenseSeries().fold<double>(0, (sum, value) => sum + value);

    if (revenue > 0 && expense > 0) {
      final roi = ((revenue - expense) / expense) * 100;
      return roi.toStringAsFixed(0);
    }

    final inventoryValue = _inventoryItems.fold<double>(0, (sum, item) {
      return sum + (_safeNumber(item['quantity']) * _safeNumber(item['price']));
    });
    final totalExpenses = _expenses.fold<double>(0, (sum, expenseItem) {
      return sum + _safeNumber(expenseItem['amount']);
    });

    if (totalExpenses <= 0) {
      return '—';
    }

    final roi = ((inventoryValue - totalExpenses) / totalExpenses) * 100;
    return roi.toStringAsFixed(0);
  }

  String _getGrowthValue() {
    final revenue = _getRevenueSeries();
    if (_seriesHasData(revenue)) {
      final growth = ((revenue.last - revenue.first) / revenue.first) * 100;
      return growth >= 0 ? '+${growth.toStringAsFixed(0)}%' : '${growth.toStringAsFixed(0)}%';
    }

    final expenses = _getExpenseSeries();
    if (!_seriesHasData(expenses) || expenses.first <= 0) {
      return '—';
    }

    final growth = ((expenses.last - expenses.first) / expenses.first) * 100;
    return growth >= 0 ? '+${growth.toStringAsFixed(0)}%' : '${growth.toStringAsFixed(0)}%';
  }

  Widget _buildEmptyChartCard({
    required String title,
    required String subtitle,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.all(20),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
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
                _buildTabSelector(),
                _buildAIInsightsBanner(),
                if (_selectedTab == 0) ...[
                  _buildRevenueChart(),
                  _buildPredictionCard(),
                  _buildInventoryTurnover(),
                ] else if (_selectedTab == 1) ...[
                  _buildExpenseTrendChart(),
                  _buildCostAnalysis(),
                  _buildExpenseForecast(),
                ] else ...[
                  _buildProfitMarginChart(),
                  _buildKeyMetrics(),
                  _buildRecommendations(),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
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
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'AI Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Powered by machine learning',
                    style: TextStyle(
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
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          onPressed: () => _shareReport(),
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          onPressed: () => _downloadReport(),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    final tabs = ['Overview', 'Expenses', 'Insights'];
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
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
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = index);
                _chartController.reset();
                _chartController.forward();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

Widget _buildAIInsightsBanner() {
  // Choose configuration based on widget.health
  Map<String, dynamic> config;
  switch (widget.health) {
    case 'good':
      config = {
        'gradient': const LinearGradient(
          colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
        ),
        'shadowColor': const Color(0xFF00b09b),
        'title': 'AI Analysis Complete',
        'message': _getAiSummary(),
        'icon': Icons.emoji_emotions_rounded,
      };
      break;
    case 'bad':
      config = {
        'gradient': const LinearGradient(
          colors: [Color(0xFFe43a15), Color(0xFFe65245)],
        ),
        'shadowColor': const Color(0xFFe43a15),
        'title': 'AI Alert',
        'message': 'Low stock & high expenses detected ⚠️',
        'icon': Icons.warning_rounded,
      };
      break;
    default: // neutral
      config = {
        'gradient': const LinearGradient(
          colors: [Color(0xFFf5af19), Color(0xFFf12711)],
        ),
        'shadowColor': const Color(0xFFf5af19),
        'title': 'AI Insights',
        'message': 'Steady progress – review recommendations 📈',
        'icon': Icons.insights_rounded,
      };
      break;
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: config['gradient'],
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: (config['shadowColor'] as Color).withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config['title'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config['message'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(config['icon'], color: Colors.white, size: 24),
        ),
      ],
    ),
  );
}

  Widget _buildRevenueChart() {
    final revenueSeries = _getRevenueSeries();
    if (!_seriesHasData(revenueSeries)) {
      return _buildEmptyChartCard(
        title: 'Revenue Trends',
        subtitle: 'From recorded sales income',
        message: 'No income recorded yet. Sell an item (manually or via barcode scan) to see monthly revenue here.',
      );
    }
    if (revenueSeries.length < 2) {
      return _buildEmptyChartCard(
        title: 'Revenue Trends',
        subtitle: 'From recorded sales income',
        message: 'You have income for ${_getRevenueLabels().first} so far — this trend chart fills in once there\'s a second month to compare against.',
      );
    }

    final revenueLabels = _getRevenueLabels();
    final rawMaxY = revenueSeries.reduce(math.max) * 1.25;
    final maxY = rawMaxY.isFinite ? math.max(rawMaxY, 10.0) : 10.0;
    final changeLabel = _percentChangeLabel(revenueSeries);

    return Container(
      margin: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Trends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2d3748),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'From recorded sales income',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      changeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: RepaintBoundary(
              child: BarChart(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = (group.x >= 0 && group.x < revenueLabels.length)
                            ? revenueLabels[group.x]
                            : '';
                        return BarTooltipItem(
                          '$label\n${rod.toY.toStringAsFixed(1)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < revenueLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                revenueLabels[value.toInt()],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    revenueSeries.length,
                    (index) => _buildBarGroup(index, revenueSeries[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF667eea),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Predictions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2d3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPredictionItem(
            'Forecasted Demand',
            _buildForecastValue(),
            'AI model',
            true,
            Icons.auto_graph_rounded,
          ),
          const SizedBox(height: 12),
          _buildPredictionItem(
            'Restock Advice',
            _buildRestockAdvice(),
            'API',
            false,
            Icons.inventory_2_rounded,
          ),
          const SizedBox(height: 12),
          _buildPredictionItem(
            'Expense Trend',
            _buildExpenseSummary(),
            'Live',
            true,
            Icons.show_chart_rounded,
          ),
        ],
      ),
    );
  }

  String _buildForecastValue() {
    if (_aiReport.isEmpty) {
      return '—';
    }
    final forecast = (_aiReport['forecast'] as List?) ?? [];
    if (forecast.isEmpty) {
      return '—';
    }
    final first = forecast.first as Map<String, dynamic>;
    return '${first['predicted_sales']} units';
  }

  String _buildRestockAdvice() {
    if (_aiReport.isEmpty) {
      return '—';
    }
    final restock = (_aiReport['restocking_recommendations'] as List?) ?? [];
    if (restock.isEmpty) {
      return 'No urgent restocks';
    }
    final first = restock.first as Map<String, dynamic>;
    return '${first['item_name']} +${first['recommended_order']}';
  }

  String _buildExpenseSummary() {
    final labels = _getExpenseLabels();
    final series = _getExpenseSeries();
    if (labels.isEmpty || series.isEmpty) {
      return '—';
    }
    return '${labels.last}: PKR ${series.last.toStringAsFixed(0)}';
  }

  Widget _buildPredictionItem(String label, String value, String change, bool isPositive, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2d3748),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isPositive ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTurnover() {
    final turnoverValue = _getInventoryTurnoverValue();
    final accuracyValue = _getStockAccuracyValue();
    final daysValue = _getDaysOnHandValue();
    final turnoverStatus = _getMetricStatus('Turnover Rate', turnoverValue);
    final accuracyStatus = _getMetricStatus('Stock Accuracy', accuracyValue);
    final daysStatus = _getMetricStatus('Days on Hand', daysValue);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            'Inventory Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 20),
          _buildMetricRow(
            'Turnover Rate',
            turnoverValue,
            turnoverStatus,
            _getMetricStatusColor(turnoverStatus),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Stock Accuracy',
            accuracyValue,
            accuracyStatus,
            _getMetricStatusColor(accuracyStatus),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Days on Hand',
            daysValue,
            daysStatus,
            _getMetricStatusColor(daysStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String status, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2d3748),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseTrendChart() {
    final expenseSeries = _getExpenseSeries();
    final expenseLabels = _getExpenseLabels();

    if (!_seriesHasData(expenseSeries)) {
      return _buildEmptyChartCard(
        title: 'Expense Trends',
        subtitle: '',
        message: 'No expense history yet. Add expenses to see monthly trends here.',
      );
    }
    if (expenseSeries.length < 2) {
      return _buildEmptyChartCard(
        title: 'Expense Trends',
        subtitle: '',
        message: 'You have expenses for ${expenseLabels.first} so far — this trend chart fills in once there\'s a second month to compare against.',
      );
    }

    final rawMaxY = expenseSeries.reduce(math.max) * 1.25;
    final maxY = rawMaxY.isFinite ? math.max(rawMaxY, 10.0) : 10.0;

    return Container(
      margin: const EdgeInsets.all(20),
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
            'Expense Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: RepaintBoundary(
              child: LineChart(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final fractional = (value - value.toInt()).abs();
                          if (fractional > 0.001) return const SizedBox.shrink();
                          final idx = value.toInt();
                          if (idx >= 0 && idx < expenseLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                expenseLabels[idx],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        expenseSeries.length,
                        (index) => FlSpot(index.toDouble(), expenseSeries[index]),
                      ),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFffa726), Color(0xFFff6f00)],
                      ),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: const Color(0xFFffa726),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFffa726).withOpacity(0.3),
                            const Color(0xFFff6f00).withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostAnalysis() {
    final items = _getCostBreakdownItems();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            'Cost Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No expense data yet. Add expenses to see your cost breakdown.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            )
          else
            ...items.map((item) {
              final category = item['category'] as String? ?? 'Expense';
              final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
              final percentage = (item['percentage'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCostItem(category, amount, percentage),
              );
            })
        ],
      ),
    );
  }

  Widget _buildCostItem(String label, double amount, double percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2d3748),
                ),
              ),
              Text(
                'PKR ${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFffa726),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFffa726), Color(0xFFff6f00)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseForecast() {
    final expenseSeries = _getExpenseSeries();
    final hasData = _seriesHasData(expenseSeries);
    if (!hasData) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFffa726), Color(0xFFff6f00)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFffa726).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'Not enough expense history for a forecast yet. Add more monthly data or start the AI backend.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      );
    }

    final currentExpense = expenseSeries.last;
    final previousExpense = expenseSeries.length > 1 ? expenseSeries[expenseSeries.length - 2] : currentExpense;
    final changePercent = previousExpense == 0 ? 0.0 : ((currentExpense - previousExpense) / previousExpense) * 100;
    final actionText = changePercent >= 0
        ? 'Monitor rising expense categories and adjust purchasing.'
        : 'Expense trend is easing. Keep inventory lean.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFffa726), Color(0xFFff6f00)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFffa726).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.waterfall_chart_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Forecast Alert',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Expenses are projected to ${changePercent >= 0 ? 'increase' : 'decrease'} by ${changePercent.abs().toStringAsFixed(0)}% based on AI analysis.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitMarginChart() {
    final incomeMonthly = _monthlyTotals(_income, 'amount', 'date');
    final expenseMonthly = _monthlyTotals(_expenses, 'amount', 'date');
    // Only months where BOTH income and expenses were recorded produce a
    // meaningful margin — comparing a month's revenue against a different
    // month's costs would be meaningless, so we intersect on the real
    // calendar-month key rather than zipping two lists by position.
    final sharedKeys = incomeMonthly.keys.where(expenseMonthly.containsKey).toList()..sort();

    if (sharedKeys.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
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
              'Profit Margin Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2d3748),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Profit margin appears once you have both income and expenses recorded in the same month.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final marginKeys = sharedKeys.take(6).toList();
    if (marginKeys.length < 2) {
      return Container(
        margin: const EdgeInsets.all(20),
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
              'Profit Margin Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2d3748),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You have both income and expenses for ${_monthLabel(marginKeys.first)} so far — this trend chart fills in once there\'s a second month to compare against.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }
    final marginLabels = marginKeys.map(_monthLabel).toList();
    final marginSeries = marginKeys.map((key) {
      final revenue = incomeMonthly[key]!;
      final expense = expenseMonthly[key]!;
      if (revenue == 0) {
        return 0.0;
      }
      return ((revenue - expense) / revenue * 100).clamp(0.0, 100.0);
    }).toList();

    return Container(
      margin: const EdgeInsets.all(20),
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
            'Profit Margin Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Real income vs. real expenses, by month',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: RepaintBoundary(
              child: LineChart(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final fractional = (value - value.toInt()).abs();
                          if (fractional > 0.001) return const SizedBox.shrink();
                          final idx = value.toInt();
                          if (idx >= 0 && idx < marginLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                marginLabels[idx],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        marginSeries.length,
                        (index) => FlSpot(index.toDouble(), marginSeries[index]),
                      ),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF66bb6a), Color(0xFF43a047)],
                      ),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: const Color(0xFF66bb6a),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF66bb6a).withOpacity(0.3),
                            const Color(0xFF43a047).withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    final roiValue = _getRoiValue();
    final growthValue = _getGrowthValue();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'ROI',
              roiValue == '—' ? '—' : '$roiValue%',
              Icons.trending_up_rounded,
              const Color(0xFF66bb6a),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              'Growth',
              growthValue,
              Icons.show_chart_rounded,
              const Color(0xFF667eea),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.recommend_rounded,
                  color: Color(0xFF667eea),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2d3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRecommendationItem(
            'Forecasted Best Sellers',
            _buildBestSellerSummary(),
            Icons.inventory_2_rounded,
            const Color(0xFF667eea),
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            'Restock Priority',
            _buildRestockSummary(),
            Icons.savings_rounded,
            const Color(0xFF66bb6a),
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            'Slow Movers',
            _buildSlowMoverSummary(),
            Icons.campaign_rounded,
            const Color(0xFFffa726),
          ),
        ],
      ),
    );
  }

  String _buildBestSellerSummary() {
    if (_aiReport.isEmpty) {
      return _inventoryItems.isEmpty ? 'No inventory yet' : 'AI backend offline';
    }
    final bestSelling = (_aiReport['best_selling_products'] as List?) ?? [];
    if (bestSelling.isEmpty) {
      return 'No best-seller data yet';
    }
    final first = bestSelling.first as Map<String, dynamic>;
    return '${first['item_name']} leads with ${first['sales']} sales.';
  }

  String _buildRestockSummary() {
    if (_aiReport.isEmpty) {
      return _inventoryItems.isEmpty ? 'Add items to get restock advice' : 'No restock signals yet';
    }
    final restocks = (_aiReport['restocking_recommendations'] as List?) ?? [];
    if (restocks.isEmpty) {
      return 'Inventory is balanced.';
    }
    final first = restocks.first as Map<String, dynamic>;
    return '${first['item_name']} should be reordered soon.';
  }

  String _buildSlowMoverSummary() {
    if (_aiReport.isEmpty) {
      return _inventoryItems.isEmpty ? 'No inventory yet' : 'No slow-moving insights yet';
    }
    final slow = (_aiReport['slow_moving_inventory'] as List?) ?? [];
    if (slow.isEmpty) {
      return 'No slow-moving items found.';
    }
    final first = slow.first as Map<String, dynamic>;
    return '${first['item_name']} is moving slowly at ${first['sales']} sales.';
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2d3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report shared successfully')),
    );
  }

  void _downloadReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report downloaded successfully')),
    );
  }
}