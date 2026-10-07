/// Foody Vrinda — FV Points & Wallet Models (Schema Parity with Web v3)
/// 1 FV Point = ₹0.10, 50 FV Points = ₹5.00

class FVWalletModel {
  final String userId;
  final double availablePoints;
  final double pendingPoints;
  final double lifetimeEarned;
  final double lifetimeRedeemed;
  final String referralCode;
  final int totalReferrals;
  final int qualifiedReferrals;
  final List<FVWalletLedgerItem> recentTransactions;

  FVWalletModel({
    required this.userId,
    this.availablePoints = 0.0,
    this.pendingPoints = 0.0,
    this.lifetimeEarned = 0.0,
    this.lifetimeRedeemed = 0.0,
    required this.referralCode,
    this.totalReferrals = 0,
    this.qualifiedReferrals = 0,
    this.recentTransactions = const [],
  });

  /// Rupee conversion: 1 FV Point = ₹0.10
  double get rupeeValue => double.parse((availablePoints * 0.10).toStringAsFixed(2));

  factory FVWalletModel.fromJson(Map<String, dynamic> json) {
    final summary = json['referral_summary'] as Map<String, dynamic>? ?? {};
    final txList = json['recent_transactions'] as List<dynamic>? ?? [];

    return FVWalletModel(
      userId: json['user_id']?.toString() ?? '',
      availablePoints: (json['available_points'] as num?)?.toDouble() ?? 0.0,
      pendingPoints: (json['pending_points'] as num?)?.toDouble() ?? 0.0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toDouble() ?? 0.0,
      lifetimeRedeemed: (json['lifetime_redeemed'] as num?)?.toDouble() ?? 0.0,
      referralCode: json['referral_code']?.toString() ?? '',
      totalReferrals: (summary['total_referrals'] as num?)?.toInt() ?? 0,
      qualifiedReferrals: (summary['qualified_referrals'] as num?)?.toInt() ?? 0,
      recentTransactions: txList
          .map((item) => FVWalletLedgerItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'available_points': availablePoints,
      'pending_points': pendingPoints,
      'lifetime_earned': lifetimeEarned,
      'lifetime_redeemed': lifetimeRedeemed,
      'referral_code': referralCode,
      'rupee_value': rupeeValue,
      'referral_summary': {
        'total_referrals': totalReferrals,
        'qualified_referrals': qualifiedReferrals,
        'referral_code': referralCode,
      },
      'recent_transactions': recentTransactions.map((tx) => tx.toJson()).toList(),
    };
  }
}

class FVWalletLedgerItem {
  final String id;
  final double amount;
  final double balanceAfter;
  final String transactionType;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final DateTime? createdAt;

  FVWalletLedgerItem({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.transactionType,
    this.referenceType,
    this.referenceId,
    this.notes,
    this.createdAt,
  });

  bool get isCredit => amount > 0;

  factory FVWalletLedgerItem.fromJson(Map<String, dynamic> json) {
    return FVWalletLedgerItem(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      transactionType: json['transaction_type']?.toString() ?? 'other',
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'balance_after': balanceAfter,
      'transaction_type': transactionType,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class FVLeaderboardItem {
  final String userId;
  final String displayName;
  final double pointsEarned;
  final int referralsCount;
  final int rank;

  FVLeaderboardItem({
    required this.userId,
    required this.displayName,
    required this.pointsEarned,
    required this.referralsCount,
    required this.rank,
  });

  factory FVLeaderboardItem.fromJson(Map<String, dynamic> json) {
    return FVLeaderboardItem(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Foody Member',
      pointsEarned: (json['points_earned'] as num?)?.toDouble() ?? 0.0,
      referralsCount: (json['referrals_count'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'points_earned': pointsEarned,
      'referrals_count': referralsCount,
      'rank': rank,
    };
  }
}

class FVCommunityLink {
  final String id;
  final String name;
  final String? description;
  final String channelType;
  final String targetRole;
  final String linkUrl;
  final bool isActive;

  FVCommunityLink({
    required this.id,
    required this.name,
    this.description,
    required this.channelType,
    this.targetRole = 'all',
    required this.linkUrl,
    this.isActive = true,
  });

  factory FVCommunityLink.fromJson(Map<String, dynamic> json) {
    return FVCommunityLink(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      channelType: json['channel_type']?.toString() ?? 'whatsapp_channel',
      targetRole: json['target_role']?.toString() ?? 'all',
      linkUrl: json['link_url']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'channel_type': channelType,
      'target_role': targetRole,
      'link_url': linkUrl,
      'is_active': isActive,
    };
  }
}
