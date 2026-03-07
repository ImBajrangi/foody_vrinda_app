import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, kitchen, delivery, owner, developer }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.kitchen:
        return 'kitchen';
      case UserRole.delivery:
        return 'delivery';
      case UserRole.owner:
        return 'owner';
      case UserRole.developer:
        return 'developer';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'kitchen':
        return UserRole.kitchen;
      case 'delivery':
        return UserRole.delivery;
      case 'owner':
        return UserRole.owner;
      case 'developer':
        return UserRole.developer;
      default:
        return UserRole.customer;
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber; // Contact phone number
  final UserRole role;
  final String? shopId;
  final List<String>? shopIds; // For delivery staff multi-shop support
  final bool isOnline; // For delivery availability status
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final List<String> devPermissions; // Permissions for dev panel features

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.role = UserRole.customer,
    this.shopId,
    this.shopIds,
    this.isOnline = false,
    this.createdAt,
    this.lastLogin,
    this.devPermissions = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return UserModel(uid: doc.id, email: '');
    }

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      phoneNumber: data['phoneNumber'],
      role: UserRoleExtension.fromString(data['role']),
      shopId: data['shopId'],
      shopIds: data['shopIds'] != null
          ? List<String>.from(data['shopIds'])
          : null,
      isOnline: data['isOnline'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
      devPermissions: data['devPermissions'] != null
          ? List<String>.from(data['devPermissions'])
          : const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'role': role.value,
      'shopId': shopId,
      'shopIds': shopIds,
      'isOnline': isOnline,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'devPermissions': devPermissions,
    };
  }

  /// Convert to JSON for local storage (SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'role': role.value,
      'shopId': shopId,
      'shopIds': shopIds,
      'isOnline': isOnline,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'devPermissions': devPermissions,
    };
  }

  /// Create from JSON (from local storage)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      phoneNumber: json['phoneNumber'],
      role: UserRoleExtension.fromString(json['role']),
      shopId: json['shopId'],
      shopIds: json['shopIds'] != null
          ? List<String>.from(json['shopIds'])
          : null,
      isOnline: json['isOnline'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      devPermissions: json['devPermissions'] != null
          ? List<String>.from(json['devPermissions'])
          : const [],
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    UserRole? role,
    String? shopId,
    List<String>? shopIds,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? lastLogin,
    List<String>? devPermissions,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      shopIds: shopIds ?? this.shopIds,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      devPermissions: devPermissions ?? this.devPermissions,
    );
  }

  bool get isStaff =>
      role == UserRole.kitchen ||
      role == UserRole.delivery ||
      role == UserRole.owner;
  bool get isAdmin => role == UserRole.owner || role == UserRole.developer;
  bool get isDeveloper => role == UserRole.developer;

  bool hasDevPermission(String permission) {
    if (isDeveloper) return true;
    return devPermissions.contains(permission);
  }

  bool get canAccessDevPanel => isDeveloper || devPermissions.isNotEmpty;

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'G';
  }
}
