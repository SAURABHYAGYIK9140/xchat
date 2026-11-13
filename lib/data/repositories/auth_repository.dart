import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_endpoints.dart';
import '../models/user_model.dart';

class AuthRepository {
  static const String _userSessionKey = 'xchat_user_session';

  Future<UserModel> loginOrRegister({
    required String username,
    String? displayName,
    String? avatarUrl,
  }) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await saveSession(user);
      return user;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<List<UserModel>> getUsers({String? excludeUserId}) async {
    final uri = excludeUserId != null
        ? Uri.parse('${ApiEndpoints.users}?excludeUserId=$excludeUserId')
        : Uri.parse(ApiEndpoints.users);

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = data['users'] as List<dynamic>;
      return rawList.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load users: ${response.body}');
    }
  }

  Future<void> saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userSessionKey);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSessionKey);
  }
}
