import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/auth_repository.dart';
import '../services/chat_repository.dart';
import '../services/media_repository.dart';
import '../services/socket_service.dart';
import '../services/user_repository.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = createApiClient();
  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(dio, storage);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRepository(dio);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UserRepository(dio);
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MediaRepository(dio);
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final dio = ref.watch(dioProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  final service = SocketService(
    authRepository: authRepository,
    socketUrl: deriveSocketUrl(dio.options.baseUrl),
  );
  ref.onDispose(service.dispose);
  return service;
});
