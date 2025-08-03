import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/intent_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserChooserDialog extends StatefulWidget {
  final String url;
  final String title;

  const BrowserChooserDialog({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<BrowserChooserDialog> createState() => _BrowserChooserDialogState();
}

class _BrowserChooserDialogState extends State<BrowserChooserDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  List<BrowserInfo> availableBrowsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _checkAvailableBrowsers();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailableBrowsers() async {
    if (Platform.isAndroid) {
      final browsers = IntentHelper.getCommonBrowsers();
      final available = <BrowserInfo>[];
      
      for (final browser in browsers) {
        final isInstalled = await IntentHelper.isAppInstalled(browser.packageName);
        if (isInstalled) {
          available.add(browser);
        }
      }
      
      setState(() {
        availableBrowsers = available;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).cardColor,
                  Theme.of(context).cardColor.withOpacity(0.9),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (isLoading)
                  _buildLoadingWidget()
                else
                  _buildBrowserOptions(),
                const SizedBox(height: 16),
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.open_in_browser,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open Article',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Choose your preferred browser',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Checking available browsers...'),
        ],
      ),
    );
  }

  Widget _buildBrowserOptions() {
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // System chooser option
            _buildBrowserOption(
              icon: Icons.apps,
              title: 'System Browser Chooser',
              subtitle: 'Let Android choose from all browsers',
              color: Colors.blue,
              onTap: () async {
                Navigator.of(context).pop();
                final success = await IntentHelper.launchUrlWithChooser(
                  widget.url,
                  title: 'Choose Browser',
                );
                if (!success) {
                  _fallbackLaunch();
                }
              },
            ),
            const SizedBox(height: 12),
            
            // Default browser option
            _buildBrowserOption(
              icon: Icons.language,
              title: 'Default Browser',
              subtitle: 'Open in system default browser',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).pop();
                _launchInDefaultBrowser();
              },
            ),
            const SizedBox(height: 12),
            
            // In-app browser option
            _buildBrowserOption(
              icon: Icons.web,
              title: 'In-App Browser',
              subtitle: 'Open within this app',
              color: Colors.orange,
              onTap: () {
                Navigator.of(context).pop();
                _launchInApp();
              },
            ),
            
            // Specific browsers (if available)
            if (availableBrowsers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Installed Browsers',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              ...availableBrowsers.map((browser) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSpecificBrowserOption(browser),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrowserOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificBrowserOption(BrowserInfo browser) {
    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        final success = await IntentHelper.launchUrlWithPackage(
          widget.url,
          browser.packageName,
        );
        if (!success) {
          _fallbackLaunch();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.web,
                size: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                browser.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _launchInDefaultBrowser() async {
    try {
      await launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _fallbackLaunch();
    }
  }

  Future<void> _launchInApp() async {
    try {
      await launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
          } catch (e) {
      _fallbackLaunch();
    }
  }

  Future<void> _fallbackLaunch() async {
    try {
      await launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      // Show error if all methods fail
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open URL: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
