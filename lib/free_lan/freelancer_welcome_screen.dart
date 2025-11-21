// lib/screens/freelancer/freelancer_welcome_screen.dart

import 'package:flutter/material.dart';

class FreelancerWelcomeScreen extends StatelessWidget {
  const FreelancerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Title
              const Text(
                'Become a Freelancer',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Join Ideaship’s community of talented builders.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF555555), height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // Beautiful Static Illustration (No Lottie needed)
              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE8F5FF),
                      Color(0xFFF8FBFF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Floating elements
                    Positioned(
                      top: 40,
                      left: 40,
                      child: _floatingIcon(Icons.code_rounded, Colors.deepPurple),
                    ),
                    Positioned(
                      top: 60,
                      right: 50,
                      child: _floatingIcon(Icons.design_services_rounded, Colors.orange),
                    ),
                    Positioned(
                      bottom: 70,
                      left: 60,
                      child: _floatingIcon(Icons.mobile_friendly_rounded, Colors.green),
                    ),
                    Positioned(
                      bottom: 50,
                      right: 70,
                      child: _floatingIcon(Icons.payments_rounded, Colors.blue),
                    ),

                    // Main center icon
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D6EFD),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.build_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Build & Earn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Benefits
              _buildBenefitRow(icon: Icons.check_circle_outline, text: 'Work on real paid projects'),
              const SizedBox(height: 20),
              _buildBenefitRow(icon: Icons.verified_user_outlined, text: 'Get officially recognized experience'),
              const SizedBox(height: 20),
              _buildBenefitRow(icon: Icons.workspace_premium_outlined, text: 'Earn as per your skills'),
              const SizedBox(height: 60),

              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Terms & Conditions or next step
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const Placeholder(), // Replace with next screen
                        transitionsBuilder: (_, animation, __, child) {
                          return SlideTransition(
                            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                .animate(CurvedAnimation(parent: animation, curve: Curves.ease)),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 26, color: const Color(0xFF0D6EFD)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15.5, color: Color(0xFF1A1A1A), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _floatingIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: color),
    );
  }
}