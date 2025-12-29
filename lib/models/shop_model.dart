import 'package:cloud_firestore/cloud_firestore.dart';

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
          .map((p) => '${p.emoji} ${p.displayName}')
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
  final String? imageUrl;
  final String? ownerId;
  final ShopSchedule schedule;
  final AlarmSettings alarmSettings;
  final DateTime? createdAt;

  ShopModel({
    required this.id,
    required this.name,
    this.address,
    this.imageUrl,
    this.ownerId,
    ShopSchedule? schedule,
    AlarmSettings? alarmSettings,
    this.createdAt,
  }) : schedule = schedule ?? ShopSchedule(),
       alarmSettings = alarmSettings ?? AlarmSettings();

  factory ShopModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ShopModel(id: doc.id, name: 'Unknown Shop');
    }

    // Handle both 'image' and 'imageUrl' field names
    String? image = data['imageUrl'] ?? data['image'];

    // Parse schedule - handle both object and non-existent cases
    ShopSchedule schedule;
    if (data['schedule'] != null && data['schedule'] is Map) {
      schedule = ShopSchedule.fromMap(data['schedule'] as Map<String, dynamic>);
    } else {
      schedule = ShopSchedule();
    }

    // Parse alarm settings
    AlarmSettings alarmSettings;
    if (data['alarmSettings'] != null && data['alarmSettings'] is Map) {
      alarmSettings = AlarmSettings.fromMap(
        data['alarmSettings'] as Map<String, dynamic>,
      );
    } else {
      alarmSettings = AlarmSettings();
    }

    // Parse createdAt
    DateTime? createdAt;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      }
    }

    return ShopModel(
      id: doc.id,
      name: data['name']?.toString() ?? 'Unnamed Shop',
      address: data['address']?.toString(),
      imageUrl: image,
      ownerId: data['ownerId']?.toString(),
      schedule: schedule,
      alarmSettings: alarmSettings,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'image': imageUrl, // Use 'image' to match existing data
      'ownerId': ownerId,
      'schedule': schedule.toMap(),
      'alarmSettings': alarmSettings.toMap(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ShopModel copyWith({
    String? id,
    String? name,
    String? address,
    String? imageUrl,
    String? ownerId,
    ShopSchedule? schedule,
    AlarmSettings? alarmSettings,
    DateTime? createdAt,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      schedule: schedule ?? this.schedule,
      alarmSettings: alarmSettings ?? this.alarmSettings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isOpen => schedule.isOpenNow();

  String get statusText => isOpen ? 'Open' : 'Closed';

  @override
  String toString() => 'ShopModel(id: $id, name: $name, address: $address)';
}
