import '../models/user_model.dart';
import 'supabase_service.dart';

/// Pure Supabase Authentication Service (Zero Firebase)
class AuthService {
  final SupabaseService _supabaseService = SupabaseService();

  // Get current user from Supabase session
  UserModel? get currentUser {
    final sbUser = _supabaseService.client.auth.currentUser;
    if (sbUser == null) return null;
    return UserModel(
      uid: sbUser.id,
      email: sbUser.email ?? '',
      displayName: sbUser.userMetadata?['displayName'] ?? sbUser.userMetadata?['full_name'],
      photoURL: sbUser.userMetadata?['avatar_url'],
    );
  }

  // Get user data from Supabase
  Future<UserModel?> getUserData(String uid) async {
    try {
      final profile = await _supabaseService.getLiveUserRoleAndProfile(userId: uid);
      if (profile != null) {
        return UserModel(
          uid: profile['id'] ?? uid,
          email: profile['email'] ?? '',
          displayName: profile['display_name'] ?? 'Devotee',
          photoURL: profile['avatar_url'],
          phoneNumber: profile['phone'],
          deliveryAddress: profile['address'] ?? profile['customer_address'],
          role: UserRoleExtension.fromString(profile['role']),
          shopId: profile['shop_id'],
        );
      }
      return null;
    } catch (e) {
      print('AuthService.getUserData error: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? phoneNumber,
    String? deliveryAddress,
    String? photoURL,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (phoneNumber != null) updates['phone'] = phoneNumber;
    if (deliveryAddress != null) updates['address'] = deliveryAddress;
    if (photoURL != null) updates['avatar_url'] = photoURL;

    if (updates.isNotEmpty) {
      await _supabaseService.updateCloudUser(uid, updates);
    }
  }

  // Update user role (admin/dev)
  Future<void> updateUserRole({
    required String uid,
    required UserRole role,
    String? shopId,
    List<String>? shopIds,
  }) async {
    final updates = <String, dynamic>{'role': role.value};
    if (shopId != null) updates['shop_id'] = shopId;
    if (shopIds != null) updates['shop_ids'] = shopIds;

    await _supabaseService.updateCloudUser(uid, updates);
  }

  // Get all users from Supabase Cloud
  Future<List<UserModel>> getAllUsers() async {
    try {
      final cloudUsers = await _supabaseService.getCloudUsers();
      return cloudUsers.map((u) => UserModel(
        uid: u['id'] ?? '',
        email: u['email'] ?? '',
        displayName: u['display_name'] ?? 'Devotee',
        photoURL: u['avatar_url'],
        phoneNumber: u['phone'],
        deliveryAddress: u['address'] ?? u['customer_address'],
        role: UserRoleExtension.fromString(u['role']),
        shopId: u['shop_id'],
      )).toList();
    } catch (e) {
      print('AuthService.getAllUsers error: $e');
      return [];
    }
  }
}
