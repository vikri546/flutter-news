import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/theme_toggle_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';

class AboutScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const AboutScreen({
    Key? key,
    this.onNavigateToHome,
  }) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  String _version = '';
  String _buildNumber = '';
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _getPackageInfo();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _launchSubscriptionForm() async {
    final Uri url = Uri.parse('https://saweria.co/vikri3162');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  // Navigate to home screen
  void _navigateToHome() {
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);

    return WillPopScope(
      onWillPop: () async {
        // Automatically navigate to home screen
        _navigateToHome();
        return false; // Prevent default back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            strings.about,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: const [
            ThemeToggleButton(),
          ],
        ),
        body: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeInAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  // App logo with animation
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        isDark
                            ? 'assets/images/logo_dark.png'
                            : 'assets/images/logo_light.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 8),
                  // Version
                  Text(
                    'Version $_version ($_buildNumber)',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Description
                  Text(
                    strings.isEn
                        ? "d'talk is your premier source for the latest news and articles. Stay informed with our carefully curated content from various categories, designed to keep you updated on what matters most."
                        : "d'talk adalah sumber utama Anda untuk berita dan artikel terbaru. Tetap terinformasi dengan konten pilihan dari berbagai kategori, dirancang untuk membuat Anda selalu update pada hal-hal penting.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Developer info with staggered animations
                  _buildAnimatedListTile(
                    icon: Icons.code,
                    title: strings.isEn ? 'Developed by' : 'Dikembangkan oleh',
                    subtitle: 'Vikri Ardiansyah',
                    delay: 0.0,
                  ),
                  const Divider(),
                  _buildAnimatedListTile(
                    icon: Icons.email,
                    title: strings.isEn ? 'Contact' : 'Kontak',
                    subtitle: 'vikriardiansyah3162@gmail.com',
                    delay: 0.1,
                  ),
                  const Divider(),
                  _buildAnimatedListTile(
                    icon: Icons.language,
                    title: strings.isEn ? 'Website' : 'Situs',
                    subtitle: 'https://dtalk-aconymous.vercel.app/',
                    delay: 0.2,
                  ),
                  const SizedBox(height: 32),

                  // Subscribe button
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: _launchSubscriptionForm,
                      icon: const Icon(Icons.notifications_active),
                      label: Text(
                        strings.isEn ? 'Support Me!' : 'Dukung Saya!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Feedback section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          strings.isEn
                              ? 'Help Me to Improve'
                              : 'Bantu Saya Meningkatkan',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.isEn
                              ? 'I appreciate your feedback! Share your suggestions and ideas to help me continue to enhance your news experience. Your input is crucial as I continue to develop and refine this application.'
                              : 'Saya menghargai masukan Anda! Bagikan saran dan ide Anda untuk membantu saya terus meningkatkan pengalaman membaca berita Anda. Masukan Anda sangat penting seiring saya mengembangkan dan menyempurnakan aplikasi ini.',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Copyright
                  Text(
                    strings.isEn
                        ? "© ${DateTime.now().year} d'talk. All rights reserved."
                        : "© ${DateTime.now().year} d'talk. Hak cipta dilindungi.",
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double delay,
  }) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delayedAnimation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            delay,
            delay + 0.6,
            curve: Curves.easeOut,
          ),
        );

        return FadeTransition(
          opacity: delayedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(delayedAnimation),
            child: child,
          ),
        );
      },
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
