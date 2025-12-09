import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_controller.dart';
import '../theme/color_tokens.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  @override
  void initState() {
    super.initState();
    _processJoin();
  }

  Future<void> _processJoin() async {
    if (widget.token == null) {
      if (mounted) {
        context.go('/conversations');
      }
      return;
    }

    try {
      await ref.read(chatControllerProvider.notifier).joinViaLink(widget.token!);
      if (!mounted) return;
      
      final active = ref.read(chatControllerProvider).activeConversation;
      if (active != null) {
        context.go('/conversations/${active.id}');
      } else {
        context.go('/conversations');
      }
    } catch (error) {
       // Error is handled in UI below usually, but since this is a transition screen...
       // We might want to show a dialog or snackbar then redirect.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);

    if (state.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(
                  'Failed to join group',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/conversations'),
                  child: const Text('Go Home'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
