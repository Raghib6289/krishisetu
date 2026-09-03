import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController(text: '9876543210');
  final _nameController = TextEditingController();
  final _otpController = TextEditingController(text: '123456');

  // Email login controllers
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'farmer@krishisetu.com');
  final _passwordController = TextEditingController(text: 'pass123');
  bool _obscurePassword = true;

  bool _isEmailMode = false;
  bool _otpSent = false;
  String _selectedRole = 'farmer';
  String? _statusMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    if (_phoneFormKey.currentState!.validate()) {
      setState(() => _statusMessage = null);
      final res = await ref.read(authProvider.notifier).sendOtp(
            _phoneController.text.trim(),
            userType: _selectedRole,
            name: _nameController.text.trim(),
          );

      if (mounted) {
        if (res['status'] == 'success') {
          setState(() {
            _otpSent = true;
            _statusMessage = res['message'] ?? 'OTP sent successfully!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent! Use demo code: ${res['demo_otp'] ?? '123456'}'),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to send OTP'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _handleVerifyOtp() async {
    if (_otpFormKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).verifyOtpAndLogin(
            _phoneController.text.trim(),
            _otpController.text.trim(),
            userType: _selectedRole,
            name: _nameController.text.trim(),
          );
      if (success && mounted) {
        _navigateByRole();
      }
    }
  }

  void _handleEmailLogin() async {
    if (_emailFormKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      if (success && mounted) {
        _navigateByRole();
      }
    }
  }

  void _demoOtpLogin(String phone, String role, String name) async {
    setState(() {
      _phoneController.text = phone;
      _selectedRole = role;
      _nameController.text = name;
      _otpController.text = '123456';
    });

    // Send and immediately verify
    await ref.read(authProvider.notifier).sendOtp(phone, userType: role, name: name);
    final success = await ref.read(authProvider.notifier).verifyOtpAndLogin(
          phone,
          '123456',
          userType: role,
          name: name,
        );
    if (success && mounted) {
      _navigateByRole();
    }
  }

  void _navigateByRole() {
    final role = ref.read(authProvider).role;
    if (role == UserRole.farmer) {
      context.go('/farmer/dashboard');
    } else if (role == UserRole.buyer) {
      context.go('/buyer/catalog');
    } else if (role == UserRole.driver) {
      context.go('/driver/tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.agriculture_rounded,
                        size: 52,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'KrishiSetu',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Direct Agricultural Marketplace & Smart Logistics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Auth Mode Switcher (Mobile OTP vs Email)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEmailMode = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isEmailMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isEmailMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_android,
                                    size: 18,
                                    color: !_isEmailMode ? AppTheme.primaryGreen : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mobile OTP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: !_isEmailMode ? AppTheme.primaryGreen : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEmailMode = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isEmailMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isEmailMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                    color: _isEmailMode ? AppTheme.primaryGreen : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Email / Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _isEmailMode ? AppTheme.primaryGreen : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // MAIN FORM CONTENT
                  if (!_isEmailMode) ...[
                    // MOBILE NUMBER & OTP FLOW
                    if (!_otpSent) ...[
                      // STEP 1: Enter Phone & Select Role
                      Form(
                        key: _phoneFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Select Your Role',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _RoleSelectChip(
                                  label: '🌾 Farmer',
                                  isSelected: _selectedRole == 'farmer',
                                  onTap: () => setState(() => _selectedRole = 'farmer'),
                                ),
                                const SizedBox(width: 8),
                                _RoleSelectChip(
                                  label: '🛒 Buyer',
                                  isSelected: _selectedRole == 'buyer',
                                  onTap: () => setState(() => _selectedRole = 'buyer'),
                                ),
                                const SizedBox(width: 8),
                                _RoleSelectChip(
                                  label: '🚚 Driver',
                                  isSelected: _selectedRole == 'driver',
                                  onTap: () => setState(() => _selectedRole = 'driver'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Mobile Number Field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: InputDecoration(
                                labelText: '10-Digit Mobile Number',
                                counterText: '',
                                prefixIcon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+91',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(height: 20, width: 1, color: Colors.grey.shade300),
                                    ],
                                  ),
                                ),
                                hintText: '98765 43210',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 10) {
                                  return 'Enter valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Name Field (Optional for existing, used for new auto-reg)
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name (Optional for new users)',
                                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryGreen),
                                hintText: 'e.g. Ramesh Patil',
                              ),
                            ),
                            const SizedBox(height: 20),

                            ElevatedButton(
                              onPressed: authState.isLoading ? null : _handleSendOtp,
                              child: authState.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Send Verification OTP'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // STEP 2: Enter OTP
                      Form(
                        key: _otpFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mark_email_read_outlined, color: AppTheme.primaryGreen, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'OTP sent to +91 ${_phoneController.text}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Demo verification code is: 123456',
                                          style: TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Enter 6-Digit OTP',
                                counterText: '',
                                prefixIcon: Icon(Icons.lock_clock_outlined, color: AppTheme.primaryGreen),
                                hintText: '123456',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 6) {
                                  return 'Enter 6-digit OTP code';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            ElevatedButton(
                              onPressed: authState.isLoading ? null : _handleVerifyOtp,
                              child: authState.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Verify OTP & Login'),
                            ),
                            const SizedBox(height: 10),

                            TextButton.icon(
                              onPressed: () => setState(() => _otpSent = false),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Change Mobile Number'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // EMAIL / PASSWORD FALLBACK
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
                            ),
                            validator: (v) => v!.isEmpty ? 'Please enter email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? 'Please enter password' : null,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: authState.isLoading ? null : _handleEmailLogin,
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Sign In to Account'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      authState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Quick Verified Personas for SIH Evaluation
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: Colors.amber.shade900, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Verified Mobile Numbers (1-Tap Demo)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _VerifiedPersonaChip(
                              title: '🌾 Farmer Ramesh',
                              phone: '+91 98765 43210',
                              color: AppTheme.primaryGreen,
                              onTap: () => _demoOtpLogin('9876543210', 'farmer', 'Ramesh Patil'),
                            ),
                            _VerifiedPersonaChip(
                              title: '🛒 Reliance Retail',
                              phone: '+91 98220 11223',
                              color: AppTheme.accentGold,
                              onTap: () => _demoOtpLogin('9822011223', 'buyer', 'Reliance Fresh Hub'),
                            ),
                            _VerifiedPersonaChip(
                              title: '🚚 Driver Santosh',
                              phone: '+91 94231 88776',
                              color: AppTheme.skyBlue,
                              onTap: () => _demoOtpLogin('9423188776', 'driver', 'Santosh Shinde'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleSelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedPersonaChip extends StatelessWidget {
  final String title;
  final String phone;
  final Color color;
  final VoidCallback onTap;

  const _VerifiedPersonaChip({
    required this.title,
    required this.phone,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
            Text(
              phone,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
