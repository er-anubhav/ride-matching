import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';

// 1. Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Redirect after delay based on JWT token authentication status
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      // Request location permission proactively so the map screen is ready
      await _requestLocationPermission();

      if (!mounted) return;
      final token = await ApiClient().getToken();
      if (mounted) {
        if (token != null && token.isNotEmpty) {
          context.go('/home');
        } else {
          context.go('/auth/phone');
        }
      }
    });

  }

  /// Ensures location services are enabled and permission is granted.
  /// Shows the system permission dialog if needed.
  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return; // Let the provider handle the error state

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Silently ignore — the provider will surface the error on the map
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary, // Brand purple background
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Official Mr. Rideo Logo
              Image.asset(
                'assets/logo.jpeg',
                width: 240,
              ),
              const SizedBox(height: 16),
              Text(
                "Your ride, elevated.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. Phone Entry Screen
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {
        _isValid = _phoneController.text.length >= 10;
      });
    });
  }

  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _startSecretGestureTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(seconds: 10), () {
      _executeSecretLogin();
    });
  }

  void _cancelSecretGestureTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  Future<void> _executeSecretLogin() async {
    setState(() {
      _isLoading = true;
      _phoneController.text = "9999999999";
    });
    try {
      final response = await ApiClient().post('/auth/otp/verify', {
        'phone': '+919999999999',
        'code': '1234',
        'role': 'RIDER',
      });
      if (response != null && response['token'] != null) {
        await ApiClient().saveToken(response['token']);
        final user = response['user'] as Map<String, dynamic>?;
        ref.read(userProfileProvider.notifier).updateProfile(
              phone: user?['phone'] ?? '+919999999999',
              name: user?['name'] ?? 'Test Rider',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚡ 10s Secret Gesture: Test Rider Logged In!')),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Secret login failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {},
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter your mobile number",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "We will send you a verification code to authenticate your account.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              // Phone Input Field Row
              Row(
                children: [
                  // Country Code Pill (Secret 10-Second Long Press Gesture Listener)
                  GestureDetector(
                    onLongPressDown: (_) => _startSecretGestureTimer(),
                    onLongPressEnd: (_) => _cancelSecretGestureTimer(),
                    onLongPressCancel: () => _cancelSecretGestureTimer(),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            "🇮🇳",
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "+91",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Phone Number Text Field
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: "98765 43210",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Actions
              PrimaryButton(
                text: "Continue",
                isLoading: _isLoading,
                onPressed: _isValid
                    ? () async {
                        setState(() {
                          _isLoading = true;
                        });
                        final phone = '+91${_phoneController.text.trim()}';
                        try {
                          await ApiClient().post('/auth/otp/request', {
                            'phone': phone,
                          });
                          if (mounted) {
                            context.push('/auth/otp', extra: phone);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to request OTP: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      }
                    : () {},
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                text: "Continue with Google",
                icon: const Icon(LucideIcons.chrome, size: 20),
                onPressed: () {
                  context.push('/auth/otp');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  bool _isLoading = false;

  Future<void> _verifyOtp(String otp) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient().post('/auth/otp/verify', {
        'phone': widget.phone,
        'code': otp,
        'role': 'RIDER',
      });

      if (response != null && response['token'] != null) {
        await ApiClient().saveToken(response['token']);
        final user = response['user'] as Map<String, dynamic>?;
        ref.read(userProfileProvider.notifier).updateProfile(
              phone: user?['phone'] ?? widget.phone,
              name: user?['name'],
            );
        if (mounted) {
          context.go('/auth/profile-setup');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify OTP: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Verification Code",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Enter the 4-digit code sent to +91 98765 43210",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              // OTP digits boxes
              OtpInputField(
                length: 4,
                onCompleted: (code) {
                  _verifyOtp(code);
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    "Resend Code in 24s",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                text: "Verify & Continue",
                isLoading: _isLoading,
                onPressed: () {
                  _verifyOtp("1234");
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. Profile Setup Screen
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              context.go('/home');
            },
            child: Text(
              "Skip",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Setup Profile",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Tell us a bit about yourself so drivers can identify you.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              // Profile Upload Circle
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: AppColors.surface,
                      child: Icon(
                        LucideIcons.user,
                        size: 44,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Name text field
              TextField(
                controller: _nameController,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: "Full Name",
                  prefixIcon: Icon(LucideIcons.user, size: 20, color: AppColors.textMuted),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                text: "Save & Proceed",
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isNotEmpty) {
                    ref.read(userProfileProvider.notifier).updateName(name);
                  }
                  FocusScope.of(context).unfocus();
                  context.go('/home');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
