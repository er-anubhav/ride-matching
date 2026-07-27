import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';
import '../providers/theme_provider.dart';

// 1. Wallet Screen
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Mr. Rideo Wallet",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL BALANCE",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "₹${wallet.balance.toStringAsFixed(2)}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick Top Up Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAmount(context, ref, 100),
                        _buildQuickAmount(context, ref, 200),
                        _buildQuickAmount(context, ref, 500),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Transaction History",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Transaction List
              Expanded(
                child: wallet.transactions.isEmpty
                    ? Center(
                        child: Text(
                          "No transactions yet.",
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: wallet.transactions.length,
                        separatorBuilder: (context, index) => Divider(color: AppColors.border),
                        itemBuilder: (context, index) {
                          final tx = wallet.transactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    tx.contains("deducted") ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                                    color: tx.contains("deducted") ? AppColors.error : AppColors.success,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    tx,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmount(BuildContext context, WidgetRef ref, double amount) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white30, width: 1),
        minimumSize: const Size(80, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        ref.read(walletProvider.notifier).addMoney(amount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Successfully added ₹${amount.toStringAsFixed(0)} to wallet!",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      },
      child: Text(
        "+₹${amount.toStringAsFixed(0)}",
        style: GoogleFonts.plusJakartaSans(),
      ),
    );
  }
}

// 2. Profile Screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "System Default";
      case ThemeMode.light:
        return "Light Theme";
      case ThemeMode.dark:
        return "Dark Theme";
    }
  }

  void _showThemeSelectionDialog(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            "Select Theme",
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: currentTheme,
                title: Text("System Default", style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
                activeColor: AppColors.primary,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ref.read(themeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: currentTheme,
                title: Text("Light Theme", style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
                activeColor: AppColors.primary,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ref.read(themeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: currentTheme,
                title: Text("Dark Theme", style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
                activeColor: AppColors.primary,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ref.read(themeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "My Profile",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Profile Card Details
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showPhotoUploadOptions(context, ref),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundImage: NetworkImage(profile.avatarUrl),
                          ).border(color: AppColors.primary, width: 3),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showPhotoUploadOptions(context, ref),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Text(
                "Account Options",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildOptionRow(
                LucideIcons.wallet,
                "Wallet Payment Details",
                "Configure default cards",
                () => context.push('/profile/payment'),
              ),
              _buildOptionRow(
                LucideIcons.shield,
                "Security & SOS Contacts",
                "Configure safety settings",
                () => context.push('/profile/security'),
              ),
              _buildOptionRow(
                LucideIcons.helpCircle,
                "Help & Customer Care",
                "Support requests",
                () => context.push('/profile/help'),
              ),
              _buildOptionRow(
                LucideIcons.palette,
                "App Theme",
                _getThemeName(themeMode),
                () => _showThemeSelectionDialog(context, ref),
              ),

              const Spacer(),
              // Version Card
              Center(
                child: Text(
                  "Mr. Rideo v1.0.0",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showPhotoUploadOptions(BuildContext context, WidgetRef ref) {
    // Curated high-fidelity profile images
    final presets = [
      "https://images.unsplash.com/photo-1534528741775-53994a69daeb", // Current default
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d", // Tech Male
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330", // Happy Female
      "https://images.unsplash.com/photo-1500648767791-00dcc994a43e", // Professional Male
      "https://images.unsplash.com/photo-1544005313-94ddf0286df2", // Creative Female
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Change Profile Photo",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Preset list
              Text(
                "Choose Preset Avatar",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length,
                  itemBuilder: (listCtx, idx) {
                    final url = presets[idx];
                    return GestureDetector(
                      onTap: () {
                        ref.read(userProfileProvider.notifier).updateAvatarUrl(url);
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Profile photo updated successfully!",
                              style: GoogleFonts.plusJakartaSans(color: Colors.white),
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(url),
                          child: ref.watch(userProfileProvider).avatarUrl == url
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.image, color: AppColors.textPrimary, size: 18),
                ),
                title: Text(
                  "Choose from Gallery",
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadPhoto(context, ref, "Gallery");
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.camera, color: AppColors.textPrimary, size: 18),
                ),
                title: Text(
                  "Take a Photo",
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadPhoto(context, ref, "Camera");
                },
              ),

            ],
          ),
        ),
      ),
    );
  }

  void _uploadPhoto(BuildContext context, WidgetRef ref, String source) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              "Uploading photo...",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final response = await ApiClient().post('/kyc/upload-url', {
        'docType': 'SELFIE',
        'contentType': 'image/jpeg',
        'fileExtension': 'jpg',
      });

      if (context.mounted) {
        Navigator.pop(context);
        if (response != null && response['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Profile photo updated successfully!",
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to upload photo",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

}

// Custom Extension to paint border around CircleAvatar
extension on CircleAvatar {
  CircleAvatar border({required Color color, required double width}) {
    return CircleAvatar(
      radius: radius != null ? radius! + width : null,
      backgroundColor: color,
      child: this,
    );
  }
}

// 3. Wallet Payment Details Screen
class WalletPaymentScreen extends ConsumerStatefulWidget {
  const WalletPaymentScreen({super.key});

  @override
  ConsumerState<WalletPaymentScreen> createState() => _WalletPaymentScreenState();
}

class _WalletPaymentScreenState extends ConsumerState<WalletPaymentScreen> {
  bool _autoRefill = false;

  void _showAddMethodSheet(BuildContext context) {
    final typeController = TextEditingController(text: 'card');
    final labelController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Payment Method",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Card"),
                          selected: typeController.text == 'card',
                          onSelected: (val) {
                            setState(() => typeController.text = 'card');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("UPI ID"),
                          selected: typeController.text == 'upi',
                          onSelected: (val) {
                            setState(() => typeController.text = 'upi');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(
                      hintText: typeController.text == 'card' 
                        ? "Enter last 4 digits of card (e.g. 4242)"
                        : "Enter UPI ID (e.g. name@upi)",
                    ),
                    keyboardType: typeController.text == 'card' 
                      ? TextInputType.number
                      : TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: () {
                      final val = labelController.text.trim();
                      if (val.isNotEmpty) {
                        if (typeController.text == 'card') {
                          ref.read(paymentMethodsProvider.notifier).addCard(val);
                        } else {
                          ref.read(paymentMethodsProvider.notifier).addUpi(val);
                        }
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Payment method added!", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    text: "Save Payment Method",
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          "Payment Details",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Credit Card Mock
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6D0FA5), Color(0xFF9D4EDD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D0FA5).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "MR. RIDEO CARD",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                      const Icon(LucideIcons.creditCard, color: Colors.white, size: 28),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    "••••  ••••  ••••  4820",
                    style: GoogleFonts.shareTechMono(
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CARD HOLDER",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            "ANUBHAV TRIPATHI",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "EXPIRES",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            "09/29",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Auto Refill Switch
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.refreshCw, color: AppColors.textPrimary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Auto-Refill Wallet",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          "Refill ₹200 automatically when balance drops below ₹100",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoRefill,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _autoRefill = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Saved Payment Methods",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddMethodSheet(context),
                  icon: Icon(LucideIcons.plus, size: 16, color: AppColors.textPrimary),
                  label: Text(
                    "Add New",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: methods.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final method = methods[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  tileColor: AppColors.surfaceCard.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
                    child: Icon(
                      method.type == 'card' ? LucideIcons.creditCard : LucideIcons.wallet,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    method.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (method.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Default",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                        onPressed: () {
                          ref.read(paymentMethodsProvider.notifier).deleteMethod(method.id);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    ref.read(paymentMethodsProvider.notifier).setDefault(method.id);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Security & SOS Contacts Screen
class SecuritySosScreen extends ConsumerStatefulWidget {
  const SecuritySosScreen({super.key});

  @override
  ConsumerState<SecuritySosScreen> createState() => _SecuritySosScreenState();
}

class _SecuritySosScreenState extends ConsumerState<SecuritySosScreen> {
  bool _shareStatus = true;
  bool _enablePin = false;
  bool _biometric = false;
  
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool _showAddForm = false;

  void _addContact() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (name.isNotEmpty && phone.isNotEmpty) {
      ref.read(sosContactsProvider.notifier).addContact(name, phone);
      nameController.clear();
      phoneController.clear();
      setState(() => _showAddForm = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Emergency Contact Saved!", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          "Security & SOS Settings",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Warning/Information Banner
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.shieldAlert, color: AppColors.primary, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Emergency SOS Assistance",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "In an emergency, tapping the SOS button will notify your emergency contacts and share your real-time tracking details.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // SOS Contacts Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "SOS Contacts",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showAddForm = !_showAddForm);
                  },
                  icon: Icon(_showAddForm ? LucideIcons.x : LucideIcons.plus, size: 16, color: AppColors.primary),
                  label: Text(
                    _showAddForm ? "Cancel" : "Add New",
                    style: GoogleFonts.plusJakartaSans(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_showAddForm) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: "Contact Name (e.g. Mom)",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        hintText: "Mobile Number (e.g. +91 99999 88888)",
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      onPressed: _addContact,
                      text: "Save Contact",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contacts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  tileColor: AppColors.surfaceCard.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      contact.name.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    contact.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    contact.phone,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                    onPressed: () {
                      ref.read(sosContactsProvider.notifier).removeContact(contact.id);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Security Preferences Toggles
            Text(
              "Security Options",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildPreferenceToggle(
              icon: LucideIcons.share2,
              title: "Auto-Share Ride Details",
              subtitle: "Automatically share trip location with SOS contacts on ride start",
              value: _shareStatus,
              onChanged: (val) => setState(() => _shareStatus = val),
            ),
            const SizedBox(height: 12),
            _buildPreferenceToggle(
              icon: LucideIcons.key,
              title: "Ride Verification PIN",
              subtitle: "Require typing 4-digit PIN sent via SMS before driver boards",
              value: _enablePin,
              onChanged: (val) => setState(() => _enablePin = val),
            ),
            const SizedBox(height: 12),
            _buildPreferenceToggle(
              icon: LucideIcons.fingerprint,
              title: "Biometric Authentication",
              subtitle: "Unlock ride management & billing details with biometric scan",
              value: _biometric,
              onChanged: (val) => setState(() => _biometric = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// 5. Help & Customer Care Screen
class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final List<Map<String, String>> _faqs = [
    {
      "q": "How do I check my driver details?",
      "a": "Once a driver matches with your ride request, their details including photo, name, rating, vehicle license plate number, and estimated arrival time will be displayed on the tracking map screen."
    },
    {
      "q": "What is the cancellation policy?",
      "a": "You can cancel your ride request for free before a driver accepts. A minor cancellation fee may apply if you cancel more than 2 minutes after a driver has been matched, to compensate the driver's fuel and time."
    },
    {
      "q": "My payment failed. What should I do?",
      "a": "If your payment fails but the money was deducted, it will be automatically refunded to your original source of payment within 3-5 business days. You can also contact support below."
    },
  ];

  String _selectedCategory = "Fare / Payment Issue";
  final ticketMessageController = TextEditingController();

  void _submitTicket() {
    final msg = ticketMessageController.text.trim();
    if (msg.isNotEmpty) {
      ref.read(supportTicketsProvider.notifier).raiseTicket(_selectedCategory, msg);
      ticketMessageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Support ticket submitted!", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(supportTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          "Help & Customer Care",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // FAQs
            Text(
              "Frequently Asked Questions",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _faqs.length,
              itemBuilder: (context, index) {
                final faq = _faqs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      backgroundColor: AppColors.surfaceCard.withValues(alpha: 0.3),
                      collapsedBackgroundColor: AppColors.surfaceCard.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        faq['q']!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                          child: Text(
                            faq['a']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Raise a ticket form
            Text(
              "Raise a Support Ticket",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Select Category",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    dropdownColor: AppColors.surface,
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      "Fare / Payment Issue",
                      "Driver Behavior",
                      "Lost Item",
                      "App Technical Issue",
                    ].map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Tell us what happened",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ticketMessageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Describe your issue in detail...",
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    onPressed: _submitTicket,
                    text: "Submit Support Request",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Past Tickets List
            Text(
              "Your Support Tickets",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            tickets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "No past support requests.",
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tickets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      final isPending = ticket.status == "Pending";
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        tileColor: AppColors.surfaceCard.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ticket.category,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending 
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ticket.status,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isPending ? AppColors.primary : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              ticket.message,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${ticket.id} • ${ticket.date}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
