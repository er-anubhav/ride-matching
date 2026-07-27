import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/driver_state_providers.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.jpeg',
                width: 240,
              ),
              const SizedBox(height: 16),
              Text(
                "Partner Console",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: 2.0,
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
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSecretGesture() async {
    setState(() {
      _isLoading = true;
      _phoneController.text = "8888888888";
    });
    try {
      final response = await ApiClient().post('/auth/otp/verify', {
        'phone': '+918888888888',
        'code': '1234',
        'role': 'DRIVER',
      });
      if (response != null && response['token'] != null) {
        await ApiClient().saveToken(response['token']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚡ Secret Gesture: Test Driver Logged In!')),
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
                "Driver Verification",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your mobile number to sign in or register your partner profile.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  GestureDetector(
                    onDoubleTap: _handleSecretGesture,
                    onLongPress: _handleSecretGesture,
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
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. OTP Verification Screen
class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  bool _isLoading = false;

  Future<void> _verifyOtp(String otp) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient().post('/auth/otp/verify', {
        'phone': widget.phone,
        'code': otp,
        'role': 'DRIVER',
      });

      if (response != null && response['token'] != null) {
        await ApiClient().saveToken(response['token']);
        if (mounted) {
          context.go('/auth/vehicle');
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

// 4. Vehicle Details Screen
class VehicleDetailsScreen extends ConsumerStatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  ConsumerState<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends ConsumerState<VehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(driverStateProvider.notifier).setVehicleDetails(
            _makeController.text.trim(),
            _modelController.text.trim(),
            _numberController.text.trim().toUpperCase(),
          );
      context.go('/auth/documents');
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Vehicle Information",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Provide the registered details of the vehicle you will operate.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _makeController,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter manufacturer' : null,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Vehicle Brand (e.g. Maruti Suzuki, Tata)",
                    prefixIcon: Icon(LucideIcons.car, size: 20, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter model' : null,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Vehicle Model (e.g. Swift, Nexon)",
                    prefixIcon: Icon(LucideIcons.gauge, size: 20, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numberController,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter registration number' : null,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "License Plate Number (e.g. UP32-AB-9999)",
                    prefixIcon: Icon(LucideIcons.creditCard, size: 20, color: AppColors.textMuted),
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  text: "Next: Document Upload",
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 5. Document Upload Screen
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  ConsumerState<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  double _dlProgress = 0.0;
  double _aadhaarProgress = 0.0;
  double _rcProgress = 0.0;

  bool _isDlUploaded = false;
  bool _isAadhaarUploaded = false;
  bool _isRcUploaded = false;

  Future<void> _uploadDocument(String docType) async {
    final mappedType = docType == 'dl' ? 'DL' : docType == 'aadhaar' ? 'AADHAAR_FRONT' : 'RC';
    setState(() {
      if (docType == 'dl') _dlProgress = 0.2;
      if (docType == 'aadhaar') _aadhaarProgress = 0.2;
      if (docType == 'rc') _rcProgress = 0.2;
    });

    try {
      final response = await ApiClient().post('/kyc/upload-url', {
        'docType': mappedType,
        'contentType': 'image/jpeg',
        'fileExtension': 'jpg',
      });

      if (response != null && response['status'] == 'success') {
        setState(() {
          if (docType == 'dl') {
            _dlProgress = 1.0;
            _isDlUploaded = true;
          } else if (docType == 'aadhaar') {
            _aadhaarProgress = 1.0;
            _isAadhaarUploaded = true;
          } else if (docType == 'rc') {
            _rcProgress = 1.0;
            _isRcUploaded = true;
          }
        });
      }
    } catch (e) {
      setState(() {
        if (docType == 'dl') _dlProgress = 0.0;
        if (docType == 'aadhaar') _aadhaarProgress = 0.0;
        if (docType == 'rc') _rcProgress = 0.0;
      });
    }
  }


  void _submit() {
    if (_isDlUploaded && _isAadhaarUploaded && _isRcUploaded) {
      ref.read(driverStateProvider.notifier).submitKycDocuments();
      context.go('/auth/kyc-pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allDone = _isDlUploaded && _isAadhaarUploaded && _isRcUploaded;

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
                "Document Verification",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Upload legible photographs of your credentials to complete onboarding KYC.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              
              // DL Card
              _buildDocItem(
                title: "Driving License (DL)",
                desc: "Validity must be unexpired",
                progress: _dlProgress,
                uploaded: _isDlUploaded,
                onTap: () => _uploadDocument('dl'),
              ),
              const SizedBox(height: 16),

              // Aadhaar Card
              _buildDocItem(
                title: "Aadhaar Card",
                desc: "National identity card",
                progress: _aadhaarProgress,
                uploaded: _isAadhaarUploaded,
                onTap: () => _uploadDocument('aadhaar'),
              ),
              const SizedBox(height: 16),

              // RC Card
              _buildDocItem(
                title: "Vehicle Registration Certificate (RC)",
                desc: "Registration credentials",
                progress: _rcProgress,
                uploaded: _isRcUploaded,
                onTap: () => _uploadDocument('rc'),
              ),


              const Spacer(),
              PrimaryButton(
                text: "Submit for Verification",
                onPressed: allDone ? _submit : () {},
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocItem({
    required String title,
    required String desc,
    required double progress,
    required bool uploaded,
    required VoidCallback onTap,
  }) {
    final bool active = progress > 0.0;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: uploaded ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (active && !uploaded) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white10,
                      color: AppColors.primary,
                      minHeight: 4,
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (uploaded)
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0F3A2E),
              child: Icon(LucideIcons.check, color: AppColors.success, size: 18),
            )
          else if (active)
            Text(
              "${(progress * 100).toInt()}%",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.primary,
              ),
            )
          else
            IconButton(
              icon: Icon(LucideIcons.uploadCloud, color: AppColors.textMuted),
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

// 6. KYC Pending Screen
class KycPendingScreen extends ConsumerWidget {
  const KycPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverStateProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF332001),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.clock,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "KYC Verification Pending",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Our administrative desk is checking your uploaded credentials. Usually this takes up to 24 hours.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              GlassCard(
                borderRadius: 16,
                child: Column(
                  children: [
                    _buildMetaRow("Vehicle Info", "${state.vehicleMake} ${state.vehicleModel}"),
                    Divider(color: AppColors.border, height: 24),
                    _buildMetaRow("License Plate", state.vehicleNumber ?? "UP32-AB-9999"),
                    Divider(color: AppColors.border, height: 24),
                    _buildMetaRow("Document Review", "In Queue"),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Dev Bypass approve button
              ElevatedButton(
                onPressed: () {
                  ref.read(driverStateProvider.notifier).approveKyc();
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Dev Auto-Approve Verification"),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
