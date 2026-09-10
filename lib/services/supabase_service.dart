import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Centralized Supabase Database Service
/// Connects to the same PostgreSQL Cloud database as Foody Vrinda Web v3
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isInitialized = false;

  /// Get active Supabase Client
  SupabaseClient get client {
    if (_client != null) return _client!;
    try {
      _client = Supabase.instance.client;
      _isInitialized = true;
      return _client!;
    } catch (_) {
      throw Exception('Supabase has not been initialized. Call SupabaseService.init() in main()');
    }
  }

  bool get isInitialized => _isInitialized;

  /// Initialize Supabase Flutter SDK
  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      _instance._client = Supabase.instance.client;
      _instance._isInitialized = true;
      print('SupabaseService: Successfully connected to Foody Vrinda Database');
    } catch (e) {
      print('SupabaseService: Initialization notice (may already be initialized): $e');
    }
  }

  // ==========================================
  // SHOPS & KITCHENS (foody_shops)
  // ==========================================

  /// Fetch all active shops
  Future<List<Map<String, dynamic>>> getShops() async {
    try {
      final res = await client
          .from(SupabaseConfig.shopsTable)
          .select('*')
          .order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('SupabaseService.getShops error: $e');
      // Fallback try with 'shops' table
      try {
        final res = await client.from('shops').select('*');
        return List<Map<String, dynamic>>.from(res);
      } catch (_) {
        return [];
      }
    }
  }

  /// Real-time stream of all shops
  Stream<List<Map<String, dynamic>>> streamShops() {
    try {
      return client
          .from(SupabaseConfig.shopsTable)
          .stream(primaryKey: ['id'])
          .map((data) => List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('SupabaseService.streamShops error: $e');
      return Stream.value([]);
    }
  }

  /// Get shop by ID
  Future<Map<String, dynamic>?> getShopById(String shopId) async {
    try {
      final res = await client
          .from(SupabaseConfig.shopsTable)
          .select('*')
          .eq('id', shopId)
          .maybeSingle();
      return res;
    } catch (e) {
      print('SupabaseService.getShopById error: $e');
      return null;
    }
  }

  /// Create shop
  Future<Map<String, dynamic>?> createShop(Map<String, dynamic> shopData) async {
    try {
      final res = await client.from(SupabaseConfig.shopsTable).insert(shopData).select().maybeSingle();
      return res;
    } catch (e) {
      print('SupabaseService.createShop error: $e');
      return null;
    }
  }

  /// Update shop
  Future<void> updateShop(String shopId, Map<String, dynamic> updates) async {
    try {
      await client.from(SupabaseConfig.shopsTable).update(updates).eq('id', shopId);
    } catch (e) {
      print('SupabaseService.updateShop error: $e');
    }
  }

  /// Delete shop
  Future<void> deleteShop(String shopId) async {
    try {
      await client.from(SupabaseConfig.shopsTable).delete().eq('id', shopId);
    } catch (e) {
      print('SupabaseService.deleteShop error: $e');
    }
  }

  // ==========================================
  // MENU ITEMS & COMBOS (foody_menus)
  // ==========================================

  /// Fetch all menu items or by shop
  Future<List<Map<String, dynamic>>> getMenus({String shopId = 'all'}) async {
    try {
      var query = client.from(SupabaseConfig.menusTable).select('*');
      if (shopId != 'all') {
        query = query.eq('shop_id', shopId);
      }
      final res = await query.order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('SupabaseService.getMenus error: $e');
      return [];
    }
  }

  /// Create menu / combo item
  Future<Map<String, dynamic>?> createMenuItem(Map<String, dynamic> itemData) async {
    try {
      final res = await client.from(SupabaseConfig.menusTable).insert(itemData).select().maybeSingle();
      return res;
    } catch (e) {
      print('SupabaseService.createMenuItem error: $e');
      return null;
    }
  }

  /// Update menu item
  Future<void> updateMenuItem(String itemId, Map<String, dynamic> updates) async {
    try {
      await client.from(SupabaseConfig.menusTable).update(updates).eq('id', itemId);
    } catch (e) {
      print('SupabaseService.updateMenuItem error: $e');
    }
  }

  /// Delete menu item
  Future<void> deleteMenuItem(String itemId) async {
    try {
      await client.from(SupabaseConfig.menusTable).delete().eq('id', itemId);
    } catch (e) {
      print('SupabaseService.deleteMenuItem error: $e');
    }
  }

  // ==========================================
  // OFFERS & PROMOTIONS (foody_offers)
  // ==========================================

  /// Fetch active offers
  Future<List<Map<String, dynamic>>> getOffers({String shopId = 'all'}) async {
    try {
      var query = client.from(SupabaseConfig.offersTable).select('*');
      if (shopId != 'all') {
        query = query.or('shop_id.eq.$shopId,shop_id.eq.all,shop_id.is.null');
      }
      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('SupabaseService.getOffers error: $e');
      return [];
    }
  }

  /// Create promo offer
  Future<Map<String, dynamic>?> createOffer(Map<String, dynamic> offerData) async {
    try {
      final res = await client.from(SupabaseConfig.offersTable).insert(offerData).select().maybeSingle();
      return res;
    } catch (e) {
      print('SupabaseService.createOffer error: $e');
      return null;
    }
  }

  /// Update promo offer
  Future<void> updateOffer(String offerId, Map<String, dynamic> updates) async {
    try {
      await client.from(SupabaseConfig.offersTable).update(updates).eq('id', offerId);
    } catch (e) {
      print('SupabaseService.updateOffer error: $e');
    }
  }

  /// Delete promo offer
  Future<void> deleteOffer(String offerId) async {
    try {
      await client.from(SupabaseConfig.offersTable).delete().eq('id', offerId);
    } catch (e) {
      print('SupabaseService.deleteOffer error: $e');
    }
  }

  /// Fetch menu items for a shop
  Future<List<Map<String, dynamic>>> getMenuItems(String shopId) async {
    try {
      final res = await client
          .from(SupabaseConfig.menusTable)
          .select('*')
          .eq('shop_id', shopId)
          .eq('is_available', true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('SupabaseService.getMenuItems error: $e');
      // Fallback try without filter or with 'menus' table
      try {
        final res = await client
            .from('menus')
            .select('*')
            .eq('shopId', shopId);
        return List<Map<String, dynamic>>.from(res);
      } catch (_) {
        return [];
      }
    }
  }

  /// Real-time stream of menu items for a shop
  Stream<List<Map<String, dynamic>>> streamMenuItems(String shopId) {
    try {
      return client
          .from(SupabaseConfig.menusTable)
          .stream(primaryKey: ['id'])
          .eq('shop_id', shopId)
          .map((data) => List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('SupabaseService.streamMenuItems error: $e');
      return Stream.value([]);
    }
  }

  // ==========================================
  // ORDERS (foody_orders)
  // ==========================================

  /// Create a new order in Supabase
  Future<String> createOrder(Map<String, dynamic> orderData) async {
    try {
      final orderId = orderData['id'] ??
          'order-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}';

      final Map<String, dynamic> payload = {
        'id': orderId,
        'shop_id': orderData['shopId'] ?? orderData['shop_id'] ?? 'shop-vrinda-main',
        'user_id': orderData['userId'] ?? orderData['user_id'] ?? 'guest',
        'customer_name': orderData['customerName'] ?? orderData['customer_name'] ?? 'Devotee',
        'customer_phone': orderData['customerPhone'] ?? orderData['customer_phone'] ?? '',
        'customer_address': orderData['deliveryAddress'] ?? orderData['customer_address'] ?? '',
        'delivery_address': orderData['deliveryAddress'] ?? orderData['delivery_address'] ?? '',
        'delivery_coordinates': orderData['deliveryCoordinates'] ??
            orderData['delivery_coordinates'] ??
            {
              'lat': orderData['customerLatitude'] ?? 27.5706,
              'lng': orderData['customerLongitude'] ?? 77.6593,
            },
        'items': orderData['items'] ?? [],
        'subtotal': orderData['subtotal'] ?? 0,
        'delivery_charge': orderData['deliveryCharge'] ?? orderData['delivery_charge'] ?? 0,
        'gst_amount': orderData['gstAmount'] ?? orderData['gst_amount'] ?? 0,
        'total_amount': orderData['totalAmount'] ?? orderData['total_amount'] ?? 0,
        'status': orderData['status'] ?? 'new',
        'payment_method': orderData['paymentMethod'] ?? orderData['payment_method'] ?? 'cash',
        'payment_id': orderData['paymentId'] ?? orderData['payment_id'],
        'cash_status': orderData['cashStatus'] ?? orderData['cash_status'] ?? 'pending',
        'cooking_notes': orderData['cookingNotes'] ?? orderData['cooking_notes'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await client.from(SupabaseConfig.ordersTable).insert(payload);
      print('SupabaseService: Order created with ID $orderId');
      return orderId;
    } catch (e) {
      print('SupabaseService.createOrder error: $e');
      rethrow;
    }
  }

  /// Get single order by ID
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final res = await client
          .from(SupabaseConfig.ordersTable)
          .select('*')
          .eq('id', orderId)
          .maybeSingle();
      return res;
    } catch (e) {
      print('SupabaseService.getOrder error: $e');
      return null;
    }
  }

  /// Stream single order for real-time tracking
  Stream<Map<String, dynamic>?> streamOrder(String orderId) {
    try {
      return client
          .from(SupabaseConfig.ordersTable)
          .stream(primaryKey: ['id'])
          .eq('id', orderId)
          .map((data) => data.isNotEmpty ? data.first : null);
    } catch (e) {
      print('SupabaseService.streamOrder error: $e');
      return Stream.value(null);
    }
  }

  /// Stream orders for a customer or shop
  Stream<List<Map<String, dynamic>>> streamOrders({String? shopId, String? userId}) {
    try {
      var query = client.from(SupabaseConfig.ordersTable).stream(primaryKey: ['id']);
      if (shopId != null && shopId.isNotEmpty) {
        query = query.eq('shop_id', shopId);
      } else if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }
      return query.map((data) => List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('SupabaseService.streamOrders error: $e');
      return Stream.value([]);
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    Map<String, dynamic>? extraFields,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...?extraFields,
      };

      await client
          .from(SupabaseConfig.ordersTable)
          .update(updateData)
          .eq('id', orderId);
    } catch (e) {
      print('SupabaseService.updateOrderStatus error: $e');
      rethrow;
    }
  }

  // ==========================================
  // USERS & PROFILES (foody_logged_users & foody_users)
  // ==========================================

  /// Fetch all cloud users from Supabase (merges foody_logged_users & foody_users)
  Future<List<Map<String, dynamic>>> getCloudUsers() async {
    final Map<String, Map<String, dynamic>> userMap = {};

    // 1. Fetch from foody_users
    try {
      final resUsers = await client
          .from(SupabaseConfig.usersTable)
          .select('*')
          .order('updated_at', ascending: false);
      for (final u in List<Map<String, dynamic>>.from(resUsers)) {
        final id = (u['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          userMap[id] = u;
        }
      }
    } catch (e) {
      print('SupabaseService.getCloudUsers usersTable notice: $e');
    }

    // 2. Fetch from foody_logged_users (active logins take priority)
    try {
      final resLogged = await client
          .from(SupabaseConfig.loggedUsersTable)
          .select('*')
          .order('updated_at', ascending: false);
      for (final u in List<Map<String, dynamic>>.from(resLogged)) {
        final id = (u['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          userMap[id] = u;
        }
      }
    } catch (e) {
      print('SupabaseService.getCloudUsers loggedUsersTable notice: $e');
    }

    return userMap.values.toList();
  }

  /// Get live user profile by ID, Email, or Phone
  Future<Map<String, dynamic>?> getLiveUserRoleAndProfile({
    String? userId,
    String? email,
    String? phone,
  }) async {
    final cleanId = userId?.trim() ?? '';
    final cleanEmail = email?.toLowerCase().trim() ?? '';
    final cleanPhone = phone?.replaceAll(RegExp(r'\D'), '') ?? '';

    if (cleanId.isEmpty && cleanEmail.isEmpty && cleanPhone.isEmpty) return null;

    try {
      var query = client.from(SupabaseConfig.loggedUsersTable).select('*');
      if (cleanId.isNotEmpty) {
        query = query.eq('id', cleanId);
      } else if (cleanEmail.isNotEmpty) {
        query = query.eq('email', cleanEmail);
      } else if (cleanPhone.length >= 10) {
        query = query.eq('phone', cleanPhone);
      }
      final res = await query.maybeSingle();
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (e) {
      print('SupabaseService.getLiveUserRoleAndProfile logged_users notice: $e');
    }

    // Fallback to foody_users table
    try {
      var query = client.from(SupabaseConfig.usersTable).select('*');
      if (cleanId.isNotEmpty) {
        query = query.eq('id', cleanId);
      } else if (cleanEmail.isNotEmpty) {
        query = query.eq('email', cleanEmail);
      } else if (cleanPhone.length >= 10) {
        query = query.eq('phone', cleanPhone);
      }
      final res = await query.maybeSingle();
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (_) {}

    return null;
  }

  /// Phone lookup sign in - matches web behavior exactly
  Future<Map<String, dynamic>> loginWithPhoneLookup(String phoneInput) async {
    final clean = phoneInput.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10) {
      throw Exception('Please enter a valid 10-digit mobile number.');
    }

    final target10 = clean.substring(clean.length - 10);

    // 1. Search existing users
    try {
      final allUsers = await getCloudUsers();
      final existing = allUsers.cast<Map<String, dynamic>?>().firstWhere(
        (u) {
          final uPhone = (u?['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
          return uPhone.endsWith(target10);
        },
        orElse: () => null,
      );

      if (existing != null) {
        // Record login time in both tables
        final nowIso = DateTime.now().toUtc().toIso8601String();
        updateCloudUser(existing['id'], {
          'last_login_at': nowIso,
          'updated_at': nowIso,
        }).catchError((_) {});
        return Map<String, dynamic>.from(existing);
      }
    } catch (e) {
      print('SupabaseService.loginWithPhoneLookup query notice: $e');
    }

    // 2. Auto-provision new customer account if not found
    final newUserId = 'user-${DateTime.now().millisecondsSinceEpoch}-${clean.substring(clean.length - 4)}';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newCustomer = <String, dynamic>{
      'id': newUserId,
      'phone': target10,
      'display_name': 'Customer (${clean.substring(clean.length - 4)})',
      'email': '',
      'role': 'customer',
      'shop_id': 'shop-vrinda-main',
      'shop_ids': ['shop-vrinda-main'],
      'created_at': nowIso,
      'last_login_at': nowIso,
      'updated_at': nowIso,
    };

    try {
      await client.from(SupabaseConfig.loggedUsersTable).upsert(newCustomer);
    } catch (e) {
      print('SupabaseService upsert into loggedUsersTable notice: $e');
    }

    try {
      await client.from(SupabaseConfig.usersTable).upsert({
        'id': newUserId,
        'phone': target10,
        'display_name': newCustomer['display_name'],
        'email': '',
        'role': 'customer',
        'shop_id': 'shop-vrinda-main',
        'shop_ids': ['shop-vrinda-main'],
        'created_at': nowIso,
        'last_seen_at': nowIso,
        'updated_at': nowIso,
      });
    } catch (e) {
      print('SupabaseService upsert into usersTable notice: $e');
    }

    return newCustomer;
  }

  /// Create new cloud user
  Future<Map<String, dynamic>> createCloudUser(Map<String, dynamic> userProfile) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final userId = userProfile['id'] ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    final cleanEmail = (userProfile['email'] ?? '').toString().trim().toLowerCase();
    final cleanPhone = (userProfile['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final cleanDisplayName = userProfile['displayName'] ?? userProfile['display_name'] ?? (cleanEmail.isNotEmpty ? cleanEmail.split('@')[0] : 'Devotee');
    final cleanRole = userProfile['role'] ?? 'customer';
    final cleanShopId = userProfile['shopId'] ?? userProfile['shop_id'] ?? 'shop-vrinda-main';
    final cleanShopIds = userProfile['shopIds'] ?? userProfile['shop_ids'] ?? [cleanShopId];

    final loggedPayload = {
      'id': userId,
      'email': cleanEmail,
      'display_name': cleanDisplayName,
      'phone': cleanPhone,
      'avatar_url': userProfile['avatarUrl'] ?? userProfile['avatar_url'] ?? '',
      'role': cleanRole,
      'shop_id': cleanShopId,
      'shop_ids': cleanShopIds,
      'created_at': nowIso,
      'last_login_at': nowIso,
      'updated_at': nowIso,
    };

    final standardPayload = {
      'id': userId,
      'email': cleanEmail,
      'display_name': cleanDisplayName,
      'phone': cleanPhone,
      'avatar_url': userProfile['avatarUrl'] ?? userProfile['avatar_url'] ?? '',
      'role': cleanRole,
      'shop_id': cleanShopId,
      'shop_ids': cleanShopIds,
      'created_at': nowIso,
      'last_seen_at': nowIso,
      'updated_at': nowIso,
    };

    try {
      await client.from(SupabaseConfig.loggedUsersTable).upsert(loggedPayload);
    } catch (e) {
      print('SupabaseService.createCloudUser logged_users notice: $e');
    }

    try {
      await client.from(SupabaseConfig.usersTable).upsert(standardPayload);
    } catch (e) {
      print('SupabaseService.createCloudUser users notice: $e');
    }

    return loggedPayload;
  }

  /// Update user in Supabase cloud
  Future<void> updateCloudUser(String userId, Map<String, dynamic> updates) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = Map<String, dynamic>.from(updates);
    payload['updated_at'] = nowIso;

    try {
      await client
          .from(SupabaseConfig.loggedUsersTable)
          .update(payload)
          .eq('id', userId);
    } catch (e) {
      print('SupabaseService.updateCloudUser loggedUsersTable notice: $e');
    }

    try {
      await client
          .from(SupabaseConfig.usersTable)
          .update(payload)
          .eq('id', userId);
    } catch (e) {
      print('SupabaseService.updateCloudUser usersTable notice: $e');
    }
  }

  /// Get or sync user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return getLiveUserRoleAndProfile(userId: userId);
  }

  /// Upsert user profile
  Future<void> upsertUserProfile(Map<String, dynamic> profile) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final userId = profile['id'] ?? profile['uid'] ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    final cleanEmail = (profile['email'] ?? '').toString().trim().toLowerCase();
    final cleanPhone = (profile['phone'] ?? profile['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final cleanName = profile['displayName'] ?? profile['display_name'] ?? profile['name'] ?? 'Devotee';
    final cleanRole = profile['role'] ?? 'customer';
    final cleanShopId = profile['shopId'] ?? profile['shop_id'] ?? 'shop-vrinda-main';

    final profilePayload = {
      'id': userId,
      'email': cleanEmail,
      'display_name': cleanName,
      'phone': cleanPhone,
      'avatar_url': profile['avatar_url'] ?? profile['photoURL'] ?? '',
      'role': cleanRole,
      'shop_id': cleanShopId,
      'updated_at': nowIso,
    };

    try {
      await client.from(SupabaseConfig.loggedUsersTable).upsert(profilePayload);
    } catch (e) {
      print('SupabaseService.upsertUserProfile loggedUsersTable notice: $e');
    }

    try {
      await client.from(SupabaseConfig.usersTable).upsert(profilePayload);
    } catch (e) {
      print('SupabaseService.upsertUserProfile usersTable notice: $e');
    }
  }
}
