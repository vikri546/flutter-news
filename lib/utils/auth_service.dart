import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';

  // Register new user
  Future<bool> register(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing users
      final usersJson = prefs.getString(_usersKey) ?? '[]';
      final List<dynamic> users = jsonDecode(usersJson);
      
      // Check if username already exists
      final existingUser = users.firstWhere(
        (user) => user['username'] == username,
        orElse: () => null,
      );
      
      if (existingUser != null) {
        return false; // User already exists
      }
      
      // Add new user
      users.add({
        'username': username,
        'password': password, // In real app, this should be hashed
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      // Save users
      await prefs.setString(_usersKey, jsonEncode(users));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Login user
  Future<bool> login(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing users
      final usersJson = prefs.getString(_usersKey) ?? '[]';
      final List<dynamic> users = jsonDecode(usersJson);
      
      // Find user with matching credentials
      final user = users.firstWhere(
        (user) => user['username'] == username && user['password'] == password,
        orElse: () => null,
      );
      
      if (user != null) {
        // Save current user session
        await prefs.setString(_currentUserKey, jsonEncode(user));
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_currentUserKey);
    } catch (e) {
      return false;
    }
  }

  // Get current user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      if (userJson != null) {
        return jsonDecode(userJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
    } catch (e) {
      // Handle error
    }
  }
}
