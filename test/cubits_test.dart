import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xchat/data/models/room_model.dart';
import 'package:xchat/data/models/user_model.dart';
import 'package:xchat/data/repositories/auth_repository.dart';
import 'package:xchat/data/repositories/chat_repository.dart';
import 'package:xchat/logic/auth/auth_cubit.dart';
import 'package:xchat/logic/auth/auth_state.dart';
import 'package:xchat/logic/rooms/rooms_cubit.dart';
import 'package:xchat/logic/rooms/rooms_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuthRepository;
  late MockChatRepository mockChatRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockChatRepository = MockChatRepository();
  });

  group('AuthCubit Unit Tests', () {
    test('initial state is AuthInitial', () {
      final cubit = AuthCubit(authRepository: mockAuthRepository);
      expect(cubit.state, isA<AuthInitial>());
      cubit.close();
    });

    test('login emits [AuthLoading, Authenticated] on success', () async {
      final user = UserModel(
        id: 'usr_test',
        username: 'alice',
        displayName: 'Alice Test',
        avatarUrl: 'https://example.com/alice.png',
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      );

      when(() => mockAuthRepository.loginOrRegister(
        username: 'alice',
        displayName: 'Alice Test',
        avatarUrl: null,
      )).thenAnswer((_) async => user);

      final cubit = AuthCubit(authRepository: mockAuthRepository);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Authenticated>().having((s) => s.user.username, 'username', 'alice'),
        ]),
      );

      await cubit.login(username: 'alice', displayName: 'Alice Test');
      expect(cubit.currentUser?.id, 'usr_test');
      cubit.close();
    });

    test('logout clears session and emits Unauthenticated', () async {
      when(() => mockAuthRepository.clearSession()).thenAnswer((_) async {});

      final cubit = AuthCubit(authRepository: mockAuthRepository);

      expectLater(
        cubit.stream,
        emits(isA<Unauthenticated>()),
      );

      await cubit.logout();
      cubit.close();
    });
  });

  group('RoomsCubit Unit Tests', () {
    final now = DateTime.now();
    final sampleRooms = [
      RoomModel(
        id: 'room_1',
        name: 'General Discussion',
        isGroup: true,
        createdBy: 'usr_1',
        createdAt: now,
        updatedAt: now,
      ),
      RoomModel(
        id: 'room_2',
        name: 'Sarah Connor',
        isGroup: false,
        createdBy: 'usr_2',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('loadRooms emits [RoomsLoading, RoomsLoaded] with fetched rooms', () async {
      when(() => mockChatRepository.getUserRooms('usr_me')).thenAnswer((_) async => sampleRooms);

      final cubit = RoomsCubit(
        chatRepository: mockChatRepository,
        currentUserId: 'usr_me',
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<RoomsLoading>(),
          isA<RoomsLoaded>().having((s) => s.rooms.length, 'rooms count', 2),
        ]),
      );

      await cubit.loadRooms();
      cubit.close();
    });

    test('selectRoom updates activeRoomId and clears unread count', () async {
      when(() => mockChatRepository.getUserRooms('usr_me')).thenAnswer((_) async => [
        sampleRooms[0].copyWith(unreadCount: 5),
      ]);
      when(() => mockChatRepository.markRoomAsRead('room_1', 'usr_me')).thenAnswer((_) async {});

      final cubit = RoomsCubit(
        chatRepository: mockChatRepository,
        currentUserId: 'usr_me',
      );

      await cubit.loadRooms();
      cubit.selectRoom('room_1');

      final state = cubit.state as RoomsLoaded;
      expect(state.activeRoomId, 'room_1');
      expect(state.rooms.first.unreadCount, 0);

      cubit.close();
    });
  });
}
