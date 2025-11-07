import 'package:flutter/material.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Username tidak boleh kosong';
    if (value.length < 3) return 'Username minimal 3 karakter';
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return 'Username hanya boleh huruf dan angka tanpa spasi';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Konfirmasi password tidak boleh kosong';
    if (value != _passwordController.text) return 'Password tidak cocok';
    return null;
  }

  Future<void> _register() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final authService = AuthService();

    final bool isLoggedIn = await authService.isLoggedIn();
    if (isLoggedIn && mounted) {
      final bool? wantToSwitch = await _showAccountSwitchDialog();
      if (wantToSwitch == true) {
        await authService.logout();
        await _performRegistrationLogic(authService);
      } else {
        return;
      }
    } else {
      await _performRegistrationLogic(authService);
    }
  }

  Future<void> _performRegistrationLogic(AuthService authService) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await authService.register(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        switch (result) {
          case RegisterResult.success:
            setState(() {
              _successMessage = 'Registrasi berhasil! Mengarahkan ke login...';
            });
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
            break;
          case RegisterResult.usernameExists:
            setState(() {
              _errorMessage = "Username tidak boleh sama seperti sebelumnya";
            });
            break;
          case RegisterResult.error:
            setState(() {
              _errorMessage = 'Terjadi kesalahan saat registrasi';
            });
            break;
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _showAccountSwitchDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sudah Login'),
          content: const Text('Anda sudah memiliki akun. Apakah ingin mengganti dengan akun ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Ganti Akun'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  foregroundColor: Colors.black),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color stabiloGreen = const Color(0xFFAEEE00); // warna hijau stabilo
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                // Logo - sama seperti login
                Image.asset(
                  isDark
                      ? 'assets/images/banner-owrite-black.jpg'
                      : 'assets/images/banner-owrite-white.jpg',
                  height: 55,
                ),
                const SizedBox(height: 20),

                // --- Teks Judul ---
                Text(
                  "Daftar",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // --- Teks Subjudul
                Text(
                  "Buat akun baru untuk mulai menulis",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 40),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Username field, hanya huruf dan angka tanpa spasi
                      TextFormField(
                        controller: _usernameController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: _buildInputDecoration(
                          context: context,
                          label: 'Username',
                          hint: 'Masukkan Username Anda',
                          icon: Icons.person_outline, // biar konsisten
                          isDark: isDark,
                          accentColor: stabiloGreen,
                        ),
                        validator: _validateUsername,
                      ),
                      const SizedBox(height: 18),
                      // Password (Toggle diubah, tombol "Show/Hide" mengikuti tema)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: _buildInputDecoration(
                          context: context,
                          label: 'Password',
                          hint: 'Password minimal 6 karakter',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          accentColor: stabiloGreen,
                        ).copyWith(
                          suffixIcon: TextButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            child: Text(
                              _obscurePassword ? 'Show' : 'Hide',
                              style: TextStyle(
                                color: isDark ? Colors.grey[200] : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 18),
                      // Konfirmasi Password (show/hide pakai TextButton seperti login)
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: _buildInputDecoration(
                          context: context,
                          label: 'Konfirmasi Password',
                          hint: 'Ulangi password Anda',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          accentColor: stabiloGreen,
                        ).copyWith(
                          suffixIcon: TextButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                            child: Text(
                              _obscureConfirmPassword ? 'Show' : 'Hide',
                              style: TextStyle(
                                color: isDark ? Colors.grey[200] : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 20),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Success message
                      if (_successMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _successMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Tombol Sign Up
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: stabiloGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : const Text(
                                  'Daftar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                // Link ke Login (sama dengan LoginScreen)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Sudah punya akun? ",
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Masuk',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                          decorationColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          decorationStyle: TextDecorationStyle.solid,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                // // Theme Toggle, seperti login
                // const Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     Text("Ganti Mode", style: TextStyle(color: Colors.grey)),
                //     SizedBox(width: 8),
                //     ThemeToggleButton(),
                //   ],
                // ),
                // const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper untuk dekorasi input (UI konsisten dengan login)
  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
  }) {
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(
        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(
        color: accentColor,
        width: 2,
      ),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      hintText: hint,
      border: outlineBorder,
      enabledBorder: outlineBorder,
      focusedBorder: focusedBorder,
      filled: true,
      fillColor: isDark ? Colors.grey[900]?.withOpacity(0.5) : Colors.grey[50],
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }
}
