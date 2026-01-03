import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemModel {
  final String id;
  final String shopId;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final String? category;
  final String? description;
  final DateTime? createdAt;

  MenuItemModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    this.imageUrl,
    this.isAvailable = true,
    this.category,
    this.description,
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

    // Handle both 'image' and 'imageUrl' field names for compatibility with different sources
    String? image = data['imageUrl'] ?? data['image'];

    return MenuItemModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? 'Unnamed Item',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: image,
      isAvailable: data['isAvailable'] ?? true,
      category: data['category'],
      description: data['description'],
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
      'image': imageUrl, // Use 'image' to match existing web app data structure
      'isAvailable': isAvailable,
      'category': category,
      'description': description,
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
    String? imageUrl,
    bool? isAvailable,
    String? category,
    String? description,
    DateTime? createdAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';
}
