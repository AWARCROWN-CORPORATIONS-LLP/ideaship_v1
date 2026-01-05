// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage>
    with TickerProviderStateMixin {
  // ---------------- Controllers ----------------

  AnimationController? _rocketController;
  AnimationController? _tickerController;
  AnimationController? _backgroundController;
  AnimationController? _fadeController;
  AnimationController? _badgeController;

  // ---------------- Init ----------------

  @override
  void initState() {
    super.initState();

    _rocketController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start fade-in after a slight delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController?.forward();
    });
  }

  @override
  void dispose() {
    _rocketController?.dispose();
    _tickerController?.dispose();
    _backgroundController?.dispose();
    _fadeController?.dispose();
    _badgeController?.dispose();
    super.dispose();
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _animatedBackground(),
          _floatingBlobs(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(cs),
              SliverToBoxAdapter(child: _content()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _floatingBlobs() {
    final ctrl = _backgroundController;
    if (ctrl == null) return const SizedBox();

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final angle = ctrl.value * 2 * math.pi;
        return Stack(
          children: [
            _buildBlob(
              Offset(-100 + math.cos(angle) * 30, -100 + math.sin(angle) * 30),
              const Color(0xFFF0F4FF).withOpacity(0.6),
              450,
            ),
            _buildBlob(
              Offset(
                MediaQuery.of(context).size.width - 200 + math.sin(angle) * 40,
                300 + math.cos(angle) * 40,
              ),
              const Color(0xFFF8F4FF).withOpacity(0.5),
              400,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlob(Offset offset, Color color, double size) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  // ---------------- Background ----------------

  Widget _animatedBackground() {
    final ctrl = _backgroundController;
    if (ctrl == null) return const SizedBox();

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(t * 2 * math.pi),
              colors: const [
                Color(0xFFFFFFFF),
                Color(0xFFFDFDFF),
                Color(0xFFFAFBFF),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- AppBar ----------------

  Widget _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: 110,
      backgroundColor: Colors.white.withOpacity(0.7),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        centerTitle: false,
        title: const Text(
          "Marketplace",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -1.0,
          ),
        ),
      ),
    );
  }

  // ---------------- Content ----------------

  Widget _content() {
    final ctrl = _fadeController;
    if (ctrl == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          _staggeredChild(0.0, _animatedRocket()),
          const SizedBox(height: 54),
          _staggeredChild(0.1, _title()),
          const SizedBox(height: 24),
          _staggeredChild(0.2, _description()),
          const SizedBox(height: 70),
          _staggeredChild(0.3, _productConveyor()),
          const SizedBox(height: 54),
          _staggeredChild(0.4, _benefitsRow()),
          const SizedBox(height: 64),
          _staggeredChild(0.5, _animatedBadge()),
          const SizedBox(height: 100),
          _staggeredChild(0.6, _footer()),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
Widget _staggeredChild(double start, Widget child) {
  return AnimatedBuilder(
    animation: _fadeController!,
    builder: (context, _) {
      final rawCurve = CurvedAnimation(
        parent: _fadeController!,
        curve: Interval(
          start,
          math.min(start + 0.4, 1.0),
          curve: Curves.easeOutBack,
        ),
      );

      // ✅ CLAMP opacity to safe range
      final opacity = rawCurve.value.clamp(0.0, 1.0);

      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - rawCurve.value)),
          child: child,
        ),
      );
    },
  );
}

  // ---------------- Benefits ----------------

  Widget _benefitsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _benefitItem(Icons.verified_outlined, "Verified Only"),
        _benefitItem(Icons.auto_graph_rounded, "High Signal"),
        _benefitItem(Icons.layers_outlined, "Curated Tools"),
      ],
    );
  }

  Widget _benefitItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.06),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.03),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5), size: 24),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ---------------- Rocket ----------------

  Widget _animatedRocket() {
    final ctrl = _rocketController;
    if (ctrl == null) return const SizedBox(height: 130);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final v = ctrl.value;
        final float = math.sin(v * math.pi * 2) * 18;
        final rotate = math.sin(v * math.pi * 2) * 0.06;
        final scale = 1.0 + math.sin(v * math.pi * 2) * 0.03;

        return Transform.translate(
          offset: Offset(0, float),
          child: Transform.rotate(
            angle: rotate,
            child: Transform.scale(scale: scale, child: _rocketCore(v)),
          ),
        );
      },
    );
  }

  Widget _rocketCore(double value) {
    final glow = math.sin(value * math.pi * 2).abs();
    return Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
            Color(0xFFD946EF),
            Color(0xFFF43F5E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3 + (glow * 0.2)),
            blurRadius: 50 + (glow * 10),
            spreadRadius: 2 + (glow * 4),
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: const Icon(
        Icons.rocket_launch_rounded,
        size: 58,
        color: Colors.white,
      ),
    );
  }

  // ---------------- Text ----------------

  Widget _title() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF334155), Color(0xFF64748B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Text(
        "A Specialized Marketplace\nBuilt for Founders",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -1.5,
          color: Colors
              .white, // Ignored by ShaderMask, but required for the widget
        ),
      ),
    );
  }

  Widget _description() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Text(
        "Ideaship Marketplace is a high-trust curated ecosystem.\nWe optimize for high signal and zero noise, connecting founders with the right solutions.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          height: 1.6,
          color: Color(0xFF475569),
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _productConveyor() {
    final ctrl = _tickerController;
    if (ctrl == null) return const SizedBox(height: 90);

    final products = [
      "Market Research AI",
     
      
      "Competitor Analysis",
      "Customer Feedback Tool",
      "Product Roadmap Planner",
      "Founder Legal Stack",
      "No-Code Websites",
      "Investor CRM",
      "Startup Analytics",
      "Hiring Automation",
      "Growth Tooling",
    ];

    final items = [...products, ...products];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 25, bottom: 20),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                "UPCOMING SOLUTIONS",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 90,
          width: double.infinity,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: ctrl,
              builder: (context, _) {
                final screenWidth = MediaQuery.of(context).size.width;
                final travel = screenWidth * 2;

               return OverflowBox(
  minWidth: 0,
  maxWidth: double.infinity,
  alignment: Alignment.centerLeft,
  child: Transform.translate(
    offset: Offset(-travel * ctrl.value, 0),
    child: Row(
      children: items.map((p) => _pill(p)).toList(),
    ),
  ),
);

              },
            ),
          ),
        ),
      ],
    );
  }
Widget _pill(String text) {
  return Container(
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    constraints: const BoxConstraints(
      maxHeight: 44,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          Color(0xFFEEF2FF),
          Color(0xFFEFF6FF),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Color(0xFFC7D2FE),
        width: 1.1,
      ),
    ),
    child: Center(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3730A3),
          letterSpacing: -0.2,
        ),
      ),
    ),
  );
}


  // ---------------- Footer ----------------

  Widget _footer() {
    return Column(
      children: [
        Container(
          height: 1.5,
          width: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          "Early Access Opens March 2026",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "Be the first to know when we go live.",
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---------------- Badge ----------------

  Widget _animatedBadge() {
    final ctrl = _badgeController;
    if (ctrl == null) return const SizedBox();

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final scale = 1.0 + (math.sin(ctrl.value * 2 * math.pi) * 0.05);
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Text(
              "Early Access Coming Soon",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
