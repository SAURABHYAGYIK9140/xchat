import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final WebSocketClient _wsClient = WebSocketClient();

  AuthCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial());

  UserModel? get currentUser {
    final s = state;
    if (s is Authenticated) return s.user;
    return null;
  }

  Future<void> checkSession() async {
    emit(AuthLoading());
    try {
      final savedUser = await _authRepository.getSavedSession();
      if (savedUser != null) {
        // Sync / verify session with the active server
        try {
          final verifiedUser = await _authRepository.loginOrRegister(
            username: savedUser.username,
            displayName: savedUser.displayName,
            avatarUrl: savedUser.avatarUrl,
          );
          _wsClient.connect(userId: verifiedUser.id);
          NotificationService().registerUserToken(verifiedUser.id);
          emit(Authenticated(verifiedUser));
          return;
        } catch (_) {
          // If offline or network error, fallback to cached session
          _wsClient.connect(userId: savedUser.id);
          NotificationService().registerUserToken(savedUser.id);
          emit(Authenticated(savedUser));
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> login({
    required String username,
    String? displayName,
    String? avatarUrl,
  }) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.loginOrRegister(
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _wsClient.connect(userId: user.id);
      NotificationService().registerUserToken(user.id);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> logout() async {
    await NotificationService().unregisterUserToken();
    await _authRepository.clearSession();
    _wsClient.disconnect();
    emit(Unauthenticated());
  }
}

