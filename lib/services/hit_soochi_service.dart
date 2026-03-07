import 'dart:convert';
import 'package:http/http.dart' as http;

/// HitSoochi Search Optimization Service
/// Provides semantic search, recommendations, and suggestions for enhanced search
class HitSoochiService {
  // API Configuration - Default to localhost for development
  static String _baseUrl = 'http://localhost:8000';
  static const Duration _timeout = Duration(seconds: 10);

  /// Configure the base URL for the service (e.g. for production)
  static void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
  }

  /// Cached instance for singleton pattern
  static final HitSoochiService _instance = HitSoochiService._internal();
  factory HitSoochiService() => _instance;
  HitSoochiService._internal();

  /// Optimize a search query with domain-specific context
  Future<OptimizedQuery?> optimizeQuery(String query) async {
    if (query.trim().length < 2) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/optimize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return OptimizedQuery.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('HitSoochi: optimizeQuery failed: $e');
    }
    return null;
  }

  /// Get service recommendations based on query intent
  Future<RecommendationResponse?> getRecommendations(String query) async {
    if (query.trim().length < 2) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recommend'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return RecommendationResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('HitSoochi: getRecommendations failed: $e');
    }
    return null;
  }

  /// Get autocomplete suggestions for partial query
  Future<List<Suggestion>> getSuggestions(
    String partial, {
    int limit = 5,
  }) async {
    if (partial.trim().length < 2) return [];

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/suggest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'partial': partial, 'limit': limit}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['suggestions'] as List)
            .map((s) => Suggestion.fromJson(s))
            .toList();
      }
    } catch (e) {
      print('HitSoochi: getSuggestions failed: $e');
    }
    return [];
  }

  /// Rank items by semantic relevance to query
  Future<List<RankedItem>> rankResults(
    String query,
    List<Map<String, String>> items, {
    SearchContext? context,
    FacetFilters? filters,
  }) async {
    if (query.trim().isEmpty || items.isEmpty) return [];

    final body = {'query': query, 'items': items};

    if (context != null) {
      body['context'] = context.toJson();
    }

    if (filters != null) {
      body['filters'] = filters.toJson();
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/rank'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['ranked_items'] as List)
            .map((item) => RankedItem.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('HitSoochi: rankResults failed: $e');
    }
    return [];
  }

  /// Check if the HitSoochi service is available
  Future<bool> isHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ============ Data Models ============

class SearchContext {
  final String platform;
  final String source;

  SearchContext({required this.platform, required this.source});

  Map<String, dynamic> toJson() => {'platform': platform, 'source': source};
}

class FacetFilters {
  final String? category;
  final String? type;
  final bool? featuredOnly;
  final bool? newOnly;

  FacetFilters({this.category, this.type, this.featuredOnly, this.newOnly});

  Map<String, dynamic> toJson() => {
    if (category != null) 'category': category,
    if (type != null) 'type': type,
    if (featuredOnly != null) 'featured_only': featuredOnly,
    if (newOnly != null) 'new_only': newOnly,
  };
}

class OptimizedQuery {
  final String original;
  final String optimized;
  final String intent;
  final String confidence;
  final List<String> seoKeywords;

  OptimizedQuery({
    required this.original,
    required this.optimized,
    required this.intent,
    required this.confidence,
    required this.seoKeywords,
  });

  factory OptimizedQuery.fromJson(Map<String, dynamic> json) => OptimizedQuery(
    original: json['original'] ?? '',
    optimized: json['optimized'] ?? '',
    intent: json['intent'] ?? 'GENERAL',
    confidence: json['confidence'] ?? '0.00',
    seoKeywords: List<String>.from(json['seo_keywords'] ?? []),
  );
}

class ServiceRecommendation {
  final String service;
  final String description;
  final String icon;
  final String url;
  final String cta;

  ServiceRecommendation({
    required this.service,
    required this.description,
    required this.icon,
    required this.url,
    required this.cta,
  });

  factory ServiceRecommendation.fromJson(Map<String, dynamic> json) =>
      ServiceRecommendation(
        service: json['service'] ?? '',
        description: json['description'] ?? '',
        icon: json['icon'] ?? '🔍',
        url: json['url'] ?? '/',
        cta: json['cta'] ?? 'Learn More',
      );
}

class RecommendationResponse {
  final String query;
  final String detectedIntent;
  final String confidence;
  final ServiceRecommendation primaryRecommendation;
  final List<ServiceRecommendation> otherServices;

  RecommendationResponse({
    required this.query,
    required this.detectedIntent,
    required this.confidence,
    required this.primaryRecommendation,
    required this.otherServices,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) =>
      RecommendationResponse(
        query: json['query'] ?? '',
        detectedIntent: json['detected_intent'] ?? 'GENERAL',
        confidence: json['confidence'] ?? '0.00',
        primaryRecommendation: ServiceRecommendation.fromJson(
          json['primary_recommendation'] ?? {},
        ),
        otherServices: (json['other_services'] as List? ?? [])
            .map((s) => ServiceRecommendation.fromJson(s))
            .toList(),
      );
}

class Suggestion {
  final String text;
  final double score;

  Suggestion({required this.text, required this.score});

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    text: json['text'] ?? '',
    score: (json['score'] ?? 0.0).toDouble(),
  );
}

class RankedItem {
  final String? title;
  final String? description;
  final String? category;
  final double relevanceScore;
  final double? editorialBoost;
  final String? boostReason;

  RankedItem({
    this.title,
    this.description,
    this.category,
    required this.relevanceScore,
    this.editorialBoost,
    this.boostReason,
  });

  factory RankedItem.fromJson(Map<String, dynamic> json) => RankedItem(
    title: json['title'],
    description: json['description'],
    category: json['category'],
    relevanceScore: (json['relevance_score'] ?? 0.0).toDouble(),
    editorialBoost: (json['editorial_boost'] ?? 0.0).toDouble(),
    boostReason: json['boost_reason'],
  );
}
