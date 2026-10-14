import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'inventory_screen.dart';
import 'expense_screen.dart';
import 'income_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'add_item_screen.dart';
import 'add_expense_screen.dart';
import 'sell_item_screen.dart';
import 'notification_screen.dart';
import 'barcode_scanner_screen.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabSelected;
  const HomeScreen({super.key, this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardController;
  late AnimationController _pulseController;
  late AnimationController _chartController;

  int _selectedPeriod = 0;
  bool _isRefreshing = false;
  bool _isLoadingData = true;
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _income = [];
  final NumberFormat _currencyFormat = NumberFormat('#,##0');
  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _expensesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _incomeSubscription;

  double _safeNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Map<String, dynamic> _getStatsForPeriod() {
    final totalItems = _inventoryItems.length;
    final lowStock = _inventoryItems.where((item) {
      final quantity = _safeNumber(item['quantity']);
      final threshold = _safeNumber(item['lowStockThreshold']);
      return quantity < threshold;
    }).length;

    final totalExpenses = _expenses.fold<double>(0, (sum, expense) {
      return sum + _safeNumber(expense['amount']);
    });

    final inventoryValue = _inventoryItems.fold<double>(0, (sum, item) {
      final quantity = _safeNumber(item['quantity']);
      final price = _safeNumber(item['price']);
      return sum + (quantity * price);
    });

    final totalIncome = _income.fold<double>(0, (sum, entry) {
      return sum + _safeNumber(entry['amount']);
    });

    final chartSpots = _buildDailySpots(_expenses, 'amount', 'date');
    final incomeSpots = _buildDailySpots(_income, 'amount', 'date');
    final hasChartData = chartSpots.any((spot) => spot.y > 0) || incomeSpots.any((spot) => spot.y > 0);

    String expenseChange = 'No data';
    if (chartSpots.any((s) => s.y > 0) && chartSpots.length >= 2) {
      final first = chartSpots.first.y;
      final last = chartSpots.last.y;
      if (first > 0) {
        final percent = ((last - first) / first * 100).round();
        expenseChange = '${percent >= 0 ? '+' : ''}$percent%';
      } else if (last > 0) {
        expenseChange = 'New activity';
      } else {
        expenseChange = 'No change';
      }
    }

    return {
      'totalItems': totalItems,
      'lowStock': lowStock,
      'expenses': totalExpenses,
      'inventoryValue': inventoryValue,
      'totalIncome': totalIncome,
      'expenseChange': expenseChange,
      'hasChartData': hasChartData,
      'chartSpots': chartSpots,
      'incomeSpots': incomeSpots,
    };
  }

  List<FlSpot> _buildDailySpots(List<Map<String, dynamic>> records, String amountKey, String dateKey) {
    final now = DateTime.now();
    final Map<String, double> dailyTotals = {};

    for (final record in records) {
      final dateValue = record[dateKey];
      DateTime? recordDate;
      if (dateValue is DateTime) {
        recordDate = dateValue;
      } else if (dateValue is String) {
        recordDate = DateTime.tryParse(dateValue);
      }

      if (recordDate == null) continue;

      final normalizedDay = DateTime(recordDate.year, recordDate.month, recordDate.day);
      final key = '${normalizedDay.year}-${normalizedDay.month}-${normalizedDay.day}';
      dailyTotals[key] = (dailyTotals[key] ?? 0) + _safeNumber(record[amountKey]);
    }

    final spots = <FlSpot>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final key = '${day.year}-${day.month}-${day.day}';
      spots.add(FlSpot((6 - i).toDouble(), dailyTotals[key] ?? 0));
    }

    return spots;
  }
  String _getBusinessHealth() {
    final stats = _getStatsForPeriod();
    final lowStockCount = stats['lowStock'] as int;
    final totalExpenses = stats['expenses'] as double;
    final inventoryValue = stats['inventoryValue'] as double;

    if (lowStockCount == 0 && totalExpenses > 0 && inventoryValue > totalExpenses) {
      return 'good';
    }
    if (lowStockCount >= 3 || (totalExpenses > 0 && inventoryValue < totalExpenses * 0.5)) {
      return 'bad';
    }
    return 'neutral';
  }


  void _pushWithTransition(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _chartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _inventorySubscription = DatabaseService.streamItems().listen((items) {
      if (!mounted) return;
      setState(() => _inventoryItems = items);
    });
    _expensesSubscription = DatabaseService.streamExpenses().listen((expenses) {
      if (!mounted) return;
      setState(() => _expenses = expenses);
    });
    _incomeSubscription = DatabaseService.streamIncome().listen((income) {
      if (!mounted) return;
      setState(() => _income = income);
    });
    _loadDashboardData();
    _startAnimations();
  }

  Future<void> _loadDashboardData() async {
    final items = await DatabaseService.getItems();
    final expenses = await DatabaseService.getExpenses();
    final income = await DatabaseService.getIncome();
    if (!mounted) return;

    setState(() {
      _inventoryItems = items;
      _expenses = expenses;
      _income = income;
      _isLoadingData = false;
    });
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () { if (mounted) _headerController.forward(); });
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _cardController.forward(); });
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _chartController.forward(); });
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _expensesSubscription?.cancel();
    _incomeSubscription?.cancel();
    _headerController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    _headerController.reset();
    _cardController.reset();
    _chartController.reset();
    await Future.delayed(const Duration(milliseconds: 500));
    _startAnimations();
    setState(() => _isRefreshing = false);
  }

  void _showAddBottomSheet() {
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
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Add New', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _buildAddOption(
              'Sell Item',
              Icons.point_of_sale_rounded,
              const Color(0xFFf5576c),
                  () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SellItemScreen()),
                ).then((result) {
                  if (result == true) {
                    _handleRefresh();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _buildAddOption(
              'Add Inventory Item',
              Icons.add_box_rounded,
              const Color(0xFF667eea),
                  () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddItemScreen()),
                ).then((result) {
                  if (result != null) {
                    // Handle returned item if needed (e.g., refresh list)
                    _handleRefresh();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _buildAddOption(
              'Add Expense',
              Icons.receipt_long_rounded,
              const Color(0xFFffa726),
                  () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                ).then((result) {
                  if (result != null) {
                    _handleRefresh();
                  }
                });
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (_isLoadingData) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Color(0xFF667eea)),
              SizedBox(height: 16),
              Text('Loading dashboard data...'),
            ],
          ),
        ),
      );
    }

    final stats = _getStatsForPeriod();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea).withOpacity(0.1),
              const Color(0xFF764ba2).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF667eea),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAnimatedAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildWelcomeBanner(),
                    _buildPeriodSelector(),
                    _buildStatsGrid(stats),
                    _buildTrendChart(
                      stats['incomeSpots'] as List<FlSpot>,
                      stats['chartSpots'] as List<FlSpot>,
                      stats['hasChartData'] as bool,
                    ),
                    _buildQuickActionsCarousel(),
                    _buildActivityTimeline(),
                    _buildAIInsightsCard(),
                    SizedBox(height: screenHeight * 0.1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAnimatedAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
            CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeTransition(
                                opacity: _headerController,
                                child: const Text(
                                  'Dashboard',
                                  style: TextStyle(
                                    color: Colors.white, fontSize: 28,
                                    fontWeight: FontWeight.w800, letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                                  CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('EEE, MMM d').format(DateTime.now()),
                                        style: const TextStyle(
                                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 6),
                            _buildHeaderIconButton(Icons.notifications_none_rounded, 'Notifications', () {
                              Navigator.of(context).push(PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const NotificationScreen(),
                                transitionsBuilder: (_, animation, __, child) {
                                  return SlideTransition(
                                    position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                        .chain(CurveTween(curve: Curves.easeOutCubic))
                                        .animate(animation),
                                    child: child,
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ));
                            }),
                            const SizedBox(width: 8),
                            _buildProfileAvatar(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton(IconData icon, String label, VoidCallback onTap) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
      ),
      child: GestureDetector(
        // Inside HomeScreen, replace the profile avatar's onTap with:
          onTap: () {
            _pushWithTransition(const ProfileScreen());
          },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.orange, Colors.pink]),
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF667eea), size: 22),
              ),
            ),
            Positioned(
              right: 0, bottom: 0,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(_pulseController.value * 0.5),
                        blurRadius: 6,
                        spreadRadius: _pulseController.value * 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
  final health = _getBusinessHealth();
  final stats = _getStatsForPeriod();
  final message = _getBannerMessage(health, stats);
  final trendText = _getBannerTrendText(health, stats);
  final trendIcon = _getBannerTrendIcon(health);

  Map<String, dynamic> config;
  switch (health) {
    case 'good':
      config = {
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
        ),
        'shadowColor': const Color(0xFF00b09b),
        'message': message,
        'trendText': trendText,
        'trendIcon': trendIcon,
      };
      break;
    case 'bad':
      config = {
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFe43a15), Color(0xFFe65245)],
        ),
        'shadowColor': const Color(0xFFe43a15),
        'message': message,
        'trendText': trendText,
        'trendIcon': trendIcon,
      };
      break;
    default:
      config = {
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFf5af19), Color(0xFFf12711)],
        ),
        'shadowColor': const Color(0xFFf5af19),
        'message': message,
        'trendText': trendText,
        'trendIcon': trendIcon,
      };
      break;
  }

  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    ),
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: config['gradient'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (config['shadowColor'] as Color).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👋 ${_getGreeting()}!',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(config['message'],
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(config['trendIcon'], color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(config['trendText'],
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (_, value, __) => Transform.scale(
              scale: value,
              child: Transform.rotate(
                angle: (1 - value) * math.pi * 2,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    health == 'good' ? Icons.emoji_emotions_rounded :
                    health == 'bad' ? Icons.warning_rounded : Icons.insights_rounded,
                    color: Colors.white, size: 36,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodTab('Today', 0),
          _buildPeriodTab('Week', 1),
          _buildPeriodTab('Month', 2),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, int index) {
    bool isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = index);
          _chartController.reset();
          _chartController.forward();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final items = [
      {
        'title': 'Total Items', 'value': stats['totalItems'].toString(),
        'icon': Icons.inventory_2_rounded, 'color': const Color(0xFF667eea),
        'change': '${stats['totalItems']} tracked', 'positive': true, 'route': const InventoryScreen(),
      },
      {
        'title': 'Low Stock', 'value': stats['lowStock'].toString(),
        'icon': Icons.warning_rounded, 'color': const Color(0xFFf5576c),
        'change': stats['lowStock'] > 0 ? '${stats['lowStock']} critical' : 'All stocked',
        'positive': stats['lowStock'] == 0,
        'route': const InventoryScreen(),
      },
      {
        'title': 'Expenses', 'value': stats['expenses'].toString(),
        'icon': Icons.payment_rounded, 'color': const Color(0xFFffa726),
        'change': stats['expenseChange'], 'positive': false, 'route': const ExpenseScreen(),
      },
      {
        'title': 'Income', 'value': stats['totalIncome'].toString(),
        'icon': Icons.trending_up_rounded, 'color': const Color(0xFF43a047),
        'change': (stats['totalIncome'] as double) > 0 ? 'From sales' : 'No income yet',
        'positive': true,
        'route': const IncomeScreen(),
      },
      {
        'title': 'Inventory Value', 'value': stats['inventoryValue'].toString(),
        'icon': Icons.attach_money_rounded, 'color': const Color(0xFF66bb6a),
        'change': (stats['inventoryValue'] as double) > 0 ? 'Current stock value' : 'No value',
        'positive': true,
        'route': const ReportsScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildStatCard(
            item['title'] as String,
            item['value'] as String,
            item['icon'] as IconData,
            item['color'] as Color,
            item['change'] as String,
            item['positive'] as bool,
            index,
            item['route'] as Widget,
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      String change, bool isPositive, int index, Widget destination) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.5 + (index * 0.1)), end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _cardController,
        curve: Interval(index * 0.1, 0.6 + (index * 0.1), curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: _cardController,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Widget dest = destination;
              if (dest is ReportsScreen) {
                dest = ReportsScreen(health: _getBusinessHealth());
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          change,
                          style: TextStyle(
                            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 10, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: double.tryParse(value) ?? 0),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (_, val, __) {
                          String displayValue;
                          if (title.contains('Expenses') || title.contains('Value') || title.contains('Income')) {
                            displayValue = 'PKR ${_currencyFormat.format(val)}';
                          } else {
                            displayValue = _currencyFormat.format(val.round());
                          }
                          return Text(
                            displayValue,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey.shade800),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(List<FlSpot> incomeSpots, List<FlSpot> expenseSpots, bool hasData) {
    final maxIncome = incomeSpots.isEmpty ? 0.0 : incomeSpots.map((s) => s.y).reduce(math.max);
    final maxExpense = expenseSpots.isEmpty ? 0.0 : expenseSpots.map((s) => s.y).reduce(math.max);
    final maxValue = math.max(maxIncome, maxExpense);
    final maxY = maxValue > 0 ? maxValue * 1.25 : 10.0;

    final totalIncomeWeek = incomeSpots.fold<double>(0, (sum, s) => sum + s.y);
    final totalExpenseWeek = expenseSpots.fold<double>(0, (sum, s) => sum + s.y);

    return FadeTransition(
      opacity: _chartController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _chartController, curve: Curves.easeOutCubic),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Business Activity',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2d3748))),
                      const SizedBox(height: 3),
                      Text('Last 7 days · income vs expenses', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  if (hasData)
                    Row(
                      children: [
                        _buildLegendDot(const Color(0xFF43a047), 'Income'),
                        const SizedBox(width: 10),
                        _buildLegendDot(const Color(0xFFffa726), 'Expense'),
                      ],
                    ),
                ],
              ),
              if (hasData) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'PKR ${totalIncomeWeek.toStringAsFixed(0)} in',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF43a047)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'PKR ${totalExpenseWeek.toStringAsFixed(0)} out',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFffa726)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: hasData
                    ? RepaintBoundary(
                        child: LineChart(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxY / 4,
                              getDrawingHorizontalLine: (_) =>
                                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, _) {
                                    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                    final fractional = (value - value.toInt()).abs();
                                    if (fractional > 0.001) return const SizedBox.shrink();
                                    final idx = value.toInt();
                                    if (idx >= 0 && idx < days.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          days[idx],
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  reservedSize: 24,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: 6,
                            minY: 0,
                            maxY: maxY,
                            lineBarsData: [
                              LineChartBarData(
                                spots: incomeSpots,
                                isCurved: true,
                                color: const Color(0xFF43a047),
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                                    radius: 5,
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                    strokeColor: const Color(0xFF43a047),
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF43a047).withOpacity(0.25),
                                      const Color(0xFF43a047).withOpacity(0.02),
                                    ],
                                  ),
                                ),
                              ),
                              LineChartBarData(
                                spots: expenseSpots,
                                isCurved: true,
                                color: const Color(0xFFffa726),
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                                    radius: 5,
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                    strokeColor: const Color(0xFFffa726),
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFFffa726).withOpacity(0.2),
                                      const Color(0xFFffa726).withOpacity(0.02),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          'No activity yet this week.\nAdd an expense or sell an item to see it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickActionsCarousel() {
    final actions = [
      {
        'title': 'Add Item', 'icon': Icons.add_box_rounded,
        'color': const Color(0xFF667eea), 'screen': const AddItemScreen(), 'action': null,
      },
      {
        'title': 'Add Expense', 'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFFffa726), 'screen': const AddExpenseScreen(), 'action': null,
      },
      {
        'title': 'Income', 'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF43a047), 'screen': const IncomeScreen(), 'action': null,
      },
      {
        'title': 'Sell Item', 'icon': Icons.point_of_sale_rounded,
        'color': const Color(0xFFf5576c), 'screen': const SellItemScreen(), 'action': null,
      },
      {
        'title': 'AI Report', 'icon': Icons.analytics_rounded,
        'color': const Color(0xFF764ba2), 'screen': const ReportsScreen(), 'action': null,
      },
      {
        'title': 'Export', 'icon': Icons.cloud_download_rounded,
        'color': const Color(0xFF66bb6a), 'screen': null, 'action': _showExportSheet,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2d3748))),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0.3 + (index * 0.1), 0), end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _cardController,
                  curve: Interval(index * 0.15, 0.5 + (index * 0.15), curve: Curves.easeOutCubic),
                )),
                child: _buildActionCard(
                  action['title'] as String,
                  action['icon'] as IconData,
                  action['color'] as Color,
                  action['screen'] as Widget?,
                  action['action'] as VoidCallback?,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, Widget? screen, VoidCallback? customAction) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (customAction != null) {
              customAction();
            } else if (screen != null) {
              Widget dest = screen;
              if (dest is ReportsScreen) {
                dest = ReportsScreen(health: _getBusinessHealth());
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => dest))
                  .then((result) {
                if (result != null) _handleRefresh();
              });
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 6),
                Text(title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.file_present_rounded, color: Color(0xFF66bb6a)),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Exporting Excel...')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFf5576c)),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Exporting PDF...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimeline() {
    final activities = _buildRecentActivities();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2d3748))),
              TextButton(
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  children: [
                    Text('See All',
                        style: TextStyle(color: Color(0xFF667eea), fontWeight: FontWeight.w600, fontSize: 12)),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF667eea)),
                  ],
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(
                CurvedAnimation(
                  parent: _cardController,
                  curve: Interval(0.4 + (index * 0.1), 0.7 + (index * 0.1), curve: Curves.easeOutCubic),
                ),
              ),
              child: _buildActivityItem(
                activity['title'] as String,
                activity['time'] as String,
                activity['icon'] as IconData,
                activity['color'] as Color,
                activity['route'] as Widget,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color, Widget destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2d3748)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIInsightsCard() {
    final insights = _buildAiInsights();

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _chartController, curve: Curves.easeOutCubic),
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('AI Insights',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, size: 6, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Live', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => _buildInsightItem(insight)).toList(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(health: _getBusinessHealth()))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF667eea),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Full Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBannerMessage(String health, Map<String, dynamic> stats) {
    final lowStock = stats['lowStock'] as int;
    if (health == 'good') return 'Inventory looks healthy and spending is under control.';
    if (health == 'bad') return 'Low stock and rising costs need attention.';
    if (lowStock > 0) return '$lowStock items need restocking soon.';
    return 'Business is steady and your stock is balanced.';
  }

  String _getBannerTrendText(String health, Map<String, dynamic> stats) {
    final lowStock = stats['lowStock'] as int;
    if (health == 'good') return '${stats['totalItems']} items tracked';
    if (health == 'bad') return 'Needs attention';
    if (lowStock > 0) return '$lowStock low stock';
    return 'Balanced stock';
  }

  IconData _getBannerTrendIcon(String health) {
    if (health == 'good') return Icons.trending_up;
    if (health == 'bad') return Icons.trending_down;
    return Icons.trending_flat;
  }

  List<Map<String, dynamic>> _buildRecentActivities() {
    final activities = <Map<String, dynamic>>[];

    for (final item in _inventoryItems.take(2)) {
      activities.add({
        'title': 'Added ${item['name'] ?? 'item'} (${item['quantity'] ?? 0} in stock)',
        'time': 'Just now',
        'icon': Icons.add_circle_rounded,
        'color': const Color(0xFF66bb6a),
        'route': const InventoryScreen(),
      });
    }

    for (final expense in _expenses.take(2)) {
      activities.add({
        'title': 'Expense: ${expense['category'] ?? 'general'}',
        'time': 'Recorded',
        'icon': Icons.receipt_rounded,
        'color': const Color(0xFFffa726),
        'route': const ExpenseScreen(),
      });
    }

    final lowStockItems = _inventoryItems.where((item) {
      final quantity = _safeNumber(item['quantity']);
      final threshold = _safeNumber(item['lowStockThreshold']);
      return quantity < threshold;
    }).toList();

    if (lowStockItems.isNotEmpty) {
      final item = lowStockItems.first;
      activities.add({
        'title': 'Low stock alert - ${item['name'] ?? 'item'}',
        'time': 'Needs review',
        'icon': Icons.warning_rounded,
        'color': const Color(0xFFf5576c),
        'route': const InventoryScreen(),
      });
    }

    return activities.take(4).toList();
  }

  List<String> _buildAiInsights() {
    final insights = <String>[];
    final stats = _getStatsForPeriod();
    final lowStock = stats['lowStock'] as int;
    final totalExpenses = stats['expenses'] as double;
    final inventoryValue = stats['inventoryValue'] as double;

    if (lowStock > 0) {
      insights.add('📦 $lowStock items need restocking soon.');
    }

    if (totalExpenses > 0) {
      insights.add('💸 Total expenses are ${totalExpenses.toStringAsFixed(0)}.');
    }

    if (inventoryValue > 0) {
      insights.add('📈 Inventory value is ${inventoryValue.toStringAsFixed(0)}.');
    }

    if (insights.isEmpty) {
      insights.add('📊 No insights available yet.');
    }

    return insights.take(3).toList();
  }

  Widget _buildInsightItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
          ),
        ],
      ),
    );
  }

  void _showScanBottomSheet() {
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
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Scan Product Barcode', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _buildScanOption(
              'Scan to Add Item',
              'Register a new item in inventory',
              Icons.qr_code_scanner_rounded,
              const Color(0xFF667eea),
              () {
                Navigator.pop(context);
                _navigateToScanner('add');
              },
            ),
            const SizedBox(height: 12),
            _buildScanOption(
              'Scan to Sell Item',
              'Sell an item and decrease stock',
              Icons.point_of_sale_rounded,
              const Color(0xFFffa726),
              () {
                Navigator.pop(context);
                _navigateToScanner('sell');
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _navigateToScanner(String mode) async {
    final dynamic result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(scanMode: mode),
      ),
    );

    if (result == null) return;

    // Extract barcode from result (either String for backward compatibility or Map with barcode key)
    final String barcode = result is Map ? result['barcode'] as String : result as String;

    if (barcode.isEmpty) return;

    if (mode == 'add') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddItemScreen(barcode: barcode),
        ),
      ).then((_) => _handleRefresh());
    } else {
      _sellItemByBarcode(barcode);
    }
  }

  void _sellItemByBarcode(String barcode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF667eea)),
      ),
    );

    final items = await DatabaseService.getItems();
    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading

    final itemIndex = items.indexWhere((i) => i['barcode'] == barcode);

    if (itemIndex != -1) {
      final item = Map<String, dynamic>.from(items[itemIndex]);
      final int qty = item['quantity'] as int;

      if (qty > 0) {
        item['quantity'] = qty - 1;
        item['lastUpdated'] = DateTime.now();

        await DatabaseService.updateItem(item).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('Sell (barcode) timed out waiting for server confirmation. '
                'Data is already in the local cache and will sync automatically.');
          },
        );

        // Record this sale as income so barcode sales show up in the Income
        // screen and dashboard, instead of only ever reducing stock silently.
        final double saleAmount = (item['price'] as double);
        final Map<String, dynamic> incomeEntry = {
          'id': '${DateTime.now().millisecondsSinceEpoch}_sale',
          'title': 'Sale: ${item['name']} x1',
          'amount': saleAmount,
          'category': 'Sales',
          'icon': '💰',
          'colorHex': 'FF66bb6a',
          'date': DateTime.now(),
          'notes': 'Auto-recorded from inventory sale',
        };
        try {
          await DatabaseService.addIncome(incomeEntry).timeout(
            const Duration(seconds: 8),
            onTimeout: () {},
          );
        } catch (e) {
          debugPrint('Failed to record income for barcode sale: $e');
        }

        if (!mounted) return;
        _handleRefresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sold 1 unit of ${item['name']}. Stock left: ${qty - 1}',
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item['name']} is out of stock!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Barcode $barcode not found in inventory.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: _showScanBottomSheet,
          borderRadius: BorderRadius.circular(25),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('Scan Code',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}