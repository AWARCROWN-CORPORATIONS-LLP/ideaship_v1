import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  bool _showLoader = false; // Flag for loader visibility

  @override
  void initState() {
    super.initState();

    // Animation controller for logo
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    // Logo scale animation (pop effect)
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Logo fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Progress animation controller
    _progressController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Progress animation
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    // Start logo animation
    _controller.forward();

    // After logo animation completes, show loader and start progress
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showLoader = true;
            });
            _progressController.forward();
          }
        });
      }
    });

    // Navigate after 3.5 seconds
    Timer(const Duration(milliseconds: 3500), () {
      Navigator.pushReplacementNamed(context, '/main_layout');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with scale + fade
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/black_logo.png',
                  width: 150,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Loader appears after logo animation
            AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _showLoader ? 1.0 : 0.0,
              child: SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _showLoader ? _progressAnimation.value : null,
                  color: Colors.black,
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}