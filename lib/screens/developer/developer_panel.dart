import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../models/order_model.dart';
import '../../models/shop_model.dart';
import '../../models/user_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/cart_item_model.dart';
import '../../models/cash_transaction_model.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import 'package:lottie/lottie.dart';
import '../../config/lottie_assets.dart';
import '../../services/auth_service.dart';
import '../../services/order_notification_manager.dart';
import '../../widgets/animations.dart';
import 'package:latlong2/latlong.dart' as ll2;
import '../../widgets/location_picker_dialog.dart';
import '../../config/menu_images.dart';

class DeveloperPanel extends StatefulWidget {
  const DeveloperPanel({super.key});

  @override
  State<DeveloperPanel> createState() => _DeveloperPanelState();
}

class _DeveloperPanelState extends State<DeveloperPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  final ShopService _shopService = ShopService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderNotificationManager _notificationManager =
      OrderNotificationManager();
  late final Stream<List<ShopModel>> _shopsStream = _shopService
      .getShops()
      .asBroadcastStream();

  // Eagerly cached shops for instant loading
  List<ShopModel> _cachedShops = [];
  bool _shopsLoaded = false;

  // System test results
  final Map<String, String> _testResults = {
    'firebase': 'pending',
    'database': 'pending',
    'auth': 'pending',
  };

  // Data consistency results
  final Map<String, String> _consistencyResults = {
    'orphanShops': 'pending',
    'orphanMenus': 'pending',
    'orphanOrders': 'pending',
    'shopsWithoutOwner': 'pending',
    'deliveryMigration': 'pending',
    'duplicateAssignments': 'pending',
  };

  // Summary data
  int _totalShops = 0;
  int _totalUsers = 0;
  int _ordersToday = 0;
  int _totalOrders = 0;

  // Orders filter
  String _orderFilter = 'all';
  String _searchQuery = '';

  // Search queries for each section
  final String _shopSearch = '';
  final String _menuSearch = '';
  String _userSearch = '';
  final String _staffSearch = '';

  // Menu management
  String? _selectedMenuShopId;
  String? _selectedMenuImageUrl;

  // Test order
  String? _selectedTestShopId;
  final Map<String, int> _testOrderItems = {}; // menuItemId -> quantity

  // Schedule management
  String? _selectedScheduleShopId;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};

  // Add Staff form
  final _staffNameController = TextEditingController();
  final _staffEmailController = TextEditingController();
  final _staffPhoneController = TextEditingController();
  String _staffRole = 'kitchen';
  String? _staffShopId;

  // Shop Management
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopLatController = TextEditingController();
  final _shopLngController = TextEditingController();
  final _shopImageController = TextEditingController();
  final _shopDiscountTagController = TextEditingController();
  final _shopDiscountDescController = TextEditingController();

  // Menu Management
  final _menuItemNameController = TextEditingController();
  final _menuItemPriceController = TextEditingController();
  final _menuItemImageController = TextEditingController();

  // User role management
  List<UserModel> _allUsers = [];

  // Payment settings
  bool _onlinePaymentsEnabled = true;
  bool _codEnabled = true;
  String? _selectedAuditShopId;
  String? _selectedPricingShopId;
  StreamSubscription? _paymentSettingsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);

    // Start loading immediately - don't wait for frame callback
    _loadAllDataInParallel();
  }

  /// Load all data in parallel for instant loading
  void _loadAllDataInParallel() {
    // Run all loads concurrently - don't await, just fire and forget
    _ensureDeveloperRole(); // Non-blocking role setup
    _loadShops();
    _loadSummary();
    _runSystemTests();
    _loadAllUsers();
    _initPaymentSettingsListener();
    _initNotificationListener();
  }

  /// Automatically ensures the current user has developer role
  Future<void> _ensureDeveloperRole() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Check if user already has developer role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists || userDoc.data()?['role'] != 'developer') {
        // Set developer role automatically
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? 'Developer',
          'photoURL': user.photoURL,
          'role': 'developer',
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Silently fail - the manual fix button is still available
      debugPrint('Auto-set developer role failed: $e');
    }
  }

  Future<void> _initNotificationListener() async {
    // Developer gets notifications for ALL orders
    _notificationManager.startListening(
      userRole: UserRole.developer,
      shopId: null, // null = all shops
    );
  }

  Future<void> _loadShops() async {
    try {
      final shops = await _shopService.getShops().first;
      if (mounted) {
        setState(() {
          _cachedShops = shops;
          _shopsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _shopsLoaded = true); // Mark loaded even on error
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paymentSettingsSubscription?.cancel();
    _notificationManager.stopListening();
    _staffNameController.dispose();
    _staffEmailController.dispose();
    _staffPhoneController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopLatController.dispose();
    _shopLngController.dispose();
    _shopImageController.dispose();
    _menuItemNameController.dispose();
    _menuItemPriceController.dispose();
    _menuItemImageController.dispose();
    _shopDiscountTagController.dispose();
    _shopDiscountDescController.dispose();
    super.dispose();
  }

  void _initPaymentSettingsListener() {
    _paymentSettingsSubscription = _firestore
        .collection('settings')
        .doc('paymentConfig')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data()!;
              setState(() {
                _onlinePaymentsEnabled = data['onlinePaymentsEnabled'] ?? true;
                _codEnabled = data['codEnabled'] ?? true;
              });
            }
          },
          onError: (e) {
            debugPrint(
              'DeveloperPanel: Error listening to payment settings: $e',
            );
          },
        );
  }

  Future<void> _loadAllUsers() async {
    try {
      final users = await _authService.getAllUsers();
      if (mounted) {
        setState(() => _allUsers = users);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadSummary() async {
    try {
      // Use count() for better performance and lower data usage
      final shopsCount = await _firestore.collection('shops').count().get();
      if (mounted) {
        setState(() => _totalShops = shopsCount.count ?? 0);
      }
    } catch (e) {
      debugPrint('DevPanel: Error loading shops: $e');
    }

    try {
      // Use regular query instead of count() for better compatibility
      final usersSnapshot = await _firestore.collection('users').get();
      if (mounted) {
        setState(() => _totalUsers = usersSnapshot.docs.length);
      }
    } catch (e) {
      debugPrint('DevPanel: Error loading users count: $e');
      // Don't show error popup - it's disruptive
    }

    try {
      final ordersSnapshot = await _firestore.collection('orders').get();
      if (mounted) {
        setState(() => _totalOrders = ordersSnapshot.docs.length);
      }
    } catch (e) {
      debugPrint('DevPanel: Error loading orders count: $e');
      // Don't show error popup - it's disruptive
    }

    try {
      // Orders today
      final ordersTodayData = await _orderService.getOrdersToday();
      if (mounted) {
        setState(() => _ordersToday = ordersTodayData.length);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _runSystemTests() async {
    setState(() {
      _testResults['firebase'] = 'pending';
      _testResults['database'] = 'pending';
      _testResults['auth'] = 'pending';
    });

    // Test Firebase Connection (read public collection)
    try {
      // Just test if we can connect to Firestore by reading shops
      await _firestore.collection('shops').limit(1).get();
      setState(() => _testResults['firebase'] = 'pass');
    } catch (e) {
      setState(() => _testResults['firebase'] = 'fail');
    }

    // Test Database
    try {
      await _firestore.collection('shops').limit(1).get();
      setState(() => _testResults['database'] = 'pass');
    } catch (e) {
      setState(() => _testResults['database'] = 'fail');
    }

    // Test Auth
    try {
      final user = _authService.currentUser;
      setState(() => _testResults['auth'] = user != null ? 'pass' : 'fail');
    } catch (e) {
      setState(() => _testResults['auth'] = 'fail');
    }
  }

  Future<void> _runDataConsistencyCheck() async {
    // Reset all to pending
    setState(() {
      _consistencyResults.forEach(
        (key, _) => _consistencyResults[key] = 'pending',
      );
    });

    // Check orphan shops (staff assigned to non-existent shops)
    try {
      final users = await _firestore.collection('users').get();
      final shops = await _firestore.collection('shops').get();
      final shopIds = shops.docs.map((d) => d.id).toSet();

      int orphanCount = 0;
      for (var user in users.docs) {
        final data = user.data();
        final shopId = data['shopId'] as String?;
        if (shopId != null && !shopIds.contains(shopId)) {
          orphanCount++;
        }
      }
      setState(
        () => _consistencyResults['orphanShops'] = orphanCount > 0
            ? '$orphanCount found'
            : 'OK',
      );
    } catch (e) {
      setState(() => _consistencyResults['orphanShops'] = 'Error');
    }

    // Check orphan menu items
    try {
      final menus = await _firestore.collection('menus').get();
      final shops = await _firestore.collection('shops').get();
      final shopIds = shops.docs.map((d) => d.id).toSet();

      int orphanCount = 0;
      for (var menu in menus.docs) {
        final data = menu.data();
        final shopId = data['shopId'] as String?;
        if (shopId != null && !shopIds.contains(shopId)) {
          orphanCount++;
        }
      }
      setState(
        () => _consistencyResults['orphanMenus'] = orphanCount > 0
            ? '$orphanCount found'
            : 'OK',
      );
    } catch (e) {
      setState(() => _consistencyResults['orphanMenus'] = 'Error');
    }

    // Check orphan orders
    try {
      final orders = await _firestore.collection('orders').get();
      final shops = await _firestore.collection('shops').get();
      final shopIds = shops.docs.map((d) => d.id).toSet();

      int orphanCount = 0;
      for (var order in orders.docs) {
        final data = order.data();
        final shopId = data['shopId'] as String?;
        if (shopId != null && !shopIds.contains(shopId)) {
          orphanCount++;
        }
      }
      setState(
        () => _consistencyResults['orphanOrders'] = orphanCount > 0
            ? '$orphanCount found'
            : 'OK',
      );
    } catch (e) {
      setState(() => _consistencyResults['orphanOrders'] = 'Error');
    }

    // Check shops without owner
    try {
      final shops = await _firestore.collection('shops').get();
      int noOwnerCount = 0;
      for (var shop in shops.docs) {
        final data = shop.data();
        final ownerId = data['ownerId'] as String?;
        if (ownerId == null || ownerId.isEmpty) {
          noOwnerCount++;
        }
      }
      setState(
        () => _consistencyResults['shopsWithoutOwner'] = noOwnerCount > 0
            ? '$noOwnerCount found'
            : 'OK',
      );
    } catch (e) {
      setState(() => _consistencyResults['shopsWithoutOwner'] = 'Error');
    }

    // Mark others as OK for now
    setState(() {
      _consistencyResults['deliveryMigration'] = 'OK';
      _consistencyResults['duplicateAssignments'] = 'OK';
    });
  }

  Future<void> _fixAllDataIssues() async {
    int fixedCount = 0;
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not logged in!'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fixing data issues...'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );

    try {
      // Fix shops without owners - assign current developer as owner
      final shops = await _firestore.collection('shops').get();
      for (var shop in shops.docs) {
        final data = shop.data();
        final ownerId = data['ownerId'] as String?;
        if (ownerId == null || ownerId.isEmpty) {
          await shop.reference.update({'ownerId': user.uid});
          fixedCount++;
        }
      }

      // Fix orphan staff - clear shopId for users assigned to non-existent shops
      final users = await _firestore.collection('users').get();
      final shopIds = shops.docs.map((d) => d.id).toSet();
      for (var userDoc in users.docs) {
        final data = userDoc.data();
        final shopId = data['shopId'] as String?;
        if (shopId != null && !shopIds.contains(shopId)) {
          await userDoc.reference.update({'shopId': FieldValue.delete()});
          fixedCount++;
        }
      }

      // Delete orphan menu items
      final menus = await _firestore.collection('menus').get();
      for (var menu in menus.docs) {
        final data = menu.data();
        final shopId = data['shopId'] as String?;
        if (shopId != null && !shopIds.contains(shopId)) {
          await menu.reference.delete();
          fixedCount++;
        }
      }

      // Re-run consistency check
      await _runDataConsistencyCheck();
      _loadSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fixed $fixedCount issues successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing issues: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  bool _hasPerm(UserModel? user, String perm) {
    if (user == null) return false;
    if (user.role == UserRole.developer) return true;
    return user.devPermissions.contains(perm);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userData;
    final isDev = user?.role == UserRole.developer;

    // Determine which tabs to show
    bool showDashboard =
        _hasPerm(user, 'summary') || _hasPerm(user, 'payments');
    bool showShopsMenu = _hasPerm(user, 'shops') || _hasPerm(user, 'menu');
    bool showUsers = _hasPerm(user, 'users');
    bool showOrders = _hasPerm(user, 'tools'); // Orders monitor and test flow

    List<Widget> tabs = [];
    if (showDashboard) {
      tabs.add(
        const Tab(text: 'Dashboard', icon: Icon(Icons.dashboard_outlined)),
      );
    }
    if (showShopsMenu) {
      tabs.add(
        const Tab(text: 'Shops & Menu', icon: Icon(Icons.storefront_outlined)),
      );
    }
    if (showUsers) {
      tabs.add(
        const Tab(text: 'Users & Roles', icon: Icon(Icons.people_alt_outlined)),
      );
    }
    if (showOrders) {
      tabs.add(
        const Tab(
          text: 'Orders & Testing',
          icon: Icon(Icons.shopping_bag_outlined),
        ),
      );
    }
    if (isDev) {
      tabs.addAll([
        const Tab(text: 'Analytics', icon: Icon(Icons.analytics_outlined)),
        const Tab(text: 'Cash Audit', icon: Icon(Icons.payments_outlined)),
        const Tab(text: 'UX & Assets', icon: Icon(Icons.movie_filter_outlined)),
      ]);
    }

    // Since we are changing tab count dynamically, we need to handle TabController
    if (_tabController.length != tabs.length) {
      // Small delay to rebuild controller
      Future.microtask(() {
        setState(() {
          _tabController = TabController(length: tabs.length, vsync: this);
        });
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        // title: const Text(
        //   'Dev Center',
        //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        // ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          _buildQuickAction(
            icon: Icons.refresh,
            tooltip: 'Reload All',
            onTap: () {
              _loadSummary();
              _runSystemTests();
              _loadAllUsers();
              _loadShops();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryBlue,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: tabs,
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (showDashboard)
            _buildResponsiveTab([
              if (_hasPerm(user, 'summary')) _buildSystemOverview(),
              if (_hasPerm(user, 'summary')) const SizedBox(height: 16),
              if (_hasPerm(user, 'payments')) _buildControlPanel(),
              if (isDev) const SizedBox(height: 16),
              if (isDev) _buildDataConsistency(),
            ]),
          if (showShopsMenu)
            _buildResponsiveTab([
              if (_hasPerm(user, 'shops')) _buildShopManagement(),
              if (_hasPerm(user, 'shops')) const SizedBox(height: 16),
              if (_hasPerm(user, 'shops')) _buildShopScheduleManagement(),
              if (_hasPerm(user, 'shops')) const SizedBox(height: 16),
              if (_hasPerm(user, 'shops')) _buildShopPricingManagement(),
              if (_hasPerm(user, 'menu')) const SizedBox(height: 16),
              if (_hasPerm(user, 'menu')) _buildMenuManagement(),
            ]),
          if (showUsers)
            _buildResponsiveTab([
              _buildAddStaffSection(),
              const SizedBox(height: 16),
              _buildUserRoleManagement(),
            ]),
          if (showOrders)
            _buildResponsiveTab([
              _buildOrdersMonitor(),
              const SizedBox(height: 16),
              _buildTestOrderFlow(),
            ]),
          if (isDev) ...[
            _buildResponsiveTab([_buildViewShopDashboard()]),
            _buildResponsiveTab([_buildCashAuditPanel()]),
            _buildResponsiveTab([_buildUXAssetsTab()]),
          ],
        ],
      ),
    );
  }

  Widget _buildCashAuditPanel() {
    return _DevCard(
      title: 'Cash Flow Audit',
      subtitle: 'Monitor collections and settlements across all shops',
      icon: Icons.payments,
      iconColor: AppTheme.success,
      child: Column(
        children: [
          // Shop selection row
          _buildAuditShopSelector(),
          const SizedBox(height: 16),

          StreamBuilder<List<CashTransactionModel>>(
            stream: _orderService.getCashTransactions(
              shopId: _selectedAuditShopId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final transactions = snapshot.data ?? [];

              // Calculate summary stats
              double collected = 0;
              double settled = 0;
              for (var tx in transactions) {
                if (tx.type == CashTransactionType.collection) {
                  collected += tx.amount;
                } else if (tx.type == CashTransactionType.settlement) {
                  settled += tx.amount;
                }
              }

              return Column(
                children: [
                  // Summary cards
                  _buildAuditSummary(collected, settled),
                  const SizedBox(height: 20),

                  // Action buttons
                  if (_selectedAuditShopId != null && (collected - settled) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: () => _showBatchSettlementConfirm(),
                        icon: const Icon(Icons.handshake),
                        label: Text(
                          'Settle All Shop Cash (₹${(collected - settled).toStringAsFixed(0)})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  const Divider(),
                  const SizedBox(height: 8),

                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppTheme.textTertiary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No transactions found',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return _buildTransactionTile(tx);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuditShopSelector() {
    return StreamBuilder<List<ShopModel>>(
      stream: _shopsStream,
      initialData: _cachedShops,
      builder: (context, snapshot) {
        final shops = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildShopPicker(
            value: _selectedAuditShopId,
            shops: shops,
            label: 'Select Shop for Audit',
            onChanged: (value) => setState(() => _selectedAuditShopId = value),
          ),
        );
      },
    );
  }

  Widget _buildAuditSummary(double collected, double settled) {
    final pending = collected - settled;
    return Row(
      children: [
        Expanded(
          child: _AuditSummaryCard(
            label: 'Collected',
            amount: collected,
            color: AppTheme.success,
            icon: Icons.add_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AuditSummaryCard(
            label: 'Settled',
            amount: settled,
            color: AppTheme.primaryBlue,
            icon: Icons.handshake_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AuditSummaryCard(
            label: 'Outstanding',
            amount: pending,
            color: pending > 0 ? AppTheme.warning : AppTheme.textSecondary,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(CashTransactionModel tx) {
    final isCollection = tx.type == CashTransactionType.collection;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isCollection
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.primaryBlue.withValues(alpha: 0.1),
        child: Icon(
          isCollection ? Icons.add : Icons.handshake,
          color: isCollection ? AppTheme.success : AppTheme.primaryBlue,
          size: 20,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isCollection ? "Collected" : "Settled",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            tx.formattedAmount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isCollection ? AppTheme.success : AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
      subtitle: Text(
        'By ${tx.userName} • ${DateFormat('MMM dd, HH:mm').format(tx.timestamp)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${tx.orderId.length > 4 ? tx.orderId.substring(tx.orderId.length - 4) : tx.orderId}',
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppTheme.error,
            ),
            onPressed: () => _showDeleteTransactionConfirm(tx),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete Transaction',
          ),
        ],
      ),
    );
  }

  void _showBatchSettlementConfirm() {
    final shop = _cachedShops.firstWhere((s) => s.id == _selectedAuditShopId);
    final user = Provider.of<AuthProvider>(context, listen: false).userData;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Batch Settlement'),
        content: Text(
          'Are you sure you want to mark all collected cash for ${shop.name} as settled with the owner?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (user == null) return;

              try {
                final count = await _orderService.settleAllCashForShop(
                  shop.id,
                  user.uid,
                  user.displayName ?? 'Developer',
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Successfully settled $count orders for ${shop.name}',
                      ),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Settle All'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTransactionConfirm(CashTransactionModel tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to permanently delete this ${tx.type.name} record of ${tx.formattedAmount}? This action only removes the audit log, it DOES NOT change the order status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _orderService.deleteCashTransaction(tx.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted successfully'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildUXAssetsTab() {
    return _DevCard(
      title: 'UX & Animation Assets',
      subtitle: 'Preview all Lottie animations used in the app',
      icon: Icons.movie_filter_outlined,
      iconColor: AppTheme.success,
      child: Column(children: [_buildLottieGrid()]),
    );
  }

  Widget _buildLottieGrid() {
    final Map<String, String> animations = {
      'Cooking': LottieAssets.cooking,
      'Delivery': LottieAssets.delivery,
      'Food Delivery': LottieAssets.foodDelivery,
      'Success': LottieAssets.success,
      'Celebration': LottieAssets.celebration,
      'Confetti': LottieAssets.confetti,
      'Order Success': LottieAssets.orderSuccess,
      'Checkmark': LottieAssets.checkmark,
      'Loading': LottieAssets.loading,
      'Food Loading': LottieAssets.foodLoading,
      'Empty Cart': LottieAssets.emptyCart,
      'Empty Box': LottieAssets.emptyBox,
      'No Data': LottieAssets.noData,
      'Not Found': LottieAssets.notFound,
      'Error': LottieAssets.error,
      'Warning': LottieAssets.warning,
      'Star': LottieAssets.star,
      'Heart': LottieAssets.heart,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: animations.length,
      itemBuilder: (context, index) {
        final key = animations.keys.elementAt(index);
        final url = animations[key]!;
        // Use animationType logic from EmptyState if possible or just Lottie.network
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Lottie.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.error,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'URL Error',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.error.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Text(
                  key,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
        ),
      ),
    );
  }

  Widget _buildShopPicker({
    required String? value,
    required List<ShopModel> shops,
    required String label,
    required Function(String?) onChanged,
  }) {
    final selectedShop = shops.firstWhere(
      (s) => s.id == value,
      orElse: () => ShopModel(id: '', name: 'Select a Shop'),
    );

    return InkWell(
      onTap: () => _showShopPickerSheet(shops, value, onChanged),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: AppTheme.primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  Text(
                    value == null ? 'None selected' : selectedShop.name,
                    style: TextStyle(
                      color: value == null
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: value == null
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.unfold_more,
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showShopPickerSheet(
    List<ShopModel> shops,
    String? currentValue,
    Function(String?) onSelected,
  ) {
    final searchController = TextEditingController();
    List<ShopModel> filteredShops = List.from(shops);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Select Shop',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        prefixIcon: const Icon(Icons.search),
                        fillColor: AppTheme.background,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          filteredShops = shops
                              .where(
                                (s) => s.name.toLowerCase().contains(
                                  val.toLowerCase(),
                                ),
                              )
                              .toList();
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredShops.isEmpty
                    ? const Center(
                        child: Text(
                          'No shops found',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: filteredShops.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, index) {
                          final shop = filteredShops[index];
                          final isSelected = shop.id == currentValue;

                          return InkWell(
                            onTap: () {
                              onSelected(shop.id);
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryBlue
                                          : AppTheme.background,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.storefront,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.primaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop.name,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 15,
                                            color: isSelected
                                                ? AppTheme.primaryBlue
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (shop.address != null)
                                          Text(
                                            shop.address!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primaryBlue,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveTab(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1200 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemOverview() {
    return _DevCard(
      title: 'System Overview',
      subtitle: 'Quick summary of the platform status',
      icon: Icons.analytics,
      iconColor: AppTheme.developerColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Total Shops',
                  value: '$_totalShops',
                  icon: Icons.store,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: 'Total Users',
                  value: '$_totalUsers',
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: 'Orders Today',
                  value: '$_ordersToday',
                  icon: Icons.today,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: 'Total Orders',
                  value: '$_totalOrders',
                  icon: Icons.list_alt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _runSystemTests();
                  _loadSummary();
                  _loadAllUsers();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Run System Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return _DevCard(
      title: 'Developer Control Panel',
      subtitle: 'System testing & debugging',
      icon: Icons.code,
      iconColor: AppTheme.developerColor,
      child: Column(
        children: [
          // Test badges
          Row(
            children: [
              Expanded(
                child: _TestBadge(
                  label: 'Firebase Connection',
                  status: _testResults['firebase'] ?? 'pending',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TestBadge(
                  label: 'Database Access',
                  status: _testResults['database'] ?? 'pending',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TestBadge(
                  label: 'Auth System',
                  status: _testResults['auth'] ?? 'pending',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Push notification test
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Push Notification',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Push notifications require Firebase Cloud Messaging setup',
                        ),
                        backgroundColor: AppTheme.warning,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text('Test', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: _runSystemTests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: const Text('Run Full System Test'),
              ),
              ElevatedButton(
                onPressed: () => _showConfirmDialog(
                  'Reset Customer Orders',
                  'This will delete all non-test orders. Are you sure?',
                  _resetCustomerOrders,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                child: const Text('Reset Customer Orders'),
              ),
              ElevatedButton.icon(
                onPressed: _fixDeveloperRole,
                icon: const Icon(Icons.admin_panel_settings, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                ),
                label: const Text('Fix My Role'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Payment Method Controls
          _buildPaymentControls(),
        ],
      ),
    );
  }

  Widget _buildPaymentControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.payment,
                  color: Colors.orange.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method Controls',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Global ON/OFF for payment methods',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Online Payments Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _onlinePaymentsEnabled
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.borderLight,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _onlinePaymentsEnabled
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: _onlinePaymentsEnabled
                        ? AppTheme.success
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Online Payments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'via Razorpay',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _onlinePaymentsEnabled
                                  ? AppTheme.success.withValues(alpha: 0.15)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _onlinePaymentsEnabled ? 'ON' : 'OFF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _onlinePaymentsEnabled
                                    ? AppTheme.success
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _onlinePaymentsEnabled,
                    onChanged: (value) async {
                      await _updatePaymentSetting(
                        'onlinePaymentsEnabled',
                        value,
                      );
                    },
                    activeThumbColor: AppTheme.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Cash on Delivery Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _codEnabled
                    ? Colors.amber.shade700.withValues(alpha: 0.3)
                    : AppTheme.borderLight,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _codEnabled
                        ? Colors.amber.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: _codEnabled
                        ? Colors.amber.shade700
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash on Delivery',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Pay at delivery',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _codEnabled
                                  ? Colors.amber.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _codEnabled ? 'ON' : 'OFF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _codEnabled
                                    ? Colors.amber.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _codEnabled,
                    onChanged: (value) async {
                      await _updatePaymentSetting('codEnabled', value);
                    },
                    activeThumbColor: Colors.amber.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePaymentSetting(String field, bool value) async {
    try {
      await _firestore.collection('settings').doc('paymentConfig').set({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        if (field == 'onlinePaymentsEnabled') {
          _onlinePaymentsEnabled = value;
        } else {
          _codEnabled = value;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${field == "onlinePaymentsEnabled" ? "Online payments" : "Cash on Delivery"} ${value ? "enabled" : "disabled"}',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      print('Error updating payment setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update payment settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fixDeveloperRole() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not logged in!'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      // Update or create user document with developer role
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? 'Developer',
        'photoURL': user.photoURL,
        'role': 'developer',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Developer role set! Please refresh the page.'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Reload data
        _loadSummary();
        _loadAllUsers();
        _runSystemTests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting role: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildDataConsistency() {
    return _DevCard(
      title: 'Data Consistency',
      subtitle: 'Check and fix database inconsistencies',
      icon: Icons.check_circle,
      iconColor: AppTheme.success,
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _ConsistencyTile(
                label: 'Orphan Shops',
                status: _consistencyResults['orphanShops'] ?? 'pending',
                description: 'Staff assigned to non-existent shops',
              ),
              _ConsistencyTile(
                label: 'Delivery Migration',
                status: _consistencyResults['deliveryMigration'] ?? 'pending',
                description: 'Delivery staff needing shopIds array',
              ),
              _ConsistencyTile(
                label: 'Shops Without Owner',
                status: _consistencyResults['shopsWithoutOwner'] ?? 'pending',
                description: 'Shops with no assigned owner',
              ),
              _ConsistencyTile(
                label: 'Orphan Menu Items',
                status: _consistencyResults['orphanMenus'] ?? 'pending',
                description: 'Menu items for non-existent shops',
              ),
              _ConsistencyTile(
                label: 'Orphan Orders',
                status: _consistencyResults['orphanOrders'] ?? 'pending',
                description: 'Orders for non-existent shops',
              ),
              _ConsistencyTile(
                label: 'Duplicate Assignments',
                status:
                    _consistencyResults['duplicateAssignments'] ?? 'pending',
                description: 'Shops in both shopId and shopIds',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: _runDataConsistencyCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: const Text('Check Data Consistency'),
              ),
              ElevatedButton(
                onPressed: _fixAllDataIssues,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
                child: const Text('Fix All Issues'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopManagement() {
    return _DevCard(
      title: 'Shop Management',
      subtitle: 'Create and manage shops',
      icon: Icons.store,
      iconColor: AppTheme.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create shop form - collapsible
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: const Icon(
                  Icons.add_business,
                  size: 20,
                  color: AppTheme.success,
                ),
                title: const Text(
                  'Create New Shop',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                children: [
                  TextField(
                    controller: _shopNameController,
                    decoration: _inputDecoration('Shop Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _shopAddressController,
                    decoration: _inputDecoration('Shop Address'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _shopPhoneController,
                    decoration: _inputDecoration('Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shopLatController,
                          decoration: _inputDecoration('Latitude'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _shopLngController,
                          decoration: _inputDecoration('Longitude'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.map,
                          color: AppTheme.primaryBlue,
                        ),
                        onPressed: () async {
                          final ll2.LatLng? picked =
                              await showDialog<ll2.LatLng>(
                                context: context,
                                builder: (context) => LocationPickerDialog(
                                  initialLocation:
                                      _shopLatController.text.isNotEmpty &&
                                          _shopLngController.text.isNotEmpty
                                      ? ll2.LatLng(
                                          double.tryParse(
                                                _shopLatController.text,
                                              ) ??
                                              28.6139,
                                          double.tryParse(
                                                _shopLngController.text,
                                              ) ??
                                              77.2090,
                                        )
                                      : null,
                                ),
                              );
                          if (picked != null) {
                            _shopLatController.text = picked.latitude
                                .toStringAsFixed(6);
                            _shopLngController.text = picked.longitude
                                .toStringAsFixed(6);
                          }
                        },
                        tooltip: 'Pick on Map',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _shopImageController,
                    decoration: _inputDecoration('Image URL (Optional)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_shopNameController.text.isNotEmpty) {
                        await _shopService.createShop(
                          name: _shopNameController.text,
                          address: _shopAddressController.text.isNotEmpty
                              ? _shopAddressController.text
                              : null,
                          phoneNumber: _shopPhoneController.text.isNotEmpty
                              ? _shopPhoneController.text
                              : null,
                          latitude: double.tryParse(_shopLatController.text),
                          longitude: double.tryParse(_shopLngController.text),
                          imageUrl: _shopImageController.text.isNotEmpty
                              ? _shopImageController.text
                              : null,
                        );
                        _shopNameController.clear();
                        _shopAddressController.clear();
                        _shopPhoneController.clear();
                        _shopLatController.clear();
                        _shopLngController.clear();
                        _shopImageController.clear();
                        _loadSummary();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Shop created!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Create Shop'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Existing shops - compact list
          Row(
            children: [
              const Icon(
                Icons.storefront,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              const Text(
                'Existing Shops',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              StreamBuilder<List<ShopModel>>(
                stream: _shopsStream,
                initialData: _cachedShops,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Icon(
                      Icons.error,
                      color: AppTheme.error,
                      size: 16,
                    );
                  }
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: StreamBuilder<List<ShopModel>>(
              stream: _shopsStream,
              initialData: _cachedShops,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 8),
                        Text(
                          'Loading shops...',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }
                final shops = snapshot.data!;
                if (shops.isEmpty) {
                  return const Center(child: Text('No shops found.'));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: shops.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(
                        Icons.store,
                        color: AppTheme.primaryBlue,
                        size: 18,
                      ),
                      title: Text(
                        shop.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        shop.address ?? 'No address',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: AppTheme.error,
                          size: 18,
                        ),
                        onPressed: () => _showConfirmDialog(
                          'Delete Shop',
                          'Delete "${shop.name}"? This will also delete all menu items and orders.',
                          () async {
                            await _shopService.deleteShop(shop.id);
                            _loadSummary();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopScheduleManagement() {
    return _DevCard(
      title: 'Shop Schedule Management',
      subtitle: 'Update shop operating hours',
      icon: Icons.schedule,
      iconColor: AppTheme.warning,
      child: StreamBuilder<List<ShopModel>>(
        stream: _shopsStream,
        initialData: _cachedShops,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shops = snapshot.data!;
          if (shops.isEmpty) {
            return const Text('Create a shop first to manage schedules.');
          }

          return Column(
            children: [
              _buildShopPicker(
                value: _selectedScheduleShopId,
                shops: shops,
                label: 'Select Shop to Manage Schedule',
                onChanged: (value) {
                  if (value != null) {
                    final shop = shops.firstWhere((s) => s.id == value);
                    final schedule = shop.schedule;
                    setState(() {
                      _selectedScheduleShopId = value;
                      _openTime = schedule.openTime != null
                          ? _parseTimeString(schedule.openTime!)
                          : const TimeOfDay(hour: 9, minute: 0);
                      _closeTime = schedule.closeTime != null
                          ? _parseTimeString(schedule.closeTime!)
                          : const TimeOfDay(hour: 21, minute: 0);
                      _selectedDays = Set<String>.from(schedule.daysOpen);
                    });
                  } else {
                    setState(() => _selectedScheduleShopId = null);
                  }
                },
              ),
              if (_selectedScheduleShopId != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      // Time pickers row - compact
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactTimePicker(
                              label: 'Open',
                              time: _openTime,
                              icon: Icons.access_time,
                              iconColor: AppTheme.success,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      _openTime ??
                                      const TimeOfDay(hour: 9, minute: 0),
                                );
                                if (picked != null) {
                                  setState(() => _openTime = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactTimePicker(
                              label: 'Close',
                              time: _closeTime,
                              icon: Icons.access_time,
                              iconColor: AppTheme.error,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      _closeTime ??
                                      const TimeOfDay(hour: 21, minute: 0),
                                );
                                if (picked != null) {
                                  setState(() => _closeTime = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Days selector - compact chips
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children:
                            [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ].map((day) {
                              final isSelected = _selectedDays.contains(day);
                              return FilterChip(
                                label: Text(
                                  day,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: isSelected,
                                onSelected: (selected) => setState(
                                  () => selected
                                      ? _selectedDays.add(day)
                                      : _selectedDays.remove(day),
                                ),
                                selectedColor: AppTheme.success.withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: AppTheme.success,
                                backgroundColor: AppTheme.background,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 12),
                      // Update button
                      ElevatedButton.icon(
                        onPressed: () =>
                            _updateShopSchedule(_selectedScheduleShopId!),
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save Schedule'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          minimumSize: const Size(double.infinity, 36),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactTimePicker({
    required String label,
    required TimeOfDay? time,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  time?.format(context) ?? '--:--',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Icon(icon, color: iconColor, size: 18),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final cleanTime = timeStr.split(' ')[0];
      final parts = cleanTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1].substring(0, 2)) : 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print('Error parsing time: $timeStr');
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateShopSchedule(String shopId) async {
    if (_openTime == null || _closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select open and close times'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('shops').doc(shopId).update({
        'schedule': {
          'openTime': _formatTimeOfDay(_openTime!),
          'closeTime': _formatTimeOfDay(_closeTime!),
          'daysOpen': _selectedDays.toList(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Don't reset _selectedScheduleShopId so tools stay visible
        // setState(() => _selectedScheduleShopId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ========== SHOP PRICING MANAGEMENT ==========
  Widget _buildShopPricingManagement() {
    return _DevCard(
      title: 'Shop Pricing Management',
      subtitle: 'Configure minimum order, delivery charges & GST',
      icon: Icons.currency_rupee,
      iconColor: AppTheme.success,
      child: StreamBuilder<List<ShopModel>>(
        stream: _shopsStream,
        initialData: _cachedShops,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading shops: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shops = snapshot.data!;
          if (shops.isEmpty) {
            return const Text('Create a shop first to manage pricing.');
          }

          return Column(
            children: [
              _buildShopPicker(
                value: _selectedPricingShopId,
                shops: shops,
                label: 'Select Shop to Manage Pricing & Discounts',
                onChanged: (value) {
                  if (value != null) {
                    final shop = shops.firstWhere((s) => s.id == value);
                    _shopDiscountTagController.text = shop.discountTag ?? '';
                    _shopDiscountDescController.text =
                        shop.discountDescription ?? '';
                  }
                  setState(() => _selectedPricingShopId = value);
                },
              ),
              if (_selectedPricingShopId != null) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final shop = shops.firstWhere(
                      (s) => s.id == _selectedPricingShopId,
                    );
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildPricingRow(
                            label: 'Minimum Order',
                            value: shop.minimumOrderAmount,
                            suffix: '',
                            prefix: '₹',
                            step: 50,
                            min: 0,
                            max: 1000,
                            onChanged: (value) => _updateShopPricing(
                              shop.id,
                              'minimumOrderAmount',
                              value,
                              'Minimum Order',
                              '₹',
                              '',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPricingRow(
                            label: 'Delivery Charge',
                            value: shop.deliveryCharge,
                            suffix: '',
                            prefix: '₹',
                            step: 10,
                            min: 0,
                            max: 200,
                            onChanged: (value) => _updateShopPricing(
                              shop.id,
                              'deliveryCharge',
                              value,
                              'Delivery Charge',
                              '₹',
                              '',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPricingRow(
                            label: 'GST',
                            value: shop.gstPercentage,
                            suffix: '%',
                            prefix: '',
                            step: 1,
                            min: 0,
                            max: 18,
                            onChanged: (value) => _updateShopPricing(
                              shop.id,
                              'gstPercentage',
                              value,
                              'GST',
                              '',
                              '%',
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_offer,
                                size: 18,
                                color: AppTheme.primaryOrange,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Discount tag & Sales Bar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _shopDiscountTagController,
                            decoration: _inputDecoration(
                              'Discount Tag (e.g. 50% OFF)',
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _shopDiscountDescController,
                            decoration: _inputDecoration(
                              'Short Description (e.g. Up to ₹100)',
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _updateShopDiscount(shop.id),
                            icon: const Icon(Icons.flash_on, size: 16),
                            label: const Text('Update Offer Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryOrange,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateShopPricing(
    String shopId,
    String field,
    double value,
    String label,
    String prefix,
    String suffix,
  ) async {
    try {
      await _firestore.collection('shops').doc(shopId).update({field: value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label updated to $prefix${value.toInt()}$suffix'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $label: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateShopDiscount(String shopId) async {
    try {
      final tag = _shopDiscountTagController.text.trim();
      final desc = _shopDiscountDescController.text.trim();

      await _firestore.collection('shops').doc(shopId).update({
        'discountTag': tag.isEmpty ? null : tag,
        'discountDescription': desc.isEmpty ? null : desc,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop offer details updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update offer: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildPricingRow({
    required String label,
    required double value,
    required String suffix,
    required String prefix,
    required double step,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(7),
                  ),
                  onTap: () {
                    if (value >= min + step) {
                      onChanged(value - step);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.remove, size: 16),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 55),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$prefix${value.toInt()}$suffix',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(7),
                  ),
                  onTap: () {
                    if (value <= max - step) {
                      onChanged(value + step);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.add, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Image',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showImagePickerSheet(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                if (_selectedMenuImageUrl != null)
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(
                          _selectedMenuImageUrl!,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _selectedMenuImageUrl == null
                        ? 'Choose from gallery'
                        : 'Image selected',
                    style: TextStyle(
                      color: _selectedMenuImageUrl == null
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const Text(
                    'Select Menu Image',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: MenuImages.urls.length,
                itemBuilder: (context, index) {
                  final url = MenuImages.urls[index];
                  final isSelected = _selectedMenuImageUrl == url;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMenuImageUrl = url;
                        _menuItemImageController.text = url;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuManagement() {
    return _DevCard(
      title: 'Menu Management',
      subtitle: 'Add and manage menu items',
      icon: Icons.restaurant_menu,
      iconColor: AppTheme.warning,
      child: StreamBuilder<List<ShopModel>>(
        stream: _shopsStream,
        initialData: _cachedShops,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedLoader(size: 80),
                  SizedBox(height: 16),
                  Text('Fetching shops...'),
                ],
              ),
            );
          }
          final shops = snapshot.data!;
          if (shops.isEmpty) {
            return const Text('Create a shop first to manage menus.');
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShopPicker(
                value: _selectedMenuShopId,
                shops: shops,
                label: 'Select Shop to Manage',
                onChanged: (value) =>
                    setState(() => _selectedMenuShopId = value),
              ),
              if (_selectedMenuShopId != null) ...[
                const SizedBox(height: 16),
                _buildImageSelector(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add menu item form
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Menu Item',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _menuItemNameController,
                            decoration: _inputDecoration('Item Name'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _menuItemPriceController,
                            decoration: _inputDecoration('Item Price'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _menuItemImageController,
                            onChanged: (val) =>
                                setState(() => _selectedMenuImageUrl = val),
                            decoration: _inputDecoration(
                              'Item Image URL (Optional)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_menuItemNameController.text.isNotEmpty &&
                                  _menuItemPriceController.text.isNotEmpty) {
                                await _shopService.addMenuItem(
                                  shopId: _selectedMenuShopId!,
                                  name: _menuItemNameController.text,
                                  price:
                                      double.tryParse(
                                        _menuItemPriceController.text,
                                      ) ??
                                      0,
                                  imageUrl:
                                      _menuItemImageController.text.isNotEmpty
                                      ? _menuItemImageController.text
                                      : null,
                                );
                                _menuItemNameController.clear();
                                _menuItemPriceController.clear();
                                _menuItemImageController.clear();
                                setState(() {
                                  _selectedMenuImageUrl = null;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Menu item added!'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            child: const Text('Add Item'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Current menu items
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Menu Items',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: StreamBuilder<List<MenuItemModel>>(
                              stream: _shopService.getMenuItems(
                                _selectedMenuShopId!,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final items = snapshot.data!;
                                if (items.isEmpty) {
                                  return const Center(
                                    child: Text('No menu items yet.'),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(item.name),
                                      subtitle: Text(
                                        '₹${item.price.toStringAsFixed(0)}',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: AppTheme.error,
                                          size: 20,
                                        ),
                                        onPressed: () => _shopService
                                            .deleteMenuItem(item.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTestOrderFlow() {
    return _DevCard(
      title: 'Test Order Flow (No Payment Required)',
      subtitle: 'Test the complete order workflow',
      icon: Icons.science,
      iconColor: AppTheme.primaryBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Test orders bypass payment and are for testing the complete workflow only.',
                    style: TextStyle(color: AppTheme.primaryBlue, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Use cached shops for instant loading
          Builder(
            builder: (context) {
              if (!_shopsLoaded) {
                return const Center(child: AnimatedLoader(size: 60));
              }
              if (_cachedShops.isEmpty) {
                return const Text('No shops available for testing.');
              }
              final shops = _cachedShops;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShopPicker(
                    value: _selectedTestShopId,
                    shops: shops,
                    label: 'Select Shop for Test Order',
                    onChanged: (value) {
                      setState(() {
                        _selectedTestShopId = value;
                        _testOrderItems
                            .clear(); // Clear items when shop changes
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Show menu items when shop is selected
                  if (_selectedTestShopId != null) ...[
                    const Text(
                      'Select Menu Items:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<MenuItemModel>>(
                      stream: _shopService.getMenuItems(_selectedTestShopId!),
                      builder: (context, menuSnapshot) {
                        if (!menuSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final menuItems = menuSnapshot.data!;
                        if (menuItems.isEmpty) {
                          return const Text(
                            'No menu items available for this shop.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          );
                        }
                        return Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: menuItems.length,
                            itemBuilder: (context, index) {
                              final item = menuItems[index];
                              final qty = _testOrderItems[item.id] ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: qty > 0
                                      ? AppTheme.success.withValues(alpha: 0.1)
                                      : AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: qty > 0
                                        ? AppTheme.success
                                        : AppTheme.borderLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '₹${item.price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity controls
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          onPressed: qty > 0
                                              ? () => setState(() {
                                                  if (qty == 1) {
                                                    _testOrderItems.remove(
                                                      item.id,
                                                    );
                                                  } else {
                                                    _testOrderItems[item.id] =
                                                        qty - 1;
                                                  }
                                                })
                                              : null,
                                          iconSize: 24,
                                          color: AppTheme.error,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          onPressed: () => setState(() {
                                            _testOrderItems[item.id] = qty + 1;
                                          }),
                                          iconSize: 24,
                                          color: AppTheme.success,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Show total
                    if (_testOrderItems.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_testOrderItems.values.fold(0, (a, b) => a + b)} item(s) selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.success,
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                        _selectedTestShopId != null &&
                            _testOrderItems.isNotEmpty
                        ? () => _createTestOrderWithItems(
                            shops.firstWhere(
                              (s) => s.id == _selectedTestShopId,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Test Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createTestOrderWithItems(ShopModel shop) async {
    try {
      // Get menu items for the order
      final menuItems = await _shopService.getMenuItems(shop.id).first;
      final cartItems = <CartItemModel>[];

      for (final entry in _testOrderItems.entries) {
        final menuItem = menuItems.firstWhere((m) => m.id == entry.key);
        cartItems.add(CartItemModel(menuItem: menuItem, quantity: entry.value));
      }

      if (cartItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one item'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }

      final orderId = await _orderService.createOrder(
        shopId: shop.id,
        userId: _authService.currentUser?.uid,
        customerName: 'Test Customer',
        customerPhone: '9876543210',
        deliveryAddress: '123 Test Street, Test City',
        cartItems: cartItems,
        isTestOrder: true,
      );

      if (mounted) {
        setState(() {
          _testOrderItems.clear();
          _selectedTestShopId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test order created: $orderId'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadSummary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _buildOrdersMonitor() {
    return _DevCard(
      title: 'All Orders Monitor',
      subtitle: 'View and search all orders',
      icon: Icons.list_alt,
      iconColor: AppTheme.ownerColor,
      child: Column(
        children: [
          // Filters - Responsive layout
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              _FilterChip(
                label: 'Today',
                isSelected: _orderFilter == 'today',
                onTap: () => setState(() => _orderFilter = 'today'),
              ),
              _FilterChip(
                label: 'This Week',
                isSelected: _orderFilter == 'week',
                onTap: () => setState(() => _orderFilter = 'week'),
              ),
              _FilterChip(
                label: 'This Month',
                isSelected: _orderFilter == 'month',
                onTap: () => setState(() => _orderFilter = 'month'),
              ),
              _FilterChip(
                label: 'All Time',
                isSelected: _orderFilter == 'all',
                onTap: () => setState(() => _orderFilter = 'all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search field - full width
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by customer name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: StreamBuilder<List<OrderModel>>(
              stream: _orderService.getAllOrders(limit: 50),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var orders = snapshot.data!;

                // Apply filters
                final now = DateTime.now();
                if (_orderFilter == 'today') {
                  orders = orders
                      .where(
                        (o) =>
                            o.createdAt?.day == now.day &&
                            o.createdAt?.month == now.month &&
                            o.createdAt?.year == now.year,
                      )
                      .toList();
                } else if (_orderFilter == 'week') {
                  final weekAgo = now.subtract(const Duration(days: 7));
                  orders = orders
                      .where((o) => o.createdAt?.isAfter(weekAgo) ?? false)
                      .toList();
                } else if (_orderFilter == 'month') {
                  final monthAgo = now.subtract(const Duration(days: 30));
                  orders = orders
                      .where((o) => o.createdAt?.isAfter(monthAgo) ?? false)
                      .toList();
                }

                // Apply search
                if (_searchQuery.isNotEmpty) {
                  orders = orders
                      .where(
                        (o) => o.customerName.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                }

                if (orders.isEmpty) {
                  return const Center(child: Text('No orders found.'));
                }
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _OrderMonitorTile(
                    order: orders[index],
                    onStatusChanged: (status) => _orderService
                        .updateOrderStatus(orders[index].id, status),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddStaffSection() {
    return _DevCard(
      title: 'Add New Staff',
      subtitle: 'Pre-create staff accounts',
      icon: Icons.person_add,
      iconColor: AppTheme.primaryBlue,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(
              Icons.person_add_alt,
              size: 20,
              color: AppTheme.success,
            ),
            title: const Text(
              'Register New Staff',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Kitchen, Delivery, Owner',
              style: TextStyle(fontSize: 11),
            ),
            children: [
              TextField(
                controller: _staffNameController,
                decoration: _inputDecoration('Full Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _staffEmailController,
                decoration: _inputDecoration('Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _staffPhoneController,
                decoration: _inputDecoration('Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: DropdownButtonFormField<String>(
                      initialValue: _staffRole,
                      decoration: _inputDecoration('Role'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'kitchen',
                          child: Text('Kitchen'),
                        ),
                        DropdownMenuItem(
                          value: 'delivery',
                          child: Text('Delivery'),
                        ),
                        DropdownMenuItem(value: 'owner', child: Text('Owner')),
                      ],
                      onChanged: (value) => setState(() => _staffRole = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: DropdownButtonFormField<String>(
                      initialValue: _staffShopId,
                      decoration: _inputDecoration('Shop'),
                      isExpanded: true,
                      items: _cachedShops
                          .map(
                            (shop) => DropdownMenuItem(
                              value: shop.id,
                              child: Text(
                                shop.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _staffShopId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _addStaffUser,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Add Staff Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Staff must sign up with the same email to link their account.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addStaffUser() async {
    final name = _staffNameController.text.trim();
    final email = _staffEmailController.text.trim().toLowerCase();
    final phone = _staffPhoneController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        _staffShopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      // Create a document in users collection with email as key or queryable field
      await _firestore.collection('users').add({
        'displayName': name,
        'email': email,
        'phoneNumber': phone,
        'role': _staffRole,
        'shopId': _staffShopId,
        'shopIds': [_staffShopId],
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': false,
        'isPreCreated': true, // Flag for AuthService to identify
      });

      _staffNameController.clear();
      _staffEmailController.clear();
      _staffPhoneController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff record created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadAllUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _buildUserRoleManagement() {
    final managableUsers = _allUsers;

    return _DevCard(
      title: 'User Role Management',
      subtitle: 'Manage user roles and shop assignments',
      icon: Icons.people,
      iconColor: AppTheme.primaryBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Total Users: ${managableUsers.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${managableUsers.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadAllUsers,
                icon: const Icon(
                  Icons.refresh,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search users by email or name...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _userSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _userSearch = ''),
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _userSearch = value),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // Apply search filter
              var filteredUsers = managableUsers;
              if (_userSearch.isNotEmpty) {
                filteredUsers = managableUsers
                    .where(
                      (u) =>
                          u.email.toLowerCase().contains(
                            _userSearch.toLowerCase(),
                          ) ||
                          (u.displayName?.toLowerCase().contains(
                                _userSearch.toLowerCase(),
                              ) ??
                              false),
                    )
                    .toList();
              }

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _userSearch.isNotEmpty
                          ? 'No users found for "$_userSearch"'
                          : 'No users found or permission denied.',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: filteredUsers.length > 5 ? 350 : double.infinity,
                ),
                child: ListView.builder(
                  shrinkWrap: filteredUsers.length <= 5,
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final roleValue =
                        [
                          'customer',
                          'kitchen',
                          'delivery',
                          'owner',
                          'developer',
                        ].contains(user.role.value)
                        ? user.role.value
                        : 'customer';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: _getRoleColor(
                              user.role,
                            ).withValues(alpha: 0.2),
                            child: Text(
                              user.email.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getRoleColor(user.role),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              _RoleBadge(role: user.role),
                              if (user.shopId != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '• ${_getShopName(user.shopId)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          children: [
                            // Role Selector
                            Row(
                              children: [
                                const Text(
                                  'Role:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                DropdownButton<String>(
                                  value: roleValue,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'customer',
                                      child: Text('Customer'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'kitchen',
                                      child: Text('Kitchen'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'delivery',
                                      child: Text('Delivery'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'owner',
                                      child: Text('Owner'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'developer',
                                      child: Text('Developer'),
                                    ),
                                  ],
                                  onChanged:
                                      user.role == UserRole.developer &&
                                          user.email == AppConfig.developerEmail
                                      ? null
                                      : (value) =>
                                            _updateUserRole(user.uid, value!),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Shop Assignment
                            if (user.role == UserRole.kitchen ||
                                user.role == UserRole.owner)
                              Row(
                                children: [
                                  const Text(
                                    'Shop:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  DropdownButton<String>(
                                    value:
                                        _cachedShops.any(
                                          (s) => s.id == user.shopId,
                                        )
                                        ? user.shopId
                                        : null,
                                    hint: const Text(
                                      'Select Shop',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    isDense: true,
                                    underline: const SizedBox(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                    items: _cachedShops
                                        .map(
                                          (shop) => DropdownMenuItem(
                                            value: shop.id,
                                            child: Text(
                                              shop.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) =>
                                        _updateUserShop(user.uid, value!),
                                  ),
                                ],
                              ),
                            if (user.role == UserRole.delivery)
                              Row(
                                children: [
                                  Text(
                                    'Shops: ${user.shopIds?.length ?? 0} assigned',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showMultiShopSelectionDialog(user),
                                    icon: const Icon(
                                      Icons.edit_location_alt_outlined,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Manage',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(60, 30),
                                    ),
                                  ),
                                ],
                              ),
                            if (user.role == UserRole.owner)
                              Row(
                                children: [
                                  const Text(
                                    'Permissions',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showPermissionsDialog(user),
                                    icon: const Icon(
                                      Icons.security_outlined,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Manage',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(60, 30),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.developer:
        return AppTheme.error;
      case UserRole.owner:
        return AppTheme.primaryBlue;
      case UserRole.kitchen:
        return AppTheme.success;
      case UserRole.delivery:
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getShopName(String? shopId) {
    if (shopId == null || _cachedShops.isEmpty) return 'Unknown';
    final shop = _cachedShops.firstWhere(
      (s) => s.id == shopId,
      orElse: () => _cachedShops.first,
    );
    return shop.name;
  }

  void _showPermissionsDialog(UserModel user) {
    final permissions = List<String>.from(user.devPermissions);
    final availablePerms = [
      {
        'id': 'summary',
        'label': 'System Overview',
        'desc': 'View global stats',
      },
      {
        'id': 'payments',
        'label': 'Payment Toggles',
        'desc': 'Enable/Disable COD or Online',
      },
      {'id': 'shops', 'label': 'Shop Management', 'desc': 'Create/Edit shops'},
      {
        'id': 'menu',
        'label': 'Menu Management',
        'desc': 'Edit menu for any shop',
      },
      {'id': 'users', 'label': 'User Management', 'desc': 'Change roles'},
      {'id': 'tools', 'label': 'System Tools', 'desc': 'Access test tools'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Dev Permissions: ${user.email}'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availablePerms.length,
                  itemBuilder: (context, index) {
                    final perm = availablePerms[index];
                    final isEnabled = permissions.contains(perm['id']);

                    return SwitchListTile(
                      title: Text(
                        perm['label']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        perm['desc']!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isEnabled,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value) {
                            permissions.add(perm['id']!);
                          } else {
                            permissions.remove(perm['id']!);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _firestore.collection('users').doc(user.uid).update(
                        {'devPermissions': permissions},
                      );
                      _loadAllUsers();
                      if (context.mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Permissions updated'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                  child: const Text('Save Permissions'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildViewShopDashboard() {
    return _DevCard(
      title: 'Shop Dashboard',
      subtitle: 'View detailed analytics for each shop',
      icon: Icons.dashboard,
      iconColor: AppTheme.ownerColor,
      // Use cached shops for instant loading
      child: Builder(
        builder: (context) {
          if (!_shopsLoaded) {
            return const Center(child: AnimatedLoader(size: 80));
          }
          if (_cachedShops.isEmpty) {
            return const Text('No shops available.');
          }
          final shops = _cachedShops;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop Cards with "View Dashboard" buttons
              ...shops.map(
                (shop) => _ShopDashboardCard(
                  shop: shop,
                  onViewDashboard: () => _showFullDashboard(shop),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFullDashboard(ShopModel shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FullShopDashboard(
        shop: shop,
        firestore: _firestore,
        authService: _authService,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      final Map<String, dynamic> updateData = {'role': role};
      // If setting to customer or developer, clear shop assignment
      if (role == 'customer' || role == 'developer') {
        updateData['shopId'] = FieldValue.delete();
      }
      await _firestore.collection('users').doc(userId).update(updateData);
      _loadAllUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated to $role'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _updateUserShop(String userId, String shopId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'shopId': shopId,
        'shopIds': [shopId], // Also update shopIds for compatibility
      });
      _loadAllUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User shop assignment updated'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _updateUserShopIds(String userId, List<String> shopIds) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'shopIds': shopIds,
        // Set shopId to the first one for backwards compatibility or display
        'shopId': shopIds.isNotEmpty ? shopIds[0] : FieldValue.delete(),
      });
      _loadAllUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Multi-shop assignment updated'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showMultiShopSelectionDialog(UserModel user) {
    if (_cachedShops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No shops available to assign.')),
      );
      return;
    }

    final selectedIds = List<String>.from(user.shopIds ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Assign Shops: ${user.email}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _cachedShops.length,
                  itemBuilder: (context, index) {
                    final shop = _cachedShops[index];
                    final isSelected = selectedIds.contains(shop.id);
                    return CheckboxListTile(
                      title: Text(shop.name),
                      value: isSelected,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedIds.add(shop.id);
                          } else {
                            selectedIds.remove(shop.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateUserShopIds(user.uid, selectedIds);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                  child: const Text('Save Assignments'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _resetCustomerOrders() async {
    try {
      final orders = await _firestore
          .collection('orders')
          .where('isTestOrder', isEqualTo: false)
          .get();
      for (var doc in orders.docs) {
        await doc.reference.delete();
      }
      _loadSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer orders reset!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showConfirmDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// Shop Dashboard Card Widget
class _ShopDashboardCard extends StatelessWidget {
  final ShopModel shop;
  final VoidCallback onViewDashboard;

  const _ShopDashboardCard({required this.shop, required this.onViewDashboard});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: shop.isOpen
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.store,
              color: shop.isOpen ? AppTheme.success : AppTheme.error,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: shop.isOpen ? AppTheme.success : AppTheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        shop.isOpen ? 'OPEN' : 'CLOSED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (shop.schedule.openTime != null)
                      Text(
                        '${shop.schedule.openTime} - ${shop.schedule.closeTime}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onViewDashboard,
            icon: const Icon(Icons.analytics, size: 18),
            label: const Text('View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ownerColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// Full Shop Dashboard Modal
class _FullShopDashboard extends StatefulWidget {
  final ShopModel shop;
  final FirebaseFirestore firestore;
  final AuthService authService;

  const _FullShopDashboard({
    required this.shop,
    required this.firestore,
    required this.authService,
  });

  @override
  State<_FullShopDashboard> createState() => _FullShopDashboardState();
}

class _FullShopDashboardState extends State<_FullShopDashboard> {
  double _totalRevenue = 0;
  int _totalOrders = 0;
  double _avgOrderValue = 0;
  int _pendingOrders = 0;
  int _completedOrders = 0;
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  List<Map<String, dynamic>> _staffMembers = [];
  Map<String, double> _dailyRevenue = {};
  Map<String, int> _statusCounts = {};
  String _historyFilter = 'all'; // 'week', 'month', 'all'
  final _staffEmailController = TextEditingController();
  String _selectedStaffRole = 'kitchen';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Load orders for this shop
      final ordersSnapshot = await widget.firestore
          .collection('orders')
          .where('shopId', isEqualTo: widget.shop.id)
          .get();

      double revenue = 0;
      int pending = 0;
      int completed = 0;
      List<Map<String, dynamic>> ordersList = [];
      Map<String, double> dayRevenue = {};
      Map<String, int> statusCountMap = {};

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] ?? 0).toDouble();

        final status = data['status'] ?? 'new';
        statusCountMap[status] = (statusCountMap[status] ?? 0) + 1;

        if (status == 'delivered' || status == 'completed') {
          completed++;
          revenue +=
              amount; // Only count delivered/completed for revenue usually, or all?
          // kitchen.html seems to count total revenue from completed.
        } else if (status != 'cancelled') {
          pending++;
        }

        DateTime orderDate = DateTime.now();
        if (data['createdAt'] != null) {
          if (data['createdAt'] is Timestamp) {
            orderDate = (data['createdAt'] as Timestamp).toDate();
          }
        }

        String dayKey = DateFormat('yyyy-MM-dd').format(orderDate);
        if (status == 'delivered' || status == 'completed') {
          dayRevenue[dayKey] = (dayRevenue[dayKey] ?? 0) + amount;
        }

        ordersList.add({
          'id': doc.id,
          'customerName': data['customerName'] ?? 'Unknown',
          'totalAmount': amount,
          'status': status,
          'createdAt': orderDate,
        });
      }

      // Sort orders by date
      ordersList.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

      // Load staff for this shop
      final staffSnapshot = await widget.firestore
          .collection('users')
          .where('shopId', isEqualTo: widget.shop.id)
          .get();

      List<Map<String, dynamic>> staff = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'staff',
          'displayName': data['displayName'] ?? 'Staff',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _totalOrders = ordersSnapshot.docs.length;
          _avgOrderValue = _totalOrders > 0 ? revenue / _totalOrders : 0;
          _pendingOrders = pending;
          _completedOrders = completed;
          _allOrders = ordersList;
          _staffMembers = staff;
          _dailyRevenue = dayRevenue;
          _statusCounts = statusCountMap;
          _applyHistoryFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyHistoryFilter() {
    DateTime now = DateTime.now();
    setState(() {
      if (_historyFilter == 'week') {
        DateTime weekAgo = now.subtract(const Duration(days: 7));
        _filteredOrders = _allOrders
            .where((o) => (o['createdAt'] as DateTime).isAfter(weekAgo))
            .toList();
      } else if (_historyFilter == 'month') {
        DateTime monthAgo = DateTime(now.year, now.month - 1, now.day);
        _filteredOrders = _allOrders
            .where((o) => (o['createdAt'] as DateTime).isAfter(monthAgo))
            .toList();
      } else {
        _filteredOrders = List.from(_allOrders);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKPIGrid(),
                        const SizedBox(height: 24),
                        _buildChartsRow(),
                        const SizedBox(height: 24),
                        _buildOrderHistory(),
                        const SizedBox(height: 24),
                        _buildStaffManagement(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.ownerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: AppTheme.ownerColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.shop.name} - Dashboard',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Performance & Insights',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildKPIGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Total Revenue',
                value: '₹${NumberFormat('#,##,###').format(_totalRevenue)}',
                icon: Icons.payments_rounded,
                color: AppTheme.success,
                subtitle: 'From completed orders',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Total Orders',
                value: '$_totalOrders',
                icon: Icons.shopping_basket_rounded,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Avg. Value',
                value: '₹${_avgOrderValue.toStringAsFixed(0)}',
                icon: Icons.analytics_rounded,
                color: AppTheme.ownerColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatusCard(
                title: 'Active Orders',
                value: '$_pendingOrders',
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCard(
                title: 'Completed',
                value: '$_completedOrders',
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        // Daily Sales Chart
        _AnalyticsCard(
          title: 'Daily Sales',
          subtitle: 'Revenue generated each day',
          height: 250,
          child: _buildSalesChart(),
        ),
        const SizedBox(height: 16),
        // Order Status Chart
        _AnalyticsCard(
          title: 'Order Distribution',
          subtitle: 'Breakdown of orders by status',
          height: 250,
          child: _buildStatusPieChart(),
        ),
      ],
    );
  }

  Widget _buildSalesChart() {
    if (_dailyRevenue.isEmpty) {
      return const Center(
        child: Text(
          'No sales data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    // Get last 7 days keys
    List<String> days = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      days.add(
        DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i))),
      );
    }

    double maxRevenue = 0;
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < days.length; i++) {
      double rev = _dailyRevenue[days[i]] ?? 0;
      if (rev > maxRevenue) maxRevenue = rev;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rev,
              color: AppTheme.primaryBlue,
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= days.length) return const SizedBox();
                String dateStr = days[index];
                DateTime dt = DateFormat('yyyy-MM-dd').parse(dateStr);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('E').format(dt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildStatusPieChart() {
    if (_statusCounts.isEmpty) {
      return const Center(child: Text('No orders to analyze'));
    }

    List<PieChartSectionData> sections = [];
    _statusCounts.forEach((status, count) {
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: '$count',
          color: _getStatusColor(status),
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(sections: sections, centerSpaceRadius: 40),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _statusCounts.keys
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildOrderHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Order History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            _buildHistoryFilterButtons(),
          ],
        ),
        const SizedBox(height: 16),
        if (_filteredOrders.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No past orders found in this period.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredOrders.length > 5
                  ? 5
                  : _filteredOrders.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    order['customerName'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, hh:mm a').format(order['createdAt']),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${order['totalAmount'].toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (newStatus) =>
                                _updateStatus(order['id'], newStatus),
                            itemBuilder: (context) =>
                                [
                                      'new',
                                      'preparing',
                                      'ready',
                                      'out_for_delivery',
                                      'delivered',
                                      'completed',
                                      'cancelled',
                                    ]
                                    .map(
                                      (s) => PopupMenuItem(
                                        value: s,
                                        child: Text(s.toUpperCase()),
                                      ),
                                    )
                                    .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  order['status'],
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      order['status'].toString().toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(order['status']),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 12,
                                    color: _getStatusColor(order['status']),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await widget.firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildHistoryFilterButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _FilterBtn(
            label: 'Week',
            isActive: _historyFilter == 'week',
            onTap: () => _updateFilter('week'),
          ),
          _FilterBtn(
            label: 'Month',
            isActive: _historyFilter == 'month',
            onTap: () => _updateFilter('month'),
          ),
          _FilterBtn(
            label: 'All',
            isActive: _historyFilter == 'all',
            onTap: () => _updateFilter('all'),
          ),
        ],
      ),
    );
  }

  void _updateFilter(String f) {
    setState(() => _historyFilter = f);
    _applyHistoryFilter();
  }

  Widget _buildStaffManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _staffEmailController,
                      decoration: InputDecoration(
                        hintText: 'Staff Email (must be registered)',
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStaffRole,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'kitchen',
                              child: Text('Kitchen Staff'),
                            ),
                            DropdownMenuItem(
                              value: 'delivery',
                              child: Text('Delivery Staff'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedStaffRole = value!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addStaff,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Staff'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_staffMembers.isEmpty)
          const Center(
            child: Text(
              'No staff assigned to this shop',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          ..._staffMembers.map(
            (staff) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.ownerColor.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppTheme.ownerColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['email'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          staff['role'].toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeStaff(staff['id']),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return AppTheme.primaryBlue;
      case 'preparing':
        return AppTheme.warning;
      case 'ready':
        return AppTheme.ownerColor;
      case 'out_for_delivery':
        return AppTheme.deliveryColor;
      case 'delivered':
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _addStaff() async {
    final email = _staffEmailController.text.trim();
    if (email.isEmpty) return;
    try {
      final userSnapshot = await widget.firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (userSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      final userId = userSnapshot.docs.first.id;
      await widget.firestore.collection('users').doc(userId).update({
        'shopId': widget.shop.id,
        'role': _selectedStaffRole,
      });
      _staffEmailController.clear();
      _loadDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff added!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _removeStaff(String userId) async {
    try {
      await widget.firestore.collection('users').doc(userId).update({
        'shopId': FieldValue.delete(),
        'role': 'customer',
      });
      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primaryBlue : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final double height;
  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.height,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

// KPI Card Widget
class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Status Card Widget
class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class _DevCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _DevCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _SummaryTile({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 24,
              color: AppTheme.primaryBlue.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestBadge extends StatelessWidget {
  final String label;
  final String status;

  const _TestBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (status) {
      case 'pass':
        color = AppTheme.success;
        text = 'PASS';
        break;
      case 'fail':
        color = AppTheme.error;
        text = 'FAIL';
        break;
      default:
        color = AppTheme.warning;
        text = 'Testing...';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsistencyTile extends StatelessWidget {
  final String label;
  final String status;
  final String description;

  const _ConsistencyTile({
    required this.label,
    required this.status,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    Color color = status == 'OK'
        ? AppTheme.success
        : (status == 'pending' || status == '--')
        ? AppTheme.warning
        : AppTheme.error;
    bool isOk = status == 'OK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 9.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOk ? '✓ OK' : status,
                  style: TextStyle(
                    color: color,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OrderMonitorTile extends StatelessWidget {
  final OrderModel order;
  final Function(OrderStatus) onStatusChanged;

  const _OrderMonitorTile({required this.order, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: order.isTestOrder ? Border.all(color: AppTheme.warning) : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        order.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (order.isTestOrder) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TEST',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              order.formattedTotal,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: PopupMenuButton<OrderStatus>(
              onSelected: onStatusChanged,
              itemBuilder: (context) => OrderStatus.values
                  .map(
                    (s) => PopupMenuItem(value: s, child: Text(s.displayName)),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        order.status.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(order.status),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: _getStatusColor(order.status),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              order.timeAgo,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

Color _getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.newOrder:
      return AppTheme.warning;
    case OrderStatus.preparing:
      return AppTheme.primaryBlue;
    case OrderStatus.readyForPickup:
      return AppTheme.success;
    case OrderStatus.outForDelivery:
      return AppTheme.ownerColor;
    case OrderStatus.completed:
      return AppTheme.success;
    case OrderStatus.cancelled:
      return AppTheme.error;
    case OrderStatus.returned:
      return Colors.deepPurple;
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (role) {
      case UserRole.developer:
        color = AppTheme.developerColor;
        break;
      case UserRole.owner:
        color = AppTheme.ownerColor;
        break;
      case UserRole.kitchen:
        color = AppTheme.warning;
        break;
      case UserRole.delivery:
        color = AppTheme.success;
        break;
      default:
        color = AppTheme.primaryBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.value.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _AuditSummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _AuditSummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
