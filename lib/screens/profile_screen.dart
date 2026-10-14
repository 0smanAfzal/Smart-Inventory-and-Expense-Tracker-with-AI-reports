import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isRoot;
  const ProfileScreen({super.key, this.isRoot = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _listController;

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _biometricEnabled = true;

  // ==================== REAL STATS STATE ====================
  bool _statsLoading = true;
  int _itemCount = 0;
  double _totalExpenses = 0;
  double _totalIncome = 0;
  final NumberFormat _currencyFormat = NumberFormat('#,##0');

  final List<Map<String, dynamic>> _settingsSections = [
    {
      'title': 'Account Settings',
      'items': [
        {'title': 'Edit Profile', 'subtitle': 'Update your personal information', 'icon': Icons.person_outline_rounded, 'color': Color(0xFF667eea), 'action': 'editProfile'},
        {'title': 'Change Password', 'subtitle': 'Update your password', 'icon': Icons.lock_outline_rounded, 'color': Color(0xFFffa726), 'action': 'changePassword'},
        {'title': 'Business Details', 'subtitle': 'Manage your business information', 'icon': Icons.business_rounded, 'color': Color(0xFF66bb6a), 'action': 'businessDetails'},
      ],
    },
    {
      'title': 'Data & Storage',
      'items': [
        {'title': 'Export Data', 'subtitle': 'Download your data as Excel/PDF', 'icon': Icons.download_rounded, 'color': Color(0xFF667eea), 'action': 'exportData'},
        {'title': 'Backup & Restore', 'subtitle': 'Backup your data to cloud', 'icon': Icons.cloud_upload_rounded, 'color': Color(0xFF42a5f5), 'action': 'backupRestore'},
        {'title': 'Clear Cache', 'subtitle': 'Free up storage space', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFFffa726), 'action': 'clearCache'},
      ],
    },
    {
      'title': 'Support & Legal',
      'items': [
        {'title': 'Help Center', 'subtitle': 'Get help and support', 'icon': Icons.help_outline_rounded, 'color': Color(0xFF667eea), 'action': 'helpCenter'},
        {'title': 'Privacy Policy', 'subtitle': 'Read our privacy policy', 'icon': Icons.privacy_tip_outlined, 'color': Color(0xFF66bb6a), 'action': 'privacyPolicy'},
        {'title': 'Terms of Service', 'subtitle': 'View terms and conditions', 'icon': Icons.description_outlined, 'color': Color(0xFF764ba2), 'action': 'termsOfService'},
        {'title': 'About', 'subtitle': 'Version 1.0.0', 'icon': Icons.info_outline_rounded, 'color': Color(0xFF42a5f5), 'action': 'about'},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _listController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();

    // Read dark mode state from provider
    _darkModeEnabled = Provider.of<ThemeProvider>(context, listen: false).isDark;

    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final items = await DatabaseService.getItems();
      final expenses = await DatabaseService.getExpenses();
      final income = await DatabaseService.getIncome();

      if (!mounted) return;

      final totalExpenses = expenses.fold<double>(0, (sum, e) {
        final amount = e['amount'];
        return sum + (amount is num ? amount.toDouble() : 0.0);
      });
      final totalIncome = income.fold<double>(0, (sum, i) {
        final amount = i['amount'];
        return sum + (amount is num ? amount.toDouble() : 0.0);
      });

      setState(() {
        _itemCount = items.length;
        _totalExpenses = totalExpenses;
        _totalIncome = totalIncome;
        _statsLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load profile stats: $e');
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Sync dark mode state
    _darkModeEnabled = themeProvider.isDark;

    // Pull real colors from the app's actual ColorScheme instead of hand-rolled
    // grey shades — this is what was making dark mode look inconsistent: every
    // other widget in the app (dialogs, snackbars, etc.) follows this scheme
    // automatically, but this screen was fighting it with flat grey.shade800/900.
    final scheme = Theme.of(context).colorScheme;

    final bool showBack = !widget.isRoot;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAnimatedAppBar(showBack),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileCard(authProvider),
                _buildStatsRow(),
                const SizedBox(height: 8),
                _buildPreferencesSection(themeProvider),
                ..._buildSettingsSections(),
                const SizedBox(height: 16),
                _buildLogoutButton(authProvider),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ANIMATED APP BAR ====================
  Widget _buildAnimatedAppBar(bool showBack) {
    return SliverAppBar(
      expandedHeight: showBack ? 150 : 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
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
        background: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
            CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Slightly deeper gradient in dark mode so the transition into
                // the dark scaffold body doesn't feel like a jarring brightness
                // spike.
                colors: _darkModeEnabled
                    ? const [Color(0xFF4b5aa8), Color(0xFF573f82)]
                    : const [Color(0xFF667eea), Color(0xFF764ba2)],
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
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage your account',
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
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  // ==================== PROFILE CARD ====================
  Widget _buildProfileCard(AuthProvider authProvider) {
    final userName = authProvider.displayName;
    final userEmail = authProvider.displayEmail;
    final userPhoto = authProvider.displayPhoto;

    return FadeTransition(
      opacity: _headerController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
        ),
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(_darkModeEnabled ? 0.2 : 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.orange, Colors.pink]),
                    ),
                    child: userPhoto.isNotEmpty
                        ? CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage(userPhoto),
                            backgroundColor: Colors.white,
                          )
                        : const CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, size: 50, color: Color(0xFF667eea)),
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => _changeProfilePicture(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF667eea), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                userName.isNotEmpty ? userName : 'User',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                userEmail.isNotEmpty ? userEmail : 'No email',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Premium Member', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== STATS ROW (REAL DATA) ====================
  Widget _buildStatsRow() {
    final scheme = Theme.of(context).colorScheme;

    final stats = [
      {
        'value': _itemCount.toString(),
        'label': 'Items',
        'icon': Icons.inventory_2_rounded,
      },
      {
        'value': 'PKR ${_currencyFormat.format(_totalExpenses)}',
        'label': 'Expenses',
        'icon': Icons.attach_money_rounded,
      },
      {
        // "Reports" had no real backing data anywhere in Firestore, so it was
        // pure decoration. Income is the natural real replacement here since
        // it's the one other headline number worth surfacing on this screen.
        'value': 'PKR ${_currencyFormat.format(_totalIncome)}',
        'label': 'Income',
        'icon': Icons.trending_up_rounded,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          return Expanded(
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
                CurvedAnimation(
                  parent: _listController,
                  curve: Interval(0.1 * index, 0.4 + (0.1 * index), curve: Curves.easeOutCubic),
                ),
              ),
              child: FadeTransition(
                opacity: _listController,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _darkModeEnabled
                        ? []
                        : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Icon(stat['icon'] as IconData, color: const Color(0xFF667eea), size: 24),
                      const SizedBox(height: 8),
                      _statsLoading
                          ? SizedBox(
                              height: 18,
                              width: 40,
                              child: Center(
                                child: SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                                ),
                              ),
                            )
                          : Text(
                              stat['value'] as String,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        stat['label'] as String,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== PREFERENCES SECTION ====================
  Widget _buildPreferencesSection(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildSectionTitle('Preferences'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _darkModeEnabled
                ? []
                : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildSwitchTile(
                'Push Notifications',
                'Receive alerts and updates',
                Icons.notifications_outlined,
                const Color(0xFF667eea),
                _notificationsEnabled,
                (v) => setState(() => _notificationsEnabled = v),
              ),
              _buildSwitchTile(
                'Dark Mode',
                'Enable dark theme',
                Icons.dark_mode_outlined,
                const Color(0xFF764ba2),
                _darkModeEnabled,
                (v) {
                  themeProvider.toggleTheme();
                  setState(() => _darkModeEnabled = v);
                },
              ),
              _buildSwitchTile(
                'Biometric Login',
                'Use fingerprint or face ID',
                Icons.fingerprint_rounded,
                const Color(0xFF66bb6a),
                _biometricEnabled,
                (v) => setState(() => _biometricEnabled = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, Color color, bool value, Function(bool) onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(_darkModeEnabled ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: color),
        ],
      ),
    );
  }

  // ==================== SETTINGS SECTIONS ====================
  List<Widget> _buildSettingsSections() {
    final scheme = Theme.of(context).colorScheme;
    List<Widget> widgets = [];
    for (int sIndex = 0; sIndex < _settingsSections.length; sIndex++) {
      final section = _settingsSections[sIndex];
      widgets.add(_buildSectionTitle(section['title'] as String));
      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _darkModeEnabled
                ? []
                : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: (section['items'] as List<Map<String, dynamic>>).asMap().entries.map((entry) {
              final itemIndex = entry.key;
              final item = entry.value;
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(
                  CurvedAnimation(
                    parent: _listController,
                    curve: Interval(0.2 + (sIndex * 0.1) + (itemIndex * 0.05), 0.6 + (sIndex * 0.1) + (itemIndex * 0.05), curve: Curves.easeOutCubic),
                  ),
                ),
                child: FadeTransition(
                  opacity: _listController,
                  child: _buildSettingsTile(
                    item['title'] as String,
                    item['subtitle'] as String,
                    item['icon'] as IconData,
                    item['color'] as Color,
                    () => _handleAction(item['action'] as String),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildSettingsTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(_darkModeEnabled ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }

  // ==================== LOGOUT BUTTON ====================
  Widget _buildLogoutButton(AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: _listController,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: authProvider.isLoading ? null : () => _logout(authProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: authProvider.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(
                authProvider.isLoading ? 'Logging out...' : 'Logout',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== ACTION HANDLERS ====================
  void _handleAction(String action) {
    switch (action) {
      case 'editProfile':
        _editProfile();
        break;
      case 'changePassword':
        _changePassword();
        break;
      case 'businessDetails':
        _showComingSoon('Business Details');
        break;
      case 'exportData':
        _exportData();
        break;
      case 'backupRestore':
        _showComingSoon('Backup & Restore');
        break;
      case 'clearCache':
        _clearCache();
        break;
      case 'helpCenter':
        _showComingSoon('Help Center');
        break;
      case 'privacyPolicy':
        _showComingSoon('Privacy Policy');
        break;
      case 'termsOfService':
        _showComingSoon('Terms of Service');
        break;
      case 'about':
        _showAbout();
        break;
      default:
        _showComingSoon('Coming Soon');
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _editProfile() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final nameController = TextEditingController(text: authProvider.displayName);
    final emailController = TextEditingController(text: authProvider.displayEmail);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await authProvider.updateProfile(
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error updating profile: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showComingSoon('Password Change');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFffa726)),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _changeProfilePicture() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF667eea)),
              title: Text('Take Photo', style: TextStyle(color: scheme.onSurface)),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF66bb6a)),
              title: Text('Choose from Gallery', style: TextStyle(color: scheme.onSurface)),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: Text('Remove Photo', style: TextStyle(color: scheme.onSurface)),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _exportData() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Format',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.file_present_rounded, color: Color(0xFF66bb6a)),
              title: Text('Export as Excel', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exporting as Excel...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFf5576c)),
              title: Text('Export as PDF', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exporting as PDF...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache'),
        content: const Text('This will free up storage space. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFffa726)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Inventory Manager',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 32),
      ),
      children: const [Text('A powerful inventory and expense tracker with AI-powered insights.')],
    );
  }

  // ==================== LOGOUT ====================
  // Fix: logging out flips AuthProvider.isAuthenticated, which makes MyApp's
  // Consumer2 swap `home:` from MainNavigation to LoginScreen — unmounting
  // this whole screen (including this State object) partway through. Any
  // `context` use after an `await` here can therefore run on a disposed
  // widget. Guarding with `if (!mounted) return;` after every await, and
  // capturing ScaffoldMessenger before the await where relevant, makes this
  // safe regardless of how fast the navigation swap happens.
  void _logout(AuthProvider authProvider) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Capture this BEFORE the await — once the widget tree swaps
              // out from under us, `ScaffoldMessenger.of(context)` would fail
              // to find an ancestor even for the success case.
              final rootMessenger = ScaffoldMessenger.maybeOf(context);

              try {
                await authProvider.logout();
                // ProfileScreen may already be disposed at this point because
                // the auth state change navigated away — don't touch context
                // or call setState if so.
                if (!mounted) return;
                rootMessenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                rootMessenger?.showSnackBar(
                  SnackBar(
                    content: Text('Logout error: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}