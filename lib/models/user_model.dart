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
  final UserRole role;
  final String? shopId;
  final List<String>? shopIds; // For delivery staff multi-shop support
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.role = UserRole.customer,
    this.shopId,
    this.shopIds,
    this.createdAt,
    this.lastLogin,
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
      role: UserRoleExtension.fromString(data['role']),
      shopId: data['shopId'],
      shopIds: data['shopIds'] != null
          ? List<String>.from(data['shopIds'])
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.value,
      'shopId': shopId,
      'shopIds': shopIds,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to JSON for local storage (SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.value,
      'shopId': shopId,
      'shopIds': shopIds,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  /// Create from JSON (from local storage)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      role: UserRoleExtension.fromString(json['role']),
      shopId: json['shopId'],
      shopIds: json['shopIds'] != null
          ? List<String>.from(json['shopIds'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    UserRole? role,
    String? shopId,
    List<String>? shopIds,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      shopIds: shopIds ?? this.shopIds,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  bool get isStaff =>
      role == UserRole.kitchen ||
      role == UserRole.delivery ||
      role == UserRole.owner;
  bool get isAdmin => role == UserRole.owner || role == UserRole.developer;
  bool get isDeveloper => role == UserRole.developer;

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
