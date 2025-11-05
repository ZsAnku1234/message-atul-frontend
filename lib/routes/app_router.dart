import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth/auth_controller.dart';
import '../screens/chat_screen.dart';
import '../screens/conversation_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final notifier = ref.watch(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: GoRouterRefreshStream(notifier.stream),
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final goingToAuth = state.matchedLocation == '/auth';

      if (!isLoggedIn) {
        return goingToAuth ? null : '/auth';
      }

      if (isLoggedIn && goingToAuth) {
        return '/conversations';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/conversations',
        name: 'conversations',
        builder: (context, state) => const ConversationListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'conversation',
            builder: (context, state) => ChatScreen(conversationId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
