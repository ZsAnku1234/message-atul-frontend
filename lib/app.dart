import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class MessageApp extends ConsumerStatefulWidget {
  const MessageApp({super.key});

  @override
  ConsumerState<MessageApp> createState() => _MessageAppState();
}

class _MessageAppState extends ConsumerState<MessageApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications after build to ensure context validity if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final theme = AppTheme();

    return MaterialApp.router(
      title: 'Pulse Messenger',
      themeMode: ThemeMode.system,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
