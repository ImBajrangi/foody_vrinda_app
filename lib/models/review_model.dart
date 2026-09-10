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

  factory ReviewModel.fromMap(Map<String, dynamic> data) {
    DateTime createdAt = DateTime.now();
    if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now();
    } else if (data['createdAt'] != null) {
      createdAt = DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now();
    }

    return ReviewModel(
      id: data['id']?.toString() ?? '',
      shopId: data['shop_id']?.toString() ?? data['shopId']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      userName: data['user_name']?.toString() ?? data['userName']?.toString() ?? 'Devotee',
      userPhotoUrl: data['user_photo_url']?.toString() ?? data['userPhotoUrl']?.toString(),
      rating: ((data['rating'] ?? 5.0) as num).toDouble(),
      comment: data['comment']?.toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'user_id': userId,
      'user_name': userName,
      'user_photo_url': userPhotoUrl,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
