import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CashTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CashTransactionModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      shopId: data['shopId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: CashTransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CashTransactionType.collection,
      ),
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'shopId': shopId,
      'amount': amount,
      'type': type.name,
      'userId': userId,
      'userName': userName,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
    };
  }
}
