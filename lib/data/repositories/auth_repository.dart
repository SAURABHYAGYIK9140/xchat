import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_endpoints.dart';
import '../models/user_model.dart';

class AuthRepository {
  static const String _userSessionKey = 'xchat_user_session';
  static List<UserModel> cachedUsers = [];

  Future<UserModel> loginOrRegister({
    required String username,
    String? displayName,
    String? avatarUrl,
  }) async {
    final candidateHosts = [
      ApiEndpoints.baseUrl,
      ApiEndpoints.useLiveBackend
          ? ApiEndpoints.localBase
          : ApiEndpoints.remoteHttpBase,
    ];

    String lastError = '';

    for (final host in candidateHosts) {
      try {
        final url = '$host/api/xchat/auth/login';
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': username,
                'displayName': displayName,
                'avatarUrl': avatarUrl,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
          await saveSession(user);

          // Lock in the responsive working server
          ApiEndpoints.useLiveBackend = (host == ApiEndpoints.remoteHttpBase);
          return user;
        } else {
          lastError =
              'Server returned ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw Exception('Login failed: $lastError');
  }

  Future<List<UserModel>> getUsers({String? excludeUserId}) async {
    final candidateHosts = [
      ApiEndpoints.baseUrl,
      ApiEndpoints.useLiveBackend
          ? ApiEndpoints.localBase
          : ApiEndpoints.remoteHttpBase,
    ];

    for (final host in candidateHosts) {
      try {
        final url = excludeUserId != null
            ? '$host/api/xchat/users?excludeUserId=$excludeUserId'
            : '$host/api/xchat/users';

        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(milliseconds: 2500));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rawList = data['users'] as List<dynamic>;
          final users = rawList
              .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
              .toList();
          cachedUsers = users;
          return users;
        }
      } catch (_) {}
    }

    if (cachedUsers.isNotEmpty) {
      if (excludeUserId != null) {
        return cachedUsers.where((u) => u.id != excludeUserId).toList();
      }
      return cachedUsers;
    }

    throw Exception('Failed to load users from available servers');
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
