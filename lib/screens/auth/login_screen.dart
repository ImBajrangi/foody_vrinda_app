import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/buttons.dart';
import '../../widgets/inputs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Navigate back if authenticated
    if (authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      'https://imbajrangi.github.io/Company/Vrindopnishad%20Web/class/logo/foodyVrinda-logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.restaurant,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Center(
                child: Text(
                  _isLogin ? 'Welcome Back!' : 'Create Account',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isLogin
                      ? 'Sign in to continue ordering your favorites'
                      : 'Sign up to start ordering delicious food',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              // Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppInputField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      // Error message
                      if (authProvider.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.error!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      AppButton(
                        text: _isLogin ? 'Sign In' : 'Sign Up',
                        isFullWidth: true,
                        isLoading: authProvider.isLoading,
                        height: 52,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Toggle login/signup
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                    authProvider.clearError();
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppTheme.textSecondary),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : "Already have an account? ",
                        ),
                        TextSpan(
                          text: _isLogin ? 'Sign Up' : 'Sign In',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Guest option
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_isLogin) {
      authProvider.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      authProvider.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }
}
