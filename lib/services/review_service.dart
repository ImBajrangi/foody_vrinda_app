import '../models/review_model.dart';
import 'supabase_service.dart';
import '../config/supabase_config.dart';

class ReviewService {
  final SupabaseService _supabase = SupabaseService();

  /// Get stream of reviews for a shop (ordered by date, newest first)
  Stream<List<ReviewModel>> getReviews(String shopId, {int limit = 10}) {
    return _supabase.client
        .from(SupabaseConfig.reviewsTable)
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .map((records) {
          final list = records.map((data) => ReviewModel.fromMap(data)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list.take(limit).toList();
        })
        .handleError((_) => <ReviewModel>[]);
  }

  /// Add a new review
  Future<void> addReview(ReviewModel review) async {
    try {
      await _supabase.client.from(SupabaseConfig.reviewsTable).insert(review.toMap());
    } catch (e) {
      print('ReviewService.addReview error: $e');
    }
  }

  /// Check if user has already reviewed this shop
  Future<bool> hasUserReviewed(String shopId, String userId) async {
    try {
      final res = await _supabase.client
          .from(SupabaseConfig.reviewsTable)
          .select('id')
          .eq('shop_id', shopId)
          .eq('user_id', userId)
          .limit(1);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Get pending order count for a shop
  Future<int> getPendingOrderCount(String shopId) async {
    try {
      final res = await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .select('id')
          .eq('shop_id', shopId)
          .inFilter('status', ['new', 'preparing', 'ready_for_pickup']);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  /// Stream pending order count for live updates
  Stream<int> streamPendingOrderCount(String shopId) {
    return _supabase.client
        .from(SupabaseConfig.ordersTable)
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .map((records) {
          return records.where((r) {
            final st = r['status']?.toString() ?? '';
            return ['new', 'preparing', 'ready_for_pickup'].contains(st);
          }).length;
        })
        .handleError((_) => 0);
  }
}
