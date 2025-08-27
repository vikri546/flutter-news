import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/strings.dart';
import '../screens/login_screen.dart';
import 'language_provider.dart';

class HomeScreenProvider with ChangeNotifier {
  String _currentUsername = '';
  String get currentUsername => _currentUsername;

  bool _showCategoryNotification = false;
  bool get showCategoryNotification => _showCategoryNotification;

  String _previousCategory = '';
  String get previousCategory => _previousCategory;

  late AnimationController _animationController;
  AnimationController get animationController => _animationController;

  void initAnimationController(TickerProvider vsync) {
    _animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1), () {
          _animationController.reverse().then((_) {
            _showCategoryNotification = false;
            notifyListeners();
          });
        });
      }
    });
  }

  Future<void> loadCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _currentUsername = user.email ?? '';
      notifyListeners();
    }
  }

  void showCategoryIndicator(String category) {
    if (_previousCategory != category) {
      _previousCategory = category;
      _showCategoryNotification = true;
      _animationController.forward(from: 0.0);
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    final strings =
        AppStrings(context.read<LanguageProvider>().locale.languageCode);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings.logoutConfirmTitle),
          content: Text(strings.logoutConfirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.logout),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await Supabase.instance.client.auth.signOut();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<bool> showExitConfirmationDialog(BuildContext context) async {
    final strings =
        AppStrings(context.read<LanguageProvider>().locale.languageCode);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(strings.exitApp),
              content: Text(strings.exitAppConfirm),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(strings.exit),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
