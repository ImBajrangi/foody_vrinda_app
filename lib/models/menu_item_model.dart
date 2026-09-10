class MenuItemModel {
  final String id;
  final String shopId;
  final String name;
  final double price;
  final double? originalPrice; // For showing discounts (strikethrough price)
  final String? imageUrl;
  final bool isAvailable;
  final String? category;
  final String? description;
  final bool isVeg;
  final double rating;
  final int ratingCount;
  final DateTime? createdAt;

  MenuItemModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.isAvailable = true,
    this.category,
    this.description,
    this.isVeg = true,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.createdAt,
  });

  factory MenuItemModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final itemId = id ?? data['id']?.toString() ?? '';
    String? image = data['image'] ?? data['imageUrl'] ?? data['image_url'];

    DateTime? parsedCreatedAt;
    if (data['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(data['created_at'].toString());
    } else if (data['createdAt'] != null) {
      parsedCreatedAt = DateTime.tryParse(data['createdAt'].toString());
    }

    return MenuItemModel(
      id: itemId,
      shopId: (data['shop_id'] ?? data['shopId'] ?? '').toString(),
      name: (data['name'] ?? 'Unnamed Item').toString(),
      price: (data['price'] is num ? data['price'] : num.tryParse(data['price']?.toString() ?? '0') ?? 0).toDouble(),
      originalPrice: data['original_price'] != null || data['originalPrice'] != null
          ? ((data['original_price'] ?? data['originalPrice']) as num).toDouble()
          : null,
      imageUrl: image?.toString(),
      isAvailable: data['is_available'] ?? data['isAvailable'] ?? true,
      category: data['category']?.toString(),
      description: data['description']?.toString(),
      isVeg: data['is_veg'] ?? data['isVeg'] ?? true,
      rating: ((data['rating'] ?? 0.0) as num).toDouble(),
      ratingCount: (data['rating_count'] ?? data['ratingCount'] ?? 0) as int,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'price': price,
      'original_price': originalPrice,
      'image': imageUrl,
      'is_available': isAvailable,
      'category': category,
      'description': description,
      'is_veg': isVeg,
      'rating': rating,
      'rating_count': ratingCount,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  MenuItemModel copyWith({
    String? id,
    String? shopId,
    String? name,
    double? price,
    double? originalPrice,
    String? imageUrl,
    bool? isAvailable,
    String? category,
    String? description,
    bool? isVeg,
    double? rating,
    int? ratingCount,
    DateTime? createdAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      category: category ?? this.category,
      description: description ?? this.description,
      isVeg: isVeg ?? this.isVeg,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';
  String get formattedOriginalPrice => originalPrice != null ? '₹${originalPrice!.toStringAsFixed(0)}' : '';
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
}
