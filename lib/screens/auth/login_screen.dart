import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/theme.dart';
import '../../widgets/pressable_scale.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Master Authentication & Devotee Profile View
/// Directly synchronized with Foody Vrinda Web v3 (AuthModal.jsx)
class LoginScreen extends StatefulWidget {
  final bool startInSignUp;
  final String? initialDesk;

  const LoginScreen({
    super.key,
    this.startInSignUp = false,
    this.initialDesk,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Navigation & View Mode
  String _selectedDesk = 'customer'; // customer, kitchen, delivery, owner, developer
  String _loginMethod = 'phone'; // 'phone' | 'email'
  bool _isSignup = false;
  int _signupStep = 1; // 1: Identity, 2: Security, 3: Delivery
  bool _showStaffSignIn = false;
  bool _showLoginView = false; // When authenticated but switching account

  // Form Controllers
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final _signupAddressController = TextEditingController();

  // Profile Inline Editing Controllers
  bool _isEditingName = false;
  final _nameEditController = TextEditingController();
  bool _isEditingPhone = false;
  final _phoneEditController = TextEditingController();
  bool _isEditingAddress = false;
  final _addressEditController = TextEditingController();

  bool _obscurePassword = true;
  String? _localError;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _isSignup = widget.startInSignUp;
    if (widget.initialDesk != null) {
      _selectedDesk = widget.initialDesk!;
      _showStaffSignIn = true;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).userData;
    if (user != null) {
      _nameEditController.text = user.displayName ?? '';
      _phoneEditController.text = user.phoneNumber ?? '';
      _addressEditController.text = user.deliveryAddress ?? '';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _signupPhoneController.dispose();
    _signupAddressController.dispose();
    _nameEditController.dispose();
    _phoneEditController.dispose();
    _addressEditController.dispose();
    super.dispose();
  }

  void _showSuccess(String msg) {
    setState(() {
      _successMessage = msg;
      _localError = null;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _successMessage = null);
    });
  }

  // 1. Phone Lookup Login
  Future<void> _handlePhoneSubmit() async {
    final clean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10) {
      setState(() => _localError = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    setState(() => _localError = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signInWithPhoneLookup(clean);

    if (success && mounted) {
      _showSuccess('Welcome back, ${auth.userData?.displayName ?? 'Devotee'}!');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  // 2. Multi-step Registration Next Step
  void _handleNextStep() {
    setState(() => _localError = null);

    if (_signupStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _localError = 'Please enter your full name.');
        return;
      }
      final clean = _signupPhoneController.text.replaceAll(RegExp(r'\D'), '');
      if (clean.length < 10) {
        setState(() => _localError = 'Please enter a valid 10-digit mobile number.');
        return;
      }
      setState(() => _signupStep = 2);
    } else if (_signupStep == 2) {
      if (!_emailController.text.contains('@')) {
        setState(() => _localError = 'Please enter a valid email address.');
        return;
      }
      if (_passwordController.text.length < 6) {
        setState(() => _localError = 'Password must be at least 6 characters.');
        return;
      }
      setState(() => _signupStep = 3);
    }
  }

  // 3. Email Submit (Login or Final Step of Registration)
  Future<void> _handleEmailSubmit() async {
    if (_isSignup && _signupStep < 3) {
      _handleNextStep();
      return;
    }

    setState(() => _localError = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_isSignup) {
      success = await auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        displayName: _nameController.text.trim(),
        phoneNumber: _signupPhoneController.text.trim(),
        deliveryAddress: _signupAddressController.text.trim(),
      );
    } else {
      success = await auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (success && mounted) {
      _showSuccess(_isSignup ? 'Account created successfully!' : 'Signed in successfully!');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  // 4. Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    setState(() => _localError = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  // 5. Save Inline Profile Edits
  Future<void> _saveProfileEdits() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userData;
    if (user == null) return;

    await auth.updateProfile(
      displayName: _nameEditController.text.trim().isNotEmpty
          ? _nameEditController.text.trim()
          : (user.displayName ?? 'Devotee'),
      phoneNumber: _phoneEditController.text.trim().isNotEmpty
          ? _phoneEditController.text.trim()
          : (user.phoneNumber ?? ''),
      deliveryAddress: _addressEditController.text.trim().isNotEmpty
          ? _addressEditController.text.trim()
          : (user.deliveryAddress ?? ''),
    );

    setState(() {
      _isEditingName = false;
      _isEditingPhone = false;
      _isEditingAddress = false;
    });
    _showSuccess('Profile updated successfully!');
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userData;
    final isAuth = auth.isAuthenticated && user != null && user.displayName != 'Devotee Guest';

    return Scaffold(
      backgroundColor: const Color(0xFF121011),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Modal Bar with Close Button
                  _buildHeaderRow(isAuth, user),
                  const SizedBox(height: 16),

                  // Error Banner
                  if (_localError != null || auth.error != null)
                    _buildAlertBanner(
                      _localError ?? auth.error!,
                      isError: true,
                      onClear: () {
                        setState(() => _localError = null);
                        auth.clearError();
                      },
                    ),

                  // Success Banner
                  if (_successMessage != null)
                    _buildAlertBanner(_successMessage!, isError: false),

                  const SizedBox(height: 12),

                  // Body Content: Authenticated Card OR Sign-In / Sign-Up Form
                  if (isAuth && !_showLoginView)
                    _buildAuthenticatedProfileView(user, auth)
                  else
                    _buildSignInPortal(auth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top Header Row with Icon / Avatar & Close Button
  Widget _buildHeaderRow(bool isAuth, UserModel? user) {
    String title;
    String subtitle;

    if (isAuth && !_showLoginView) {
      title = 'Devotee Profile';
      subtitle = user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty
          ? '+91 ${user.phoneNumber}'
          : (user?.email ?? 'Verified Satvik Member');
    } else if (_showStaffSignIn) {
      title = _selectedDesk == 'kitchen'
          ? 'Kitchen Operations'
          : (_selectedDesk == 'delivery'
              ? 'Sarathi Fleet'
              : 'Store Owner Portal');
      subtitle = 'Authorized station login & management';
    } else if (_isSignup) {
      title = _signupStep == 1
          ? 'Step 1: Your Identity'
          : (_signupStep == 2 ? 'Step 2: Account Security' : 'Step 3: Delivery Location');
      subtitle = _signupStep == 1
          ? 'Enter your name and mobile number'
          : (_signupStep == 2 ? 'Set email and secure password' : 'Set delivery address in Vrindavan');
    } else {
      title = _showLoginView ? 'Switch Account' : 'Welcome to Foody Vrinda';
      subtitle = _showLoginView ? 'Sign in with another mobile or email' : 'Authentic Satvik Cloud Kitchen & Prasad';
    }

    return Row(
      children: [
        // Left Badge / Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B1C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE0FF33).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0FF33).withValues(alpha: 0.15),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: isAuth && !_showLoginView
                ? Text(
                    user?.initials ?? 'V',
                    style: const TextStyle(
                      color: Color(0xFFE0FF33),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  )
                : const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Color(0xFFE0FF33),
                    size: 22,
                  ),
          ),
        ),
        const SizedBox(width: 14),

        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Close Button
        PressableScale(
          onTap: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.close, color: Color(0xFFA1A1AA), size: 18),
          ),
        ),
      ],
    );
  }

  /// Alert Banner Widget
  Widget _buildAlertBanner(String message, {required bool isError, VoidCallback? onClear}) {
    final bg = isError ? const Color(0xFFE11D48).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12);
    final border = isError ? const Color(0xFFE11D48).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3);
    final textCol = isError ? const Color(0xFFFDA4AF) : const Color(0xFF6EE7B7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: textCol, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textCol, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, color: textCol, size: 16),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0);
  }

  // ========================================================================
  // AUTHENTICATED PROFILE VIEW (MASTER DEVOTEE CARD)
  // ========================================================================
  Widget _buildAuthenticatedProfileView(UserModel user, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. MASTER DEVOTEE CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181617),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Name & Role Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _isEditingName
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameEditController,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: const Color(0xFF221F20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE0FF33)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: _saveProfileEdits,
                                icon: const Icon(Icons.check, color: Color(0xFFE0FF33), size: 20),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.displayName ?? 'Devotee Member',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(() => _isEditingName = true),
                                child: const Icon(Icons.edit_outlined, color: Color(0xFFA1A1AA), size: 16),
                              ),
                            ],
                          ),
                  ),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0FF33).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE0FF33).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      user.role.value.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE0FF33),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),

              if (user.email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(color: Color(0xFF71717A), fontSize: 12, fontFamily: 'monospace'),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 14),

              // Contact & Delivery Address Quick Pills
              Row(
                children: [
                  // Phone Pill
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B1C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, color: Color(0xFFE0FF33), size: 14),
                              SizedBox(width: 4),
                              Text('MOBILE', style: TextStyle(color: Color(0xFF71717A), fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.phoneNumber != null && user.phoneNumber!.isNotEmpty
                                ? '+91 ${user.phoneNumber}'
                                : 'Not added',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Address Pill
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isEditingAddress = !_isEditingAddress),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B1C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.location_on_outlined, color: Color(0xFFE0FF33), size: 14),
                                SizedBox(width: 4),
                                Text('ADDRESS', style: TextStyle(color: Color(0xFF71717A), fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.deliveryAddress != null && user.deliveryAddress!.isNotEmpty
                                  ? user.deliveryAddress!
                                  : 'Tap to add',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Expandable Address Form
              if (_isEditingAddress) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141213),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0FF33).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _addressEditController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: const InputDecoration(
                          hintText: 'Enter delivery address in Vrindavan...',
                          hintStyle: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Landmark Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          'Near ISKCON Temple',
                          'Prem Mandir Area',
                          'Parikrama Marg',
                          'Chhatikara Road',
                        ].map((loc) {
                          return GestureDetector(
                            onTap: () => setState(() => _addressEditController.text = loc),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Text('+ $loc', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 10, fontWeight: FontWeight.w500)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isEditingAddress = false),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveProfileEdits,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE0FF33),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Save Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),

              // Prasad Rewards Strip
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0FF33).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFFE0FF33), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('150 Coins', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Text('₹15 savings on orders', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.verified_user_outlined, color: Color(0xFF06B6D4), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dham Express', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Text('Priority Bhog Prep', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. SHORTCUTS (WhatsApp Channel)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181617),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF10B981), size: 20),
                title: const Text('Official WhatsApp Channel', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Join', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                onTap: () async {
                  final uri = Uri.parse('https://whatsapp.com/channel/0029Va9xyz');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
              ),
            ],
          ),
        ),

        // 3. OPERATIONAL ROLE SWITCHER (Dev & Admin only)
        if (auth.isAdmin || auth.isDeveloper) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF181617),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0FF33).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('OPERATIONAL SWITCHER', style: TextStyle(color: Color(0xFFE0FF33), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text('DEVELOPER ROOT', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRoleChip(auth, UserRole.customer, 'Storefront', Icons.storefront_outlined),
                    _buildRoleChip(auth, UserRole.kitchen, 'Kitchen KDS', Icons.soup_kitchen_outlined),
                    _buildRoleChip(auth, UserRole.delivery, 'Rider Board', Icons.delivery_dining_outlined),
                    _buildRoleChip(auth, UserRole.owner, 'Store Owner', Icons.admin_panel_settings_outlined),
                    _buildRoleChip(auth, UserRole.developer, 'Dev Console', Icons.terminal_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 4. DUAL ACTION BAR (Switch Account & Sign Out)
        Row(
          children: [
            Expanded(
              child: PressableScale(
                onTap: () => setState(() => _showLoginView = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync_alt, color: Color(0xFFE0FF33), size: 16),
                      SizedBox(width: 8),
                      Text('Switch Account', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: PressableScale(
                onTap: () async {
                  await auth.signOut();
                  if (mounted && Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Color(0xFFFDA4AF), size: 16),
                      SizedBox(width: 8),
                      Text('Sign Out', style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleChip(AuthProvider auth, UserRole role, String label, IconData icon) {
    final isSelected = auth.userData?.role == role;
    return GestureDetector(
      onTap: () => auth.switchRole(role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0FF33) : const Color(0xFF221F20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFE0FF33) : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : const Color(0xFFA1A1AA)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : const Color(0xFFA1A1AA),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SIGN-IN & STEP-BY-STEP REGISTRATION PORTAL
  // ========================================================================
  Widget _buildSignInPortal(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showLoginView) ...[
          GestureDetector(
            onTap: () => setState(() => _showLoginView = false),
            child: const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: Color(0xFFE0FF33), size: 16),
                  SizedBox(width: 6),
                  Text('Back to active profile', style: TextStyle(color: Color(0xFFE0FF33), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],

        // Sub-Navigation Tabs: Mobile vs Email
        if (!_isSignup)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF181617),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMethodTab(
                    title: 'Mobile Number',
                    icon: Icons.phone_iphone_rounded,
                    isSelected: _loginMethod == 'phone',
                    onTap: () => setState(() => _loginMethod = 'phone'),
                  ),
                ),
                Expanded(
                  child: _buildMethodTab(
                    title: 'Email & Password',
                    icon: Icons.email_outlined,
                    isSelected: _loginMethod == 'email',
                    onTap: () => setState(() => _loginMethod = 'email'),
                  ),
                ),
              ],
            ),
          ),

        // Step Progress Bar for Sign-Up
        if (_isSignup) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF181617),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildStepDot(1, 'Identity'),
                    _buildStepLine(1),
                    _buildStepDot(2, 'Security'),
                    _buildStepLine(2),
                    _buildStepDot(3, 'Delivery'),
                  ],
                ),
                Text('$_signupStep/3', style: const TextStyle(color: Color(0xFFE0FF33), fontWeight: FontWeight.w900, fontSize: 12)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 1. MOBILE PHONE FORM
        if (!_isSignup && _loginMethod == 'phone') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF181617),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Text('+91', style: TextStyle(color: Color(0xFFE0FF33), fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(width: 12),
                const SizedBox(height: 24, child: VerticalDivider(color: Colors.white24, width: 1)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Enter 10-digit mobile number',
                      hintStyle: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Instant sign-in for customers, kitchen chefs, and riders.',
            style: TextStyle(color: Color(0xFF71717A), fontSize: 11.5),
          ),
          const SizedBox(height: 16),

          // Sign-In with Mobile Button
          PressableScale(
            onTap: auth.isLoading ? null : _handlePhoneSubmit,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE0FF33),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0FF33).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: auth.isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sign In with Mobile', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],

        // 2. EMAIL FORM / MULTI-STEP SIGNUP
        if (_isSignup || _loginMethod == 'email') ...[
          if (_isSignup && _signupStep == 1) ...[
            // STEP 1: IDENTITY
            _buildInputField('Full Name', _nameController, Icons.person_outline, hint: 'e.g. Radhe Shyam'),
            const SizedBox(height: 12),
            _buildInputField('Mobile Number', _signupPhoneController, Icons.phone_iphone_rounded, hint: '10-digit mobile', isPhone: true),
          ] else if (_isSignup && _signupStep == 2) ...[
            // STEP 2: CREDENTIALS
            _buildInputField('Email Address', _emailController, Icons.email_outlined, hint: 'user@example.com', isEmail: true),
            const SizedBox(height: 12),
            _buildPasswordField(),
          ] else if (_isSignup && _signupStep == 3) ...[
            // STEP 3: DELIVERY LOCATION
            _buildInputField('Default Delivery Address', _signupAddressController, Icons.location_on_outlined, hint: 'e.g. Raman Reti, Vrindavan'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'Near ISKCON Temple',
                'Prem Mandir Area',
                'Parikrama Marg',
                'Chhatikara Road',
              ].map((loc) {
                return GestureDetector(
                  onTap: () => setState(() => _signupAddressController.text = loc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text('+ $loc', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            // STANDARD EMAIL LOGIN
            _buildInputField('Email Address', _emailController, Icons.email_outlined, hint: 'Enter your email', isEmail: true),
            const SizedBox(height: 12),
            _buildPasswordField(),
          ],

          const SizedBox(height: 16),

          // Primary Email Action Button
          PressableScale(
            onTap: auth.isLoading ? null : (_isSignup && _signupStep < 3 ? _handleNextStep : _handleEmailSubmit),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE0FF33),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0FF33).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: auth.isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignup
                                ? (_signupStep < 3 ? 'Continue to Step ${_signupStep + 1}' : 'Create Satvik Account')
                                : 'Sign In with Email',
                            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Toggle Registration Mode
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _isSignup = !_isSignup;
                _signupStep = 1;
                _localError = null;
              });
            },
            child: Text(
              _isSignup ? 'Already have an account? Sign In' : 'New devotee? Create Account in 3 Steps',
              style: const TextStyle(color: Color(0xFFE0FF33), fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.white12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(color: Color(0xFF71717A), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: Colors.white12)),
          ],
        ),
        const SizedBox(height: 16),

        // Google Sign-In Button
        PressableScale(
          onTap: auth.isLoading ? null : _handleGoogleSignIn,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF181617),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Center(
                    child: Image.network(
                      'https://developers.google.com/static/identity/images/g-logo.png',
                      width: 14,
                      height: 14,
                      errorBuilder: (_, __, ___) => const Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Continue with Google', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Guest Continue Option
        Center(
          child: TextButton(
            onPressed: () async {
              await auth.signInAnonymously();
              if (mounted && Navigator.canPop(context)) Navigator.pop(context);
            },
            child: const Text('Continue as Guest', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF282526) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFFE0FF33) : const Color(0xFF71717A)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _signupStep == step;
    final isDone = _signupStep > step;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE0FF33)
                : (isDone ? const Color(0xFFE0FF33).withValues(alpha: 0.2) : Colors.white10),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 12, color: Color(0xFFE0FF33))
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.black : const Color(0xFFA1A1AA),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF71717A),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    return Container(
      width: 14,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: _signupStep > step ? const Color(0xFFE0FF33) : Colors.white12,
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    bool isEmail = false,
    bool isPhone = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF181617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF71717A), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isEmail
                  ? TextInputType.emailAddress
                  : (isPhone ? TextInputType.phone : TextInputType.text),
              maxLength: isPhone ? 10 : null,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 12),
                border: InputBorder.none,
                counterText: '',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF181617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF71717A), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                hintText: 'Min 6 characters',
                hintStyle: TextStyle(color: Color(0xFF52525B), fontSize: 12),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF71717A),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
