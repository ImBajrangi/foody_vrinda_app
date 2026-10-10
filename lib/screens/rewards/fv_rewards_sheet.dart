import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/fv_wallet_service.dart';
import '../../models/fv_wallet_model.dart';
import '../../widgets/pressable_scale.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// FOODY VRINDA REWARDS & DYNASTY SHEET (FLUTTER)
/// 100% Feature, Schema & Design System Parity with Web FVRewardsDashboard
/// ═══════════════════════════════════════════════════════════════════════════

class FVRewardsSheet extends StatefulWidget {
  const FVRewardsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const FVRewardsSheet(),
    );
  }

  @override
  State<FVRewardsSheet> createState() => _FVRewardsSheetState();
}

class _FVRewardsSheetState extends State<FVRewardsSheet> {
  final FVWalletService _walletService = FVWalletService();
  String _activeTab = 'wallet'; // wallet | referral | leaderboard | ledger | community
  String _leaderboardRole = 'customer'; // customer | delivery
  
  FVWalletModel? _wallet;
  bool _isLoading = true;
  List<FVLeaderboardItem> _leaderboard = [];
  bool _isLoadingLeaderboard = false;
  List<FVCommunityLink> _communityLinks = [];
  bool _isLoadingCommunity = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userData?.uid ?? authProvider.user?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final data = await _walletService.getWalletDashboard(userId);
    if (mounted) {
      setState(() {
        _wallet = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    final list = await _walletService.getLeaderboard(
      period: 'all_time',
      role: _leaderboardRole,
      limit: 15,
    );
    if (mounted) {
      setState(() {
        _leaderboard = list;
        _isLoadingLeaderboard = false;
      });
    }
  }

  Future<void> _loadCommunityLinks() async {
    setState(() => _isLoadingCommunity = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = authProvider.userData?.role.toString().split('.').last ?? 'customer';
    final links = await _walletService.getCommunityLinks(role: role);
    if (mounted) {
      setState(() {
        _communityLinks = links;
        _isLoadingCommunity = false;
      });
    }
  }

  void _onTabChanged(String tab) {
    HapticFeedback.selectionClick();
    setState(() => _activeTab = tab);
    if (tab == 'leaderboard' && _leaderboard.isEmpty) {
      _loadLeaderboard();
    } else if (tab == 'community' && _communityLinks.isEmpty) {
      _loadCommunityLinks();
    }
  }

  void _copyReferralCode() {
    final code = _wallet?.referralCode ?? 'FVPROMO';
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareOnWhatsApp() async {
    final code = _wallet?.referralCode ?? 'FVPROMO';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = authProvider.userData?.role.toString().split('.').last ?? 'customer';
    final url = _walletService.generateWhatsAppShareUrl(code, role: role);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userData?.uid ?? authProvider.user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF1E1B1C) : const Color(0xFFFCFBF7);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E5E4);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.8 : 0.25),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Unified Top Header with Mobile Grab Pill
              Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Column(
                  children: [
                    // Grab Pill Indicator
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFD6D3D1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Header Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          // Radiant Crown Medallion
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD84D), Color(0xFFF59E0B)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFC97A00).withValues(alpha: 0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.workspace_premium, color: Color(0xFF1E1B1C), size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Title and Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FV Rewards',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Outfit',
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Earn & redeem points on your orders',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF78716C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Close Button
                          PressableScale(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF282526) : const Color(0xFFF5F5F4),
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF57534E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // 2. Chunky Segmented Nav Bar (Vault, Quests, League, History, Club)
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141213) : const Color(0xFFF5F5F4),
                  border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _buildNavTab('wallet', 'Vault', Icons.account_balance_wallet_outlined, const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    _buildNavTab('referral', 'Quests', Icons.card_giftcard_outlined, const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _buildNavTab('leaderboard', 'League', Icons.emoji_events_outlined, const Color(0xFFEAB308)),
                    const SizedBox(width: 8),
                    _buildNavTab('ledger', 'History', Icons.history, const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _buildNavTab('community', 'Club', Icons.chat_bubble_outline, const Color(0xFF22C55E)),
                  ],
                ),
              ),

              // 3. Tab Content
              Expanded(
                child: userId == null
                    ? _buildUnauthenticatedView()
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD000)))
                        : _buildTabContent(scrollController),
              ),

              // 4. Modal Bottom Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: sheetBg,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Points are automatically applied at checkout',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF78716C),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    PressableScale(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282526) : const Color(0xFFE7E5E4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'CLOSE',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavTab(String id, String label, IconData icon, Color color) {
    final isActive = _activeTab == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onTap: () => _onTabChanged(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFFFFD000) : const Color(0xFF1C1917))
              : (isDark ? const Color(0xFF221F20) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? (isDark ? const Color(0xFFE5B800) : const Color(0xFF0C0A09))
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE7E5E4)),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isDark ? const Color(0xFFFFD000) : Colors.black).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive
                  ? (isDark ? const Color(0xFF100E0F) : Colors.white)
                  : color,
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isActive
                    ? (isDark ? const Color(0xFF100E0F) : Colors.white)
                    : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF57534E)),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(ScrollController controller) {
    switch (_activeTab) {
      case 'wallet':
        return _buildVaultTab(controller);
      case 'referral':
        return _buildQuestsTab(controller);
      case 'leaderboard':
        return _buildLeagueTab(controller);
      case 'ledger':
        return _buildHistoryTab(controller);
      case 'community':
        return _buildClubTab(controller);
      default:
        return _buildVaultTab(controller);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. VAULT TAB (Balances, Conversion, Tier Medallion)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVaultTab(ScrollController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = _wallet?.availablePoints ?? 0.0;
    final rupees = _walletService.pointsToRupees(points);
    final cardBg = isDark ? const Color(0xFF282526) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E5E4);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        // Hero Balance Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD84D), Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PRASAD BALANCE',
                      style: TextStyle(
                        color: Color(0xFF1E1B1C),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Icon(Icons.bolt, color: Color(0xFF1E1B1C), size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    points.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFF1E1B1C),
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FV Points',
                    style: TextStyle(
                      color: Color(0xFF1E1B1C),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '≈ ₹${rupees.toStringAsFixed(2)} instant discount on checkout',
                style: const TextStyle(
                  color: Color(0xFF1E1B1C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3 Key Benefit Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                '₹0.10',
                'Per FV Point',
                Icons.currency_rupee,
                const Color(0xFF10B981),
                cardBg,
                borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                '${_wallet?.lifetimeEarned.toInt() ?? 0}',
                'Lifetime Earned',
                Icons.trending_up,
                const Color(0xFF3B82F6),
                cardBg,
                borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                '${_wallet?.totalReferrals ?? 0}',
                'Devotees Invited',
                Icons.people_outline,
                const Color(0xFFEC4899),
                cardBg,
                borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // How Points Work
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFFD000), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'How Prasad Points Work',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildBulletRule('Earn 5% points on every Satvik order automatically.'),
              _buildBulletRule('Redeem instantly at checkout with zero minimum threshold.'),
              _buildBulletRule('Invite friends and get 150 bonus points when they order.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String value, String label, IconData icon, Color color, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFFFD000), fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. QUESTS / REFERRAL TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuestsTab(ScrollController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF282526) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E5E4);
    final referralCode = _wallet?.referralCode ?? 'FVPROMO';

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        // Referral Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0E2619) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRASAD QUEST',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Icon(Icons.volunteer_activism_outlined, color: Color(0xFF10B981), size: 20),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Invite Devotees to Foody Vrinda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share your unique code. Both of you earn 150 FV Points (₹15 OFF) upon their first order delivery.',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Referral Code Pill Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR REFERRAL CODE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    referralCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      letterSpacing: 1.5,
                      color: Color(0xFFFFD000),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  PressableScale(
                    onTap: _copyReferralCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _copied ? const Color(0xFF10B981) : (isDark ? const Color(0xFF383335) : const Color(0xFFE7E5E4)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(_copied ? Icons.check : Icons.copy, size: 14, color: _copied ? Colors.white : null),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'COPIED' : 'COPY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _copied ? Colors.white : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // WhatsApp Share Button
        PressableScale(
          onTap: _shareOnWhatsApp,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'SHARE ON WHATSAPP',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. LEAGUE / LEADERBOARD TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLeagueTab(ScrollController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF282526) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E5E4);
    final authProvider = Provider.of<AuthProvider>(context);
    final myUserId = authProvider.userData?.uid ?? authProvider.user?.id;

    return Column(
      children: [
        // Role Toggle (Customer vs Delivery Fleet)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: () {
                    setState(() => _leaderboardRole = 'customer');
                    _loadLeaderboard();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _leaderboardRole == 'customer' ? const Color(0xFFFFD000) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'DEVOTEES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _leaderboardRole == 'customer' ? const Color(0xFF100E0F) : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressableScale(
                  onTap: () {
                    setState(() => _leaderboardRole = 'delivery');
                    _loadLeaderboard();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _leaderboardRole == 'delivery' ? const Color(0xFFFFD000) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SARATHI FLEET',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _leaderboardRole == 'delivery' ? const Color(0xFF100E0F) : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Leaderboard List
        Expanded(
          child: _isLoadingLeaderboard
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD000)))
              : _leaderboard.isEmpty
                  ? const Center(child: Text('No rank entries yet', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        final item = _leaderboard[index];
                        final isMe = item.userId == myUserId;
                        final rank = index + 1;
                        final maskedName = FVWalletService.maskLeaderboardName(item.displayName, isMe);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFFFD000).withValues(alpha: 0.15) : cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMe ? const Color(0xFFFFD000) : borderColor,
                              width: isMe ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank Medal / Number
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? const Color(0xFFFFD700)
                                      : rank == 2
                                          ? const Color(0xFFC0C0C0)
                                          : rank == 3
                                              ? const Color(0xFFCD7F32)
                                              : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  rank <= 3 ? '👑' : '#$rank',
                                  style: TextStyle(
                                    fontSize: rank <= 3 ? 14 : 11,
                                    fontWeight: FontWeight.w900,
                                    color: rank <= 3 ? Colors.black : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          maskedName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFD000),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'YOU',
                                              style: TextStyle(color: Colors.black, fontSize: 8.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${item.referralsCount} referrals',
                                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),

                              // Points
                              Text(
                                '${item.pointsEarned.toInt()} FV',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Outfit',
                                  color: Color(0xFFFFD000),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. HISTORY / LEDGER TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryTab(ScrollController controller) {
    final transactions = _wallet?.recentTransactions ?? [];
    if (transactions.isEmpty) {
      return const Center(child: Text('No points transactions yet', style: TextStyle(color: Colors.grey)));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF282526) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E5E4);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(20),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isCredit = tx.amount > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCredit ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.notes ?? tx.transactionType.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.createdAt.toString().split('.').first,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '${isCredit ? '+' : ''}${tx.amount.toInt()} FV',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit',
                  color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. CLUB / COMMUNITY TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildClubTab(ScrollController controller) {
    if (_isLoadingCommunity) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD000)));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF282526) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E5E4);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(20),
      itemCount: _communityLinks.length,
      itemBuilder: (context, index) {
        final link = _communityLinks[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.forum_outlined, color: Color(0xFF25D366), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.description ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              PressableScale(
                onTap: () async {
                  final uri = Uri.parse(link.linkUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'JOIN',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFFFFD000)),
            const SizedBox(height: 14),
            const Text(
              'Sign in to access FV Rewards',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Earn points on every Satvik order and invite friends to earn ₹15 cashback.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD000),
                foregroundColor: Colors.black,
              ),
              child: const Text('Back to Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
