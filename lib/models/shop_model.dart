

/// Time periods for intuitive scheduling
enum TimePeriod {
  morning, // 6:00 AM - 9:00 AM
  forenoon, // 9:00 AM - 12:00 PM
  afternoon, // 12:00 PM - 4:00 PM
  evening, // 4:00 PM - 8:00 PM
  night, // 8:00 PM - 12:00 AM
}

/// Extension for TimePeriod with display names and time ranges
extension TimePeriodExtension on TimePeriod {
  String get displayName {
    switch (this) {
      case TimePeriod.morning:
        return 'Morning';
      case TimePeriod.forenoon:
        return 'Forenoon';
      case TimePeriod.afternoon:
        return 'Afternoon';
      case TimePeriod.evening:
        return 'Evening';
      case TimePeriod.night:
        return 'Night';
    }
  }

  String get timeRange {
    switch (this) {
      case TimePeriod.morning:
        return '6:00 AM - 9:00 AM';
      case TimePeriod.forenoon:
        return '9:00 AM - 12:00 PM';
      case TimePeriod.afternoon:
        return '12:00 PM - 4:00 PM';
      case TimePeriod.evening:
        return '4:00 PM - 8:00 PM';
      case TimePeriod.night:
        return '8:00 PM - 12:00 AM';
    }
  }

  String get emoji {
    switch (this) {
      case TimePeriod.morning:
        return '🌅';
      case TimePeriod.forenoon:
        return '☀️';
      case TimePeriod.afternoon:
        return '🍽️';
      case TimePeriod.evening:
        return '🌆';
      case TimePeriod.night:
        return '🌙';
    }
  }

  /// Start hour (24-hour format)
  int get startHour {
    switch (this) {
      case TimePeriod.morning:
        return 6;
      case TimePeriod.forenoon:
        return 9;
      case TimePeriod.afternoon:
        return 12;
      case TimePeriod.evening:
        return 16;
      case TimePeriod.night:
        return 20;
    }
  }

  /// End hour (24-hour format)
  int get endHour {
    switch (this) {
      case TimePeriod.morning:
        return 9;
      case TimePeriod.forenoon:
        return 12;
      case TimePeriod.afternoon:
        return 16;
      case TimePeriod.evening:
        return 20;
      case TimePeriod.night:
        return 24;
    }
  }
}

class ShopSchedule {
  final String? openTime;
  final String? closeTime;
  final List<String> daysOpen;
  final List<String>
  timePeriods; // Stores period names: 'morning', 'afternoon', etc.

  ShopSchedule({
    this.openTime,
    this.closeTime,
    this.daysOpen = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.timePeriods = const [],
  });

  factory ShopSchedule.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return ShopSchedule();
    }

    // Handle both 'daysOpen' and 'operatingDays' field names
    List<String> days = [];
    if (data['daysOpen'] != null) {
      days = List<String>.from(data['daysOpen']);
    } else if (data['operatingDays'] != null) {
      days = List<String>.from(data['operatingDays']);
    } else {
      days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }

    // Parse time periods
    List<String> periods = [];
    if (data['timePeriods'] != null) {
      periods = List<String>.from(data['timePeriods']);
    }

    return ShopSchedule(
      openTime: data['openTime']?.toString(),
      closeTime: data['closeTime']?.toString(),
      daysOpen: days,
      timePeriods: periods,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openTime': openTime,
      'closeTime': closeTime,
      'daysOpen': daysOpen,
      'timePeriods': timePeriods,
    };
  }

  /// Check if currently open based on time periods or legacy time-based schedule
  bool isOpenNow() {
    final now = DateTime.now();
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final currentDay = daysOfWeek[now.weekday % 7];

    if (!daysOpen.contains(currentDay)) {
      return false;
    }

    // Check time periods first (new system)
    if (timePeriods.isNotEmpty) {
      final currentHour = now.hour;
      for (final periodName in timePeriods) {
        final period = _getPeriodFromName(periodName);
        if (period != null) {
          if (currentHour >= period.startHour && currentHour < period.endHour) {
            return true;
          }
        }
      }
      return false;
    }

    // Fall back to legacy time-based schedule
    if (openTime == null ||
        openTime!.isEmpty ||
        closeTime == null ||
        closeTime!.isEmpty) {
      return true;
    }

    try {
      final openParts = openTime!.split(':');
      final closeParts = closeTime!.split(':');

      final openHour = int.tryParse(openParts[0]) ?? 0;
      final openMinute = openParts.length > 1
          ? int.tryParse(openParts[1]) ?? 0
          : 0;
      final closeHour = int.tryParse(closeParts[0]) ?? 23;
      final closeMinute = closeParts.length > 1
          ? int.tryParse(closeParts[1]) ?? 59
          : 59;

      final openTimeOfDay = openHour * 60 + openMinute;
      final closeTimeOfDay = closeHour * 60 + closeMinute;
      final currentTimeOfDay = now.hour * 60 + now.minute;

      return currentTimeOfDay >= openTimeOfDay &&
          currentTimeOfDay <= closeTimeOfDay;
    } catch (e) {
      return true; // If parsing fails, assume open
    }
  }

  TimePeriod? _getPeriodFromName(String name) {
    switch (name.toLowerCase()) {
      case 'morning':
        return TimePeriod.morning;
      case 'forenoon':
        return TimePeriod.forenoon;
      case 'afternoon':
        return TimePeriod.afternoon;
      case 'evening':
        return TimePeriod.evening;
      case 'night':
        return TimePeriod.night;
      default:
        return null;
    }
  }

  /// Get selected TimePeriod enums from stored strings
  List<TimePeriod> get selectedTimePeriods {
    return timePeriods
        .map((name) => _getPeriodFromName(name))
        .whereType<TimePeriod>()
        .toList();
  }

  String get displaySchedule {
    // If time periods are set, display them
    if (timePeriods.isNotEmpty) {
      final periodNames = selectedTimePeriods
          .map((p) => p.displayName)
          .join(', ');
      return periodNames;
    }

    // Fall back to legacy time display
    if (openTime == null ||
        openTime!.isEmpty ||
        closeTime == null ||
        closeTime!.isEmpty) {
      return 'Always Open';
    }
    return '$openTime - $closeTime';
  }
}

class AlarmSettings {
  final bool kitchenNew;
  final bool kitchenReady;
  final bool deliveryReady;

  AlarmSettings({
    this.kitchenNew = true,
    this.kitchenReady = false,
    this.deliveryReady = true,
  });

  factory AlarmSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return AlarmSettings();
    }
    return AlarmSettings(
      kitchenNew: data['kitchenNew'] ?? true,
      kitchenReady: data['kitchenReady'] ?? false,
      deliveryReady: data['deliveryReady'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kitchenNew': kitchenNew,
      'kitchenReady': kitchenReady,
      'deliveryReady': deliveryReady,
    };
  }
}

class ShopModel {
  final String id;
  final String name;
  final String? address;
  final String? phoneNumber; // Contact phone number for the shop
  final double? latitude; // Location coordinate
  final double? longitude; // Location coordinate
  final String? imageUrl;
  final String? ownerId;
  final ShopSchedule schedule;
  final AlarmSettings alarmSettings;
  final DateTime? createdAt;
  final double rating;
  final int ratingCount;
  final bool showOrderQueue;
  final int estimatedWaitTime;
  final bool showWaitTime;
  final double minimumOrderAmount; // Minimum order value required
  final double deliveryCharge; // Delivery fee
  final double gstPercentage; // GST percentage
  final String? discountTag; // e.g., "50% OFF"
  final String? discountDescription; // e.g., "Up to ₹100 on first order"

  ShopModel({
    required this.id,
    required this.name,
    this.address,
    this.phoneNumber,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.ownerId,
    ShopSchedule? schedule,
    AlarmSettings? alarmSettings,
    this.createdAt,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.showOrderQueue = false,
    this.estimatedWaitTime = 15,
    this.showWaitTime = false,
    this.minimumOrderAmount = 0.0,
    this.deliveryCharge = 0.0,
    this.gstPercentage = 5.0,
    this.discountTag,
    this.discountDescription,
  }) : schedule = schedule ?? ShopSchedule(),
       alarmSettings = alarmSettings ?? AlarmSettings();

  factory ShopModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final shopId = id ?? data['id']?.toString() ?? '';
    String? image = data['image'] ?? data['imageUrl'] ?? data['image_url'];

    // Parse coordinates - either coordinates: {lat, lng} or separate latitude/longitude
    double? lat;
    double? lng;
    if (data['coordinates'] != null && data['coordinates'] is Map) {
      final coords = data['coordinates'] as Map;
      lat = (coords['lat'] as num?)?.toDouble();
      lng = (coords['lng'] as num?)?.toDouble();
    } else {
      lat = (data['latitude'] ?? data['lat']) != null ? ((data['latitude'] ?? data['lat']) as num).toDouble() : null;
      lng = (data['longitude'] ?? data['lng']) != null ? ((data['longitude'] ?? data['lng']) as num).toDouble() : null;
    }

    // Parse schedule
    ShopSchedule schedule;
    if (data['schedule'] != null && data['schedule'] is Map) {
      schedule = ShopSchedule.fromMap(data['schedule'] as Map<String, dynamic>);
    } else {
      schedule = ShopSchedule();
    }

    // Parse alarm settings
    AlarmSettings alarmSettings;
    final alarmData = data['alarm_settings'] ?? data['alarmSettings'];
    if (alarmData != null && alarmData is Map) {
      alarmSettings = AlarmSettings.fromMap(alarmData as Map<String, dynamic>);
    } else {
      alarmSettings = AlarmSettings();
    }

    // Parse createdAt
    DateTime? createdAt;
    if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString());
    } else if (data['createdAt'] != null) {
      createdAt = DateTime.tryParse(data['createdAt'].toString());
    }

    return ShopModel(
      id: shopId,
      name: data['name']?.toString() ?? 'Unnamed Shop',
      address: data['address']?.toString(),
      phoneNumber: (data['phone'] ?? data['phoneNumber'])?.toString(),
      latitude: lat,
      longitude: lng,
      imageUrl: image,
      ownerId: (data['owner_id'] ?? data['ownerId'])?.toString(),
      schedule: schedule,
      alarmSettings: alarmSettings,
      createdAt: createdAt,
      rating: ((data['rating'] ?? 0.0) as num).toDouble(),
      ratingCount: (data['rating_count'] ?? data['ratingCount'] ?? 0) as int,
      showOrderQueue: data['show_order_queue'] ?? data['showOrderQueue'] ?? false,
      estimatedWaitTime: (data['estimated_wait_time'] ?? data['estimatedWaitTime'] ?? 15) as int,
      showWaitTime: data['show_wait_time'] ?? data['showWaitTime'] ?? false,
      minimumOrderAmount: ((data['minimum_order_amount'] ?? data['minimumOrderAmount'] ?? 0.0) as num).toDouble(),
      deliveryCharge: ((data['delivery_charge'] ?? data['deliveryCharge'] ?? 0.0) as num).toDouble(),
      gstPercentage: ((data['gst_percentage'] ?? data['gstPercentage'] ?? 5.0) as num).toDouble(),
      discountTag: (data['discount_tag'] ?? data['discountTag'])?.toString(),
      discountDescription: (data['discount_description'] ?? data['discountDescription'])?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'image': imageUrl,
      'owner_id': ownerId,
      'schedule': schedule.toMap(),
      'alarm_settings': alarmSettings.toMap(),
      'created_at': createdAt?.toUtc().toIso8601String(),
      'rating': rating,
      'rating_count': ratingCount,
      'show_order_queue': showOrderQueue,
      'estimated_wait_time': estimatedWaitTime,
      'show_wait_time': showWaitTime,
      'minimum_order_amount': minimumOrderAmount,
      'delivery_charge': deliveryCharge,
      'gst_percentage': gstPercentage,
      'discount_tag': discountTag,
      'discount_description': discountDescription,
    };
  }

  ShopModel copyWith({
    String? id,
    String? name,
    String? address,
    String? phoneNumber,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? ownerId,
    ShopSchedule? schedule,
    AlarmSettings? alarmSettings,
    DateTime? createdAt,
    double? rating,
    int? ratingCount,
    bool? showOrderQueue,
    int? estimatedWaitTime,
    bool? showWaitTime,
    double? minimumOrderAmount,
    double? deliveryCharge,
    double? gstPercentage,
    String? discountTag,
    String? discountDescription,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      schedule: schedule ?? this.schedule,
      alarmSettings: alarmSettings ?? this.alarmSettings,
      createdAt: createdAt ?? this.createdAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      showOrderQueue: showOrderQueue ?? this.showOrderQueue,
      estimatedWaitTime: estimatedWaitTime ?? this.estimatedWaitTime,
      showWaitTime: showWaitTime ?? this.showWaitTime,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      discountTag: discountTag ?? this.discountTag,
      discountDescription: discountDescription ?? this.discountDescription,
    );
  }

  bool get isOpen => schedule.isOpenNow();

  String get statusText => isOpen ? 'Open' : 'Closed';

  @override
  String toString() => 'ShopModel(id: $id, name: $name, address: $address)';
}
