import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/user_model.dart';
import '../config/lottie_assets.dart';
import 'dart:developer' as dev;

class ResourceCacheService {
  static final ResourceCacheService _instance =
      ResourceCacheService._internal();
  factory ResourceCacheService() => _instance;
  ResourceCacheService._internal();

  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// Pre-caches essential resources based on the user's role
  Future<void> preCacheResources(UserRole role) async {
    dev.log(
      'Starting pre-cache for role: ${role.value}',
      name: 'ResourceCacheService',
    );

    final List<String> commonAssets = [
      LottieAssets.loading,
      LottieAssets.foodLoading,
      LottieAssets.success,
      LottieAssets.error,
      'https://imbajrangi.github.io/Company/Vrindopnishad%20Web/class/logo/foodyVrinda-logo.png',
    ];

    List<String> roleSpecificAssets = [];

    switch (role) {
      case UserRole.customer:
        roleSpecificAssets = [
          LottieAssets.emptyCart,
          LottieAssets.foodDelivery,
          LottieAssets.celebration,
          LottieAssets.orderSuccess,
        ];
        break;
      case UserRole.kitchen:
        roleSpecificAssets = [
          LottieAssets.cooking,
          LottieAssets.preparing,
          LottieAssets.ready,
          LottieAssets.newOrder,
        ];
        break;
      case UserRole.delivery:
        roleSpecificAssets = [
          LottieAssets.delivery,
          LottieAssets.foodDelivery,
          LottieAssets.outForDelivery,
          LottieAssets.ready,
        ];
        break;
      case UserRole.owner:
      case UserRole.developer:
        roleSpecificAssets = [
          LottieAssets.noData,
          LottieAssets.profile,
          LottieAssets.celebration,
        ];
        break;
    }

    final allAssets = {...commonAssets, ...roleSpecificAssets};

    for (final url in allAssets) {
      _cacheAsset(url);
    }
  }

  Future<void> _cacheAsset(String url) async {
    try {
      final file = await _cacheManager.getFileFromCache(url);
      if (file == null) {
        dev.log('Downloading to cache: $url', name: 'ResourceCacheService');
        await _cacheManager.downloadFile(url);
      } else {
        dev.log('Already in cache: $url', name: 'ResourceCacheService');
      }
    } catch (e) {
      dev.log('Error caching $url: $e', name: 'ResourceCacheService');
    }
  }
}
