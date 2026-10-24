// ─────────────────────────────────────────────────────────────────
// lib/screens/onboarding_screen.dart
// Note: No sign-up here. Admin creates all users from the web panel.
//       Onboarding is purely informational + permission requests.
// ─────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../services/auth_service.dart';
import 'webview_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  bool _requestingPermissions = false;

  final List<_OnboardSlide> _slides = [
    const _OnboardSlide(
      icon: Icons.domain_rounded,
      color: AppTheme.orange,
      title: 'Welcome to v connect',
      subtitle: 'Your complete construction project management suite. '
          'Track progress, manage teams, and stay on top of every site.',
    ),
    const _OnboardSlide(
      icon: Icons.checklist_rounded,
      color: Color(0xFF10B981),
      title: 'Daily Reports & Approvals',
      subtitle: 'Submit DPRs, get PM approvals, track snags and issues — '
          'all from your phone, even offline.',
    ),
    const _OnboardSlide(
      icon: Icons.location_on_rounded,
      color: Color(0xFF3B82F6),
      title: 'GPS Site Attendance',
      subtitle: 'Check in and out directly from the site. '
          'Location is verified against the project geofence automatically.',
    ),
    const _OnboardSlide(
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Stay Instantly Notified',
      subtitle: 'Get alerts when DPRs are approved or held, '
          'new snags are raised, and bills need your attention.',
      isLast: true,
    ),
  ];

  Future<void> _requestPermissionsAndFinish() async {
    setState(() => _requestingPermissions = true);

    // Location
    await Geolocator.requestPermission();

    // Camera + storage
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();

    // Notifications
    await Permission.notification.request();

    // Biometric opt-in
    final hasBio = await AuthService.isBiometricAvailable();
    if (hasBio && mounted) {
      final enable = await _showBiometricDialog();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyBiometricEnabled, enable);
    }

    // Mark onboarding done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingDone, true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WebViewScreen()),
      );
    }
  }

  Future<bool> _showBiometricDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Enable Biometric Login?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
            content: const Text(
              'Use Face ID or Fingerprint to quickly and securely open v connect.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enable'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 20),
                child: _currentPage < _slides.length - 1
                    ? TextButton(
                        onPressed: _requestPermissionsAndFinish,
                        child: const Text('Skip',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 14)),
                      )
                    : const SizedBox(height: 40),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageCtrl,
                    count: _slides.length,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: AppTheme.orange,
                      dotColor: AppTheme.border,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: _currentPage < _slides.length - 1
                        ? ElevatedButton(
                            onPressed: () => _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                            ),
                            child: const Text('Next'),
                          )
                        : ElevatedButton(
                            onPressed: _requestingPermissions
                                ? null
                                : _requestPermissionsAndFinish,
                            child: _requestingPermissions
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Get Started'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(slide.icon, size: 60, color: slide.color),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, color: AppTheme.textMuted, height: 1.65),
          ),
        ],
      ),
    );
  }
}

class _OnboardSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isLast;
  const _OnboardSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });
}
