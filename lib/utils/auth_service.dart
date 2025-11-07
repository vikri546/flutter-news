import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String _baseUrl = 'https://www.owrite.id/wp-json/wp/v2';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserAvatar = 'user_avatar';

  // Fetch users from WordPress API
  Future<List<Map<String, dynamic>>> fetchWordPressUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users?per_page=100'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((user) {
          return {
            'id': user['id'].toString(),
            'username': user['slug'] ?? user['name'] ?? 'user',
            'name': user['name'] ?? 'Unknown',
            'email': user['description'] ?? '', // WordPress doesn't expose email in public API
            'avatar': user['avatar_urls'] != null ? user['avatar_urls']['96'] : null,
          };
        }).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching WordPress users: $e');
      rethrow;
    }
  }

  // Login dengan username yang ada di WordPress API
  Future<bool> login(String username, String password) async {
    try {
      // Fetch users from API
      final users = await fetchWordPressUsers();
      
      // Cari user berdasarkan username (case insensitive)
      final user = users.firstWhere(
        (u) => u['username'].toString().toLowerCase() == username.toLowerCase(),
        orElse: () => {},
      );

      if (user.isEmpty) {
        return false; // User tidak ditemukan
      }

      // Untuk demo, password adalah username (bisa disesuaikan)
      if (password.toLowerCase() != user['username'].toString().toLowerCase()) {
        return false; // Password salah
      }

      // Simpan data user
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, user['username']);
      await prefs.setString(_keyUserId, user['id']);
      await prefs.setString(_keyUserEmail, user['email']);
      if (user['avatar'] != null) {
        await prefs.setString(_keyUserAvatar, user['avatar']);
      }

      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Login as Guest
  Future<void> loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.setString(_keyUsername, 'Guest');
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserAvatar);
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Get current user
  Future<Map<String, String>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyUserEmail);
    final avatar = prefs.getString(_keyUserAvatar);

    if (username != null) {
      return {
        'username': username,
        'userId': userId ?? '',
        'email': email ?? '',
        'avatar': avatar ?? '',
      };
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.setString(_keyUsername, 'Guest');
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserAvatar);
  }
}