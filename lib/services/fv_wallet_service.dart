import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fv_wallet_model.dart';
import 'supabase_service.dart';

/// Centralized FV Wallet & Dynasty Service for Flutter
/// Maintains 100% schema parity with Foody Vrinda Web v3
class FVWalletService {
  static final FVWalletService _instance = FVWalletService._internal();
  factory FVWalletService() => _instance;
  FVWalletService._internal();

  SupabaseClient get _client => SupabaseService().client;

  // Conversion rates (1 FV Point = ₹0.10)
  static const double exchangeRate = 0.10;
  static const double pointsPerRupee = 10.0;

  double pointsToRupees(double points) =>
      double.parse((points * exchangeRate).toStringAsFixed(2));

  double rupeesToPoints(double rupees) => (rupees * pointsPerRupee).ceilToDouble();

  /// Privacy-compliant display name mask for public leaderboards
  /// Prevents leaking full names, student IDs, phone numbers, or email handles
  static String maskLeaderboardName(String? name, [bool isSelf = false]) {
    if (isSelf) return name != null && name.trim().isNotEmpty ? name.trim() : 'You';
    if (name == null || name.trim().isEmpty) return 'Foody Devotee';

    String clean = name.trim();

    // 1. Strip student roll number / alphanumeric registration IDs (e.g., '24F2004883 Bajrangi SHARMA')
    clean = clean.replaceFirst(RegExp(r'^[0-9][0-9A-Za-z_-]{4,}\s+', caseSensitive: false), '');

    // 2. Strip internal user role wrappers
    if (clean.toLowerCase().contains('chef_')) return 'Kitchen Chef';
    if (clean.toLowerCase().startsWith('user (')) {
      clean = clean.replaceFirst(RegExp(r'^user\s*\((.*?)\)', caseSensitive: false), r'$1');
    }

    // 3. Test/Auto-generated accounts with trailing digits (e.g. 'vrindatest31514')
    if (RegExp(r'^[a-zA-Z]+[0-9]{3,}$').hasMatch(clean)) {
      return 'Devotee •••${clean.substring(clean.length - 3)}';
    }

    // 4. Phone numbers
    final digitsOnly = clean.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 10) {
      return 'Devotee •••${digitsOnly.substring(digitsOnly.length - 4)}';
    }

    // 5. Email addresses
    if (clean.contains('@')) {
      final userPart = clean.split('@').first;
      return 'Devotee •••${userPart.length >= 3 ? userPart.substring(userPart.length - 3) : userPart}';
    }

    // 6. Multi-word names: First name + Last name initial masked (e.g. 'Kunvar Singh' -> 'Kunvar S***')
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0];
      final lastInitial = parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
      return '$first $lastInitial***';
    }

    // 7. Single word names (e.g. 'Bajrangi' -> 'Baj***')
    if (clean.length > 3) {
      return '${clean.substring(0, 3)}***';
    }

    return '$clean***';
  }

  /// Provision wallet for user upon signup with referral code
  Future<Map<String, dynamic>> initUserWallet(
    String userId, {
    String? referralCode,
    String channel = 'direct',
  }) async {
    try {
      final res = await _client.rpc('create_wallet_on_signup', params: {
        'p_user_id': userId,
        'p_referral_code': referralCode?.trim(),
        'p_channel': channel,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('FVWalletService.initUserWallet error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get complete wallet dashboard (balances, ledger, and referral summary)
  Future<FVWalletModel?> getWalletDashboard(String userId, {bool forceFresh = false}) async {
    try {
      final res = await _client.rpc('get_wallet_dashboard', params: {
        'p_user_id': userId,
      });

      if (res != null && res is Map) {
        return FVWalletModel.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (e) {
      print('FVWalletService.getWalletDashboard error: $e');
      return null;
    }
  }

  /// Redeem FV Points against an order at checkout
  Future<Map<String, dynamic>> redeemPoints({
    required String userId,
    required double points,
    required String orderId,
  }) async {
    try {
      final res = await _client.rpc('redeem_fv_points', params: {
        'p_user_id': userId,
        'p_points_to_redeem': points,
        'p_order_id': orderId,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('FVWalletService.redeemPoints error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch Leaderboard rankings
  Future<List<FVLeaderboardItem>> getLeaderboard({
    String period = 'all_time',
    String role = 'customer',
    int limit = 10,
  }) async {
    try {
      final res = await _client.rpc('get_fv_leaderboard', params: {
        'p_period_type': period,
        'p_role_type': role,
        'p_limit': limit,
      });

      if (res != null && res is Map && res['leaderboard'] is List) {
        final list = res['leaderboard'] as List<dynamic>;
        return list
            .map((item) => FVLeaderboardItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      print('FVWalletService.getLeaderboard error: $e');
      return [];
    }
  }

  /// Fetch active community links (WhatsApp Channels, Fleet Groups)
  Future<List<FVCommunityLink>> getCommunityLinks({String role = 'all'}) async {
    try {
      var query = _client.from('foody_community_links').select().eq('is_active', true);
      final List<dynamic> res = await query;
      return res
          .map((item) => FVCommunityLink.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((link) => link.targetRole == 'all' || link.targetRole == role)
          .toList();
    } catch (e) {
      print('FVWalletService.getCommunityLinks error: $e');
      return [
        FVCommunityLink(
          id: 'comm_default_wa',
          name: 'Foody Vrinda VIP WhatsApp Channel',
          description: 'Exclusive deals, instant delivery updates, and secret discounts',
          channelType: 'whatsapp_channel',
          targetRole: 'customer',
          linkUrl: 'https://whatsapp.com/channel/foodyvrinda',
        )
      ];
    }
  }

  /// Realtime stream for wallet changes
  RealtimeChannel subscribeWallet(String userId, Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('public:foody_wallets:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'foody_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Helper to format WhatsApp share URL with referral code
  String generateWhatsAppShareUrl(String referralCode, {String role = 'customer'}) {
    final link = 'https://eat.vrindopnishad.in/?ref=${Uri.encodeComponent(referralCode)}';
    String message = '';
    if (role == 'delivery') {
      message = '🚀 Join Foody Vrinda Delivery Fleet! Use my referral code $referralCode to earn milestone cash bonuses on every delivery.\n\nSign up here: $link';
    } else {
      message = '🥗 Order 100% Satvik Pure food from Foody Vrinda in Sri Vrindavan Dham! Use my referral code $referralCode to get ₹10 OFF your first order.\n\nTaste the Divine: $link';
    }
    return 'https://wa.me/?text=${Uri.encodeComponent(message)}';
  }
}
