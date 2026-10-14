import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {    
  late AnimationController _headerController;
  late AnimationController _listController;

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Alerts', 'Updates', 'Expenses'];

  // Dummy notifications
  final List<Map<String, dynamic>> _allNotifications = [
    {
      'id': '1',
      'type': 'alert',
      'title': 'Low Stock Alert',
      'message': 'Product "Dell XPS Laptop" is running low. Only 3 units remaining.',
      'time': DateTime.now().subtract(const Duration(minutes: 15)),
      'icon': Icons.warning_rounded,
      'color': Color(0xFFf5576c),
      'isRead': false,
    },
    {
      'id': '2',
      'type': 'expense',
      'title': 'Expense Added',
      'message': 'Office Supplies purchase of PKR 245.00 was recorded successfully.',
      'time': DateTime.now().subtract(const Duration(hours: 1)),
      'icon': Icons.receipt_long_rounded,
      'color': Color(0xFFffa726),
      'isRead': false,
    },
    {
      'id': '3',
      'type': 'update',
      'title': 'Inventory Updated',
      'message': '50 units of "Wireless Mouse" were added to inventory.',
      'time': DateTime.now().subtract(const Duration(hours: 3)),
      'icon': Icons.inventory_2_rounded,
      'color': Color(0xFF667eea),
      'isRead': false,
    },
    {
      'id': '4',
      'type': 'alert',
      'title': 'Critical Stock Alert',
      'message': 'Product "USB-C Hub" has 0 units. Please restock immediately.',
      'time': DateTime.now().subtract(const Duration(hours: 5)),
      'icon': Icons.error_rounded,
      'color': Color(0xFFf5576c),
      'isRead': true,
    },
    {
      'id': '5',
      'type': 'update',
      'title': 'Item Deleted',
      'message': '"Old Keyboard Model" was removed from inventory.',
      'time': DateTime.now().subtract(const Duration(hours: 8)),
      'icon': Icons.delete_rounded,
      'color': Color(0xFF764ba2),
      'isRead': true,
    },
    {
      'id': '6',
      'type': 'expense',
      'title': 'Monthly Summary',
      'message': 'Total expenses this month: PKR 1,250.00. Up 15% from last month.',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'icon': Icons.bar_chart_rounded,
      'color': Color(0xFF66bb6a),
      'isRead': true,
    },
    {
      'id': '7',
      'type': 'alert',
      'title': 'Low Stock Alert',
      'message': '"Office Chair" stock is below threshold. 2 units remaining.',
      'time': DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      'icon': Icons.warning_rounded,
      'color': Color(0xFFffa726),
      'isRead': true,
    },
    {
      'id': '8',
      'type': 'update',
      'title': 'Price Updated',
      'message': 'Unit price for "Monitor 27 inch" updated from PKR 350 to PKR 320.',
      'time': DateTime.now().subtract(const Duration(days: 2)),
      'icon': Icons.edit_rounded,
      'color': Color(0xFF42a5f5),
      'isRead': true,
    },
    {
      'id': '9',
      'type': 'expense',
      'title': 'Expense Deleted',
      'message': 'Duplicate transport expense of PKR 80.00 was removed.',
      'time': DateTime.now().subtract(const Duration(days: 3)),
      'icon': Icons.delete_sweep_rounded,
      'color': Color(0xFFec407a),
      'isRead': true,
    },
    {
      'id': '10',
      'type': 'update',
      'title': 'Bulk Import Done',
      'message': '120 items were successfully imported into inventory.',
      'time': DateTime.now().subtract(const Duration(days: 5)),
      'icon': Icons.cloud_done_rounded,
      'color': Color(0xFF26a69a),
      'isRead': true,
    },
  ];

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _allNotifications;
    final filterMap = {
      'Alerts': 'alert',
      'Updates': 'update',
      'Expenses': 'expense',
    };
    return _allNotifications
        .where((n) => n['type'] == filterMap[_selectedFilter])
        .toList();
  }

  int get _unreadCount =>
      _allNotifications.where((n) => !(n['isRead'] as bool)).length;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _markAllRead() {
    setState(() {
      for (final n in _allNotifications) {
        n['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All notifications marked as read'),
        backgroundColor: const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _markRead(String id) {
    setState(() {
      final n = _allNotifications.firstWhere((n) => n['id'] == id);
      n['isRead'] = true;
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      _allNotifications.removeWhere((n) => n['id'] == id);
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _allNotifications.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All notifications cleared'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _filteredNotifications;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildFilterTabs()),
          SliverToBoxAdapter(
            child: notifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationList(notifications),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
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
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_unreadCount > 0)
          TextButton.icon(
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded,
                color: Colors.white, size: 18),
            label: const Text(
              'Mark all read',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_sweep_rounded,
                color: Colors.white, size: 20),
          ),
          onPressed: _allNotifications.isEmpty ? null : _clearAll,
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          )),
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
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FadeTransition(
                        opacity: _headerController,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _unreadCount > 0
                                  ? '$_unreadCount unread notification${_unreadCount > 1 ? 's' : ''}'
                                  : 'All caught up!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Unread badge
                    if (_unreadCount > 0)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(
                              parent: _headerController,
                              curve: Curves.elasticOut),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_unreadCount new',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)])
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  filter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final n in notifications) {
      final time = n['time'] as DateTime;
      final now = DateTime.now();
      String label;
      if (now.difference(time).inHours < 24 &&
          time.day == now.day) {
        label = 'Today';
      } else if (now.difference(time).inDays <= 1 &&
          time.day == now.subtract(const Duration(days: 1)).day) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMMM d, yyyy').format(time);
      }
      grouped.putIfAbsent(label, () => []).add(n);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Divider(color: Colors.grey.shade200, height: 1),
                    ),
                  ],
                ),
              ),
              ...entry.value.asMap().entries.map((e) {
                final index = e.key;
                final notification = e.value;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _listController,
                    curve: Interval(
                      (index * 0.05).clamp(0.0, 0.9),
                      ((index * 0.05) + 0.4).clamp(0.0, 1.0),
                      curve: Curves.easeOutCubic,
                    ),
                  )),
                  child: FadeTransition(
                    opacity: _listController,
                    child: _buildNotificationCard(notification),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] as bool;
    final color = notification['color'] as Color;

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification['id']),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _markRead(notification['id']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? Colors.transparent : color.withOpacity(0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isRead ? 0.03 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notification['icon'] as IconData,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: const Color(0xFF2d3748),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification['time'] as DateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['message'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead
                            ? Colors.grey.shade500
                            : Colors.grey.shade700,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Unread dot
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (_, value, __) => Transform.scale(
              scale: value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withOpacity(0.15),
                      const Color(0xFF764ba2).withOpacity(0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.notifications_off_rounded,
                    size: 48,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'You\'re all caught up!\nNo notifications at the moment.'
                : 'No ${_selectedFilter.toLowerCase()} notifications found.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}