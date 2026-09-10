enum CashTransactionType { collection, settlement, refund }

class CashTransactionModel {
  final String id;
  final String orderId;
  final String shopId;
  final double amount;
  final CashTransactionType type;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String? notes;

  CashTransactionModel({
    required this.id,
    required this.orderId,
    required this.shopId,
    required this.amount,
    required this.type,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.notes,
  });

  String get formattedAmount => '₹${amount.toStringAsFixed(0)}';

  factory CashTransactionModel.fromMap(Map<String, dynamic> data) {
    DateTime ts = DateTime.now();
    if (data['timestamp'] != null) {
      ts = DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now();
    }

    return CashTransactionModel(
      id: data['id']?.toString() ?? '',
      orderId: data['order_id']?.toString() ?? data['orderId']?.toString() ?? '',
      shopId: data['shop_id']?.toString() ?? data['shopId']?.toString() ?? '',
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      type: CashTransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CashTransactionType.collection,
      ),
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      userName: data['user_name']?.toString() ?? data['userName']?.toString() ?? 'Unknown',
      timestamp: ts,
      notes: data['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'shop_id': shopId,
      'amount': amount,
      'type': type.name,
      'user_id': userId,
      'user_name': userName,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'notes': notes,
    };
  }
}
