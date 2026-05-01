// ─────────────────────────────────────────────────────────────────
// lib/screens/splash_screen.dart
// ─────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import 'webview_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<double>   _scale;
  late Animation<double>   _slideY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _fade  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeIn)));
    _scale = Tween<double>(begin: 0.6, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.7, curve: Curves.elasticOut)));
    _slideY = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)));

    _ctrl.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _navigate();
    });
  }

  Future<void> _navigate() async {
    final prefs         = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

    if (!onboardingDone) {
      _go(const OnboardingScreen());
      return;
    }

    // Biometric gate if enabled
    final biometricOn = prefs.getBool(AppConstants.keyBiometricEnabled) ?? false;
    if (biometricOn) {
      final ok = await AuthService.authenticateBiometric();
      if (!ok && mounted) {
        // Still navigate — the web login will enforce auth
      }
    }

    _go(const WebViewScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.orange,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fade,
            child: Transform.translate(
              offset: Offset(0, _slideY.value),
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo card
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 40, offset: const Offset(0, 16),
                          )
                        ],
                      ),
                      child: const Icon(Icons.domain_rounded, size: 56, color: AppTheme.orange),
                    ),
                    const SizedBox(height: 28),
                    const Text('VAASTU PMC',
                      style: TextStyle(
                        color: Colors.white, fontSize: 30,
                        fontWeight: FontWeight.w700, letterSpacing: 2.5,
                        fontFamily: 'DMSans',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(AppConstants.appTagline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13, letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 56),
                    SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
