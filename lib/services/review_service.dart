import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get stream of reviews for a shop (ordered by date, newest first)
  Stream<List<ReviewModel>> getReviews(String shopId, {int limit = 10}) {
    return _firestore
        .collection('reviews')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReviewModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Add a new review
  Future<void> addReview(ReviewModel review) async {
    final batch = _firestore.batch();

    // Add the review
    final reviewRef = _firestore.collection('reviews').doc();
    batch.set(reviewRef, review.toFirestore());

    // Update shop's rating and count
    final shopRef = _firestore.collection('shops').doc(review.shopId);
    final shopDoc = await shopRef.get();

    if (shopDoc.exists) {
      final shopData = shopDoc.data() as Map<String, dynamic>;
      final currentRating = (shopData['rating'] ?? 0.0).toDouble();
      final currentCount = shopData['ratingCount'] ?? 0;

      // Calculate new average
      final newCount = currentCount + 1;
      final newRating =
          ((currentRating * currentCount) + review.rating) / newCount;

      batch.update(shopRef, {'rating': newRating, 'ratingCount': newCount});
    }

    await batch.commit();
  }

  /// Check if user has already reviewed this shop
  Future<bool> hasUserReviewed(String shopId, String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get pending order count for a shop
  Future<int> getPendingOrderCount(String shopId) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['new', 'preparing', 'ready_for_pickup'])
        .get();

    return snapshot.docs.length;
  }

  /// Stream pending order count for live updates
  Stream<int> streamPendingOrderCount(String shopId) {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['new', 'preparing', 'ready_for_pickup'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
