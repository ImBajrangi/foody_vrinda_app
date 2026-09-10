import '../models/shop_model.dart';
import '../models/menu_item_model.dart';
import 'hit_soochi_service.dart';
import 'supabase_service.dart';
import 'shop_service.dart';

/// Represents a search result that can be either a Shop or a Menu Item
class SearchResult {
  final String type; // 'shop' or 'menuItem'
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final ShopModel? shop; // For direct navigation
  final MenuItemModel? menuItem;
  final String? shopId; // For menu items, to navigate to the shop
  final double? relevanceScore; // From HitSoochi semantic ranking

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.shop,
    this.menuItem,
    this.shopId,
    this.relevanceScore,
  });
}

/// Enhanced search response with HitSoochi integration
class EnhancedSearchResponse {
  final String originalQuery;
  final String? optimizedQuery;
  final String? detectedIntent;
  final String? confidence;
  final List<SearchResult> results;
  final RecommendationResponse? recommendation;

  EnhancedSearchResponse({
    required this.originalQuery,
    this.optimizedQuery,
    this.detectedIntent,
    this.confidence,
    required this.results,
    this.recommendation,
  });
}

class SearchService {
  final SupabaseService _supabase = SupabaseService();
  final HitSoochiService _hitSoochi = HitSoochiService();

  /// Enhanced search using HitSoochi for optimization and ranking
  Future<EnhancedSearchResponse> enhancedSearch(String query) async {
    if (query.trim().isEmpty) {
      return EnhancedSearchResponse(originalQuery: query, results: []);
    }

    final resultsFuture = search(query);
    final optimizeFuture = _hitSoochi.optimizeQuery(query);
    final recommendFuture = _hitSoochi.getRecommendations(query);

    final results = await resultsFuture;
    final optimized = await optimizeFuture;
    final recommendation = await recommendFuture;

    List<SearchResult> rankedResults = results;
    if (results.length > 1 && optimized != null) {
      final itemsForRanking = results
          .map(
            (r) => {
              'title': r.title,
              'description': r.subtitle ?? '',
              'category': r.type,
            },
          )
          .toList();

      final ranked = await _hitSoochi.rankResults(
        query,
        itemsForRanking,
        context: SearchContext(platform: 'app', source: 'foody_vrinda_app'),
      );

      if (ranked.isNotEmpty) {
        final scoreMap = <String, double>{};
        for (final item in ranked) {
          if (item.title != null) {
            scoreMap[item.title!] = item.relevanceScore;
          }
        }

        rankedResults = results
            .map(
              (r) => SearchResult(
                type: r.type,
                id: r.id,
                title: r.title,
                subtitle: r.subtitle,
                imageUrl: r.imageUrl,
                shop: r.shop,
                menuItem: r.menuItem,
                shopId: r.shopId,
                relevanceScore: scoreMap[r.title] ?? 0.0,
              ),
            )
            .toList();

        rankedResults.sort(
          (a, b) => (b.relevanceScore ?? 0).compareTo(a.relevanceScore ?? 0),
        );
      }
    }

    return EnhancedSearchResponse(
      originalQuery: query,
      optimizedQuery: optimized?.optimized,
      detectedIntent: optimized?.intent,
      confidence: optimized?.confidence,
      results: rankedResults,
      recommendation: recommendation,
    );
  }

  /// Searches across shops and menu items (basic matching)
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final queryLower = query.toLowerCase().trim();
    final results = <SearchResult>[];

    // Search shops
    try {
      final shopsData = await _supabase.getShops();
      for (final data in shopsData) {
        final shop = ShopModel.fromMap(data);
        final nameMatch = shop.name.toLowerCase().contains(queryLower);
        final addressMatch =
            shop.address?.toLowerCase().contains(queryLower) ?? false;

        if (nameMatch || addressMatch) {
          results.add(
            SearchResult(
              type: 'shop',
              id: shop.id,
              title: shop.name,
              subtitle: shop.address ?? 'Cloud Kitchen',
              imageUrl: shop.imageUrl,
              shop: shop,
            ),
          );
        }
      }
    } catch (e) {
      print('SearchService: Error searching shops: $e');
    }

    // Search menu items
    try {
      final menusData = await _supabase.client.from('foody_menus').select('*');
      for (final doc in menusData) {
        final item = MenuItemModel.fromMap(doc);
        final nameMatch = item.name.toLowerCase().contains(queryLower);
        final categoryMatch =
            item.category?.toLowerCase().contains(queryLower) ?? false;
        final descriptionMatch =
            item.description?.toLowerCase().contains(queryLower) ?? false;

        if (nameMatch || categoryMatch || descriptionMatch) {
          results.add(
            SearchResult(
              type: 'menuItem',
              id: item.id,
              title: item.name,
              subtitle:
                  '${item.formattedPrice}${item.category != null ? ' • ${item.category}' : ''}',
              imageUrl: item.imageUrl,
              menuItem: item,
              shopId: item.shopId,
            ),
          );
        }
      }
    } catch (e) {
      print('SearchService: Error searching menu items: $e');
    }

    results.sort((a, b) {
      if (a.type == b.type) {
        return a.title.compareTo(b.title);
      }
      return a.type == 'shop' ? -1 : 1;
    });

    return results;
  }

  /// Get a shop by its ID
  Future<ShopModel?> getShopById(String shopId) async {
    return ShopService().getShop(shopId);
  }

  /// Get autocomplete suggestions
  Future<List<Suggestion>> getSuggestions(String partial) async {
    return _hitSoochi.getSuggestions(partial);
  }
}
