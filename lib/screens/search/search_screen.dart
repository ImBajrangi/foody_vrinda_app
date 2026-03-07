import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/search_service.dart';
import '../menu/menu_screen.dart';
import '../../config/lottie_assets.dart';
import '../../widgets/animations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResult> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final results = await _searchService.search(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToResult(SearchResult result) async {
    if (result.type == 'shop' && result.shop != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MenuScreen(shop: result.shop!)),
      );
    } else if (result.type == 'menuItem' && result.shopId != null) {
      // First fetch the shop, then navigate
      final shop = await _searchService.getShopById(result.shopId!);
      if (shop != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MenuScreen(shop: shop)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search shops, items, cuisines...',
            hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: AnimatedLoader(message: 'Searching...', size: 100),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_results.isEmpty) {
      return _buildNoResults();
    }

    return _buildResults();
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        // Fun background animation
        Positioned(
          bottom: -20,
          right: -20,
          child: Opacity(
            opacity: 0.1,
            child: LottieAssets.build(
              LottieAssets.potato,
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search Nearby Section
            const Text(
              'SEARCH NEARBY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(
                    'Restaurant',
                    Icons.restaurant,
                    Colors.orange,
                    () => _performSearch('restaurant'),
                  ),
                  _buildCategoryChip(
                    'Fast Food',
                    Icons.fastfood,
                    Colors.red,
                    () => _performSearch('fast food'),
                  ),
                  _buildCategoryChip(
                    'Sweets',
                    Icons.cake,
                    Colors.pink,
                    () => _performSearch('sweets'),
                  ),
                  _buildCategoryChip(
                    'Snacks',
                    Icons.local_pizza,
                    Colors.amber,
                    () => _performSearch('snacks'),
                  ),
                  _buildCategoryChip(
                    'Drinks',
                    Icons.local_cafe,
                    Colors.brown,
                    () => _performSearch('drinks'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Popular Shops Section
            _buildSuggestionSection(
              title: 'Popular Shops',
              icon: Icons.trending_up,
            ),
            const SizedBox(height: 12),
            _buildPopularShopsList(),

            const SizedBox(height: 32),

            // Quick Actions Section
            _buildSuggestionSection(title: 'Quick Actions', icon: Icons.bolt),
            const SizedBox(height: 12),
            _buildQuickActionTile(
              'Open Now',
              'Find shops currently open',
              Icons.access_time_filled,
              Colors.green,
              () => _performSearch('open'),
            ),
            _buildQuickActionTile(
              'New Arrivals',
              'Recently added shops',
              Icons.new_releases,
              Colors.blue,
              () => _performSearch('new'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionSection({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPopularShopsList() {
    // This will show the first few shops from Firestore
    return FutureBuilder<List<SearchResult>>(
      future: _searchService.search(''), // Empty query returns all
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // Filter to shops only and take first 5
        final shops = (snapshot.data ?? [])
            .where((r) => r.type == 'shop')
            .take(5)
            .toList();

        if (shops.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No shops available yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return Column(
          children: shops.map((shop) => _buildPopularShopTile(shop)).toList(),
        );
      },
    );
  }

  Widget _buildPopularShopTile(SearchResult shop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: () => _navigateToResult(shop),
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: shop.shop?.isOpen == true ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          shop.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          shop.subtitle ?? '',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      ),
    );
  }

  Widget _buildQuickActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      ),
    );
  }

  Widget _buildNoResults() {
    return const EmptyState(
      title: 'No Results Found',
      subtitle: 'Try a different search term. That cat isn\'t happy either!',
      animationType: 'bad_cat',
    );
  }

  Widget _buildResults() {
    final shops = _results.where((r) => r.type == 'shop').toList();
    final menuItems = _results.where((r) => r.type == 'menuItem').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (shops.isNotEmpty) ...[
          _buildSectionHeader('Shops', Icons.storefront, shops.length),
          const SizedBox(height: 12),
          ...shops.map((r) => _buildResultTile(r)),
          const SizedBox(height: 24),
        ],
        if (menuItems.isNotEmpty) ...[
          _buildSectionHeader(
            'Menu Items',
            Icons.restaurant_menu,
            menuItems.length,
          ),
          const SizedBox(height: 12),
          ...menuItems.map((r) => _buildResultTile(r)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _navigateToResult(result),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 56,
            height: 56,
            color: AppTheme.background,
            child: result.imageUrl != null && result.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: result.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      result.type == 'shop' ? Icons.store : Icons.fastfood,
                      color: AppTheme.textTertiary,
                    ),
                  )
                : Icon(
                    result.type == 'shop' ? Icons.store : Icons.fastfood,
                    color: AppTheme.textTertiary,
                    size: 28,
                  ),
          ),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: result.subtitle != null
            ? Text(
                result.subtitle!,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      ),
    );
  }
}
