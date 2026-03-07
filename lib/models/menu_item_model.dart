import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return MenuItemModel(
        id: doc.id,
        shopId: '',
        name: 'Unknown Item',
        price: 0,
      );
    }

    // Handle both 'image' and 'imageUrl' field names for compatibility
    String? image = data['imageUrl'] ?? data['image'];

    return MenuItemModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? 'Unnamed Item',
      price: (data['price'] ?? 0).toDouble(),
      originalPrice: data['originalPrice'] != null 
          ? (data['originalPrice']).toDouble() 
          : null,
      imageUrl: image,
      isAvailable: data['isAvailable'] ?? true,
      category: data['category'],
      description: data['description'],
      isVeg: data['isVeg'] ?? true,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'name': name,
      'price': price,
      'originalPrice': originalPrice,
      'image': imageUrl,
      'isAvailable': isAvailable,
      'category': category,
      'description': description,
      'isVeg': isVeg,
      'rating': rating,
      'ratingCount': ratingCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
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
