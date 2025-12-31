import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String shopId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ReviewModel(
        id: doc.id,
        shopId: '',
        userId: '',
        userName: 'Anonymous',
        rating: 0,
        createdAt: DateTime.now(),
      );
    }

    DateTime createdAt = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      }
    }

    return ReviewModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'],
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
