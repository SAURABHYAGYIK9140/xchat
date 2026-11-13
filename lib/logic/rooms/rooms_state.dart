import 'package:equatable/equatable.dart';
import '../../data/models/room_model.dart';

abstract class RoomsState extends Equatable {
  const RoomsState();
  @override
  List<Object?> get props => [];
}

class RoomsInitial extends RoomsState {}

class RoomsLoading extends RoomsState {}

class RoomsLoaded extends RoomsState {
  final List<RoomModel> rooms;
  final String? activeRoomId;
  final String searchQuery;

  const RoomsLoaded({
    required this.rooms,
    this.activeRoomId,
    this.searchQuery = '',
  });

  List<RoomModel> get filteredRooms {
    if (searchQuery.trim().isEmpty) return rooms;
    final query = searchQuery.trim().toLowerCase();
    return rooms.where((r) => r.name.toLowerCase().contains(query)).toList();
  }

  RoomModel? get activeRoom {
    if (activeRoomId == null) return null;
    try {
      return rooms.firstWhere((r) => r.id == activeRoomId);
    } catch (_) {
      return null;
    }
  }

  RoomsLoaded copyWith({
    List<RoomModel>? rooms,
    String? activeRoomId,
    String? searchQuery,
    bool clearActiveRoom = false,
  }) {
    return RoomsLoaded(
      rooms: rooms ?? this.rooms,
      activeRoomId: clearActiveRoom ? null : (activeRoomId ?? this.activeRoomId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [rooms, activeRoomId, searchQuery];
}

class RoomsError extends RoomsState {
  final String message;
  const RoomsError(this.message);

  @override
  List<Object?> get props => [message];
}

