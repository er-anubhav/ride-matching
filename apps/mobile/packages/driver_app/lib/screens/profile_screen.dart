import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/driver_state_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          "Driver Profile",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Avatar & Name
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.surfaceCard,
                      child: Icon(
                        LucideIcons.user,
                        color: AppColors.primary.withValues(alpha: 0.8),
                        size: 56,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.camera, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  state.riderName ?? "Vikram Singh",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.shieldCheck, color: AppColors.success, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "KYC Verified",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2. Personal & Vehicle Info Card
              _buildSectionHeader("VEHICLE DETAILS"),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildInfoRow("Vehicle Model", state.vehicleModel ?? "Tata Nexon EV"),
                    const SizedBox(height: 16),
                    _buildInfoRow("License Plate", state.vehicleNumber ?? "UP32-AB-9999"),
                    const SizedBox(height: 16),
                    _buildInfoRow("Fuel Type", "Electric (EV)"),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 3. Document Status
              _buildSectionHeader("UPLOADED DOCUMENTS"),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildDocStatusRow("Driving License", true),
                    const SizedBox(height: 16),
                    _buildDocStatusRow("Aadhaar Card", true),
                    const SizedBox(height: 16),
                    _buildDocStatusRow("Vehicle Insurance", true),
                    const SizedBox(height: 16),
                    _buildDocStatusRow("Registration Certificate (RC)", true),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. Logout / Exit
              OutlinedButton(
                onPressed: () {
                  ref.read(driverStateProvider.notifier).toggleDutyStatus();
                  context.go('/auth/phone');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("LOG OUT"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDocStatusRow(String label, bool isVerified) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        Row(
          children: [
            Icon(LucideIcons.check, color: AppColors.success, size: 16),
            const SizedBox(width: 6),
            Text(
              "Verified",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
