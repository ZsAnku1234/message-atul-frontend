import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_state.dart';
import '../screens/chat_screen.dart';
import '../screens/conversation_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/profile_screen.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated) {
          notifyListeners();
        }
      },
    );
  }

  final Ref ref;
  late final ProviderSubscription<AuthState> _subscription;

  bool get isAuthenticated => ref.read(authControllerProvider).isAuthenticated;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  final router = GoRouter(
    initialLocation: '/auth',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/auth';
      }

      if (isLoggedIn && isAuthRoute) {
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
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/conversations',
        name: 'conversations',
        builder: (context, state) => const ConversationListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'conversation',
            builder: (context, state) => ChatScreen(
              conversationId: state.pathParameters['id']!,
            ),
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

  ref.onDispose(router.dispose);
  return router;
});
