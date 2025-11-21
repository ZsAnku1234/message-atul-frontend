import 'dart:async';
import 'dart:developer' as developer;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/conversation.dart';
import '../models/message.dart';
import 'auth_repository.dart';
import 'chat_mapper.dart';

class SocketService {
  SocketService({
    required AuthRepository authRepository,
    required String socketUrl,
  })  : _authRepository = authRepository,
        _socketUrl = socketUrl;

  final AuthRepository _authRepository;
  final String _socketUrl;

  final _eventController = StreamController<ChatSocketEvent>.broadcast();
  io.Socket? _socket;

  bool _isDisposed = false;

  Stream<ChatSocketEvent> get events => _eventController.stream;

  Future<void> connect() async {
    if (_isDisposed || _socket?.connected == true) {
      return;
    }

    final token = await _authRepository.readToken();
    if (token == null) {
      return;
    }

    _socket?.dispose();
    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': 'Bearer $token'})
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .disableAutoConnect()
        .enableReconnection()
        .enableForceNew()
        .build();

    final socket = io.io(_socketUrl, options);

    socket.onConnect((_) {
      _emitEvent(const ChatSocketConnectionChanged(true));
    });

    socket.onDisconnect((_) {
      _emitEvent(const ChatSocketConnectionChanged(false));
    });

    socket.onConnectError((error) {
      developer.log(
        'Socket connect error',
        name: 'SocketService',
        error: error,
      );
      _emitEvent(const ChatSocketConnectionChanged(false));
    });

    socket.onError((error) {
      developer.log(
        'Socket error',
        name: 'SocketService',
        error: error,
      );
    });

    socket.on('message:new', (dynamic payload) {
      final message = _safeMapMessage(payload);
      if (message != null) {
        _emitEvent(ChatSocketMessageReceived(message));
      }
    });

    socket.on('message:updated', (dynamic payload) {
      final message = _safeMapMessage(payload);
      if (message != null) {
        _emitEvent(ChatSocketMessageUpdated(message));
      }
    });

    socket.on('message:deleted', (dynamic payload) {
      final data = _asMap(payload);
      if (data == null) {
        return;
      }
      final messageId = data['messageId'] as String?;
      final conversationId =
          data['conversationId'] as String? ?? data['conversation'] as String?;
      if (messageId != null && conversationId != null) {
        _emitEvent(ChatSocketMessageDeleted(messageId, conversationId));
      }
    });

    socket.on('conversation:updated', (dynamic payload) {
      final conversation = _safeMapConversation(payload);
      if (conversation != null) {
        _emitEvent(ChatSocketConversationUpdated(conversation));
      }
    });

    socket.on('conversation:added', (dynamic payload) {
      final conversation = _safeMapConversation(payload);
      if (conversation != null) {
        _emitEvent(ChatSocketConversationAdded(conversation));
      }
    });

    socket.on('conversation:removed', (dynamic payload) {
      final data = _asMap(payload);
      final id = data?['conversationId'] as String?;
      if (id != null) {
        _emitEvent(ChatSocketConversationRemoved(id));
      }
    });

    socket.on('conversation:deleted', (dynamic payload) {
      final data = _asMap(payload);
      final id = data?['conversationId'] as String?;
      if (id != null) {
        _emitEvent(ChatSocketConversationDeleted(id));
      }
    });

    socket.connect();
    _socket = socket;
  }

  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _emitEvent(const ChatSocketConnectionChanged(false));
  }

  Future<void> joinConversation(String conversationId) async {
    final socket = await _requireSocket();
    socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  Future<void> leaveConversation(String conversationId) async {
    final socket = _socket;
    socket?.emit('conversation:leave', {'conversationId': conversationId});
  }

  Future<io.Socket?> _requireSocket() async {
    if (_socket?.connected == true) {
      return _socket;
    }
    await connect();
    return _socket;
  }

  Message? _safeMapMessage(dynamic payload) {
    final data = _asMap(payload);
    if (data == null) {
      return null;
    }
    try {
      return ChatMapper.mapMessage(data);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to map incoming message',
        name: 'SocketService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  ConversationSummary? _safeMapConversation(dynamic payload) {
    final data = _asMap(payload);
    final conversation = data?['conversation'];
    if (conversation is Map) {
      try {
        return ChatMapper.mapConversation(
            Map<String, dynamic>.from(conversation));
      } catch (error, stackTrace) {
        developer.log(
          'Failed to map conversation payload',
          name: 'SocketService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  void dispose() {
    _isDisposed = true;
    _socket?.dispose();
    _socket = null;
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }

  void _emitEvent(ChatSocketEvent event) {
    if (_isDisposed || _eventController.isClosed) {
      return;
    }
    _eventController.add(event);
  }
}

abstract class ChatSocketEvent {
  const ChatSocketEvent();
}

class ChatSocketConnectionChanged extends ChatSocketEvent {
  const ChatSocketConnectionChanged(this.isConnected);

  final bool isConnected;
}

class ChatSocketMessageReceived extends ChatSocketEvent {
  const ChatSocketMessageReceived(this.message);

  final Message message;
}

class ChatSocketMessageUpdated extends ChatSocketEvent {
  const ChatSocketMessageUpdated(this.message);

  final Message message;
}

class ChatSocketMessageDeleted extends ChatSocketEvent {
  const ChatSocketMessageDeleted(this.messageId, this.conversationId);

  final String messageId;
  final String conversationId;
}

class ChatSocketConversationUpdated extends ChatSocketEvent {
  const ChatSocketConversationUpdated(this.conversation);

  final ConversationSummary conversation;
}

class ChatSocketConversationAdded extends ChatSocketEvent {
  const ChatSocketConversationAdded(this.conversation);

  final ConversationSummary conversation;
}

class ChatSocketConversationRemoved extends ChatSocketEvent {
  const ChatSocketConversationRemoved(this.conversationId);

  final String conversationId;
}

class ChatSocketConversationDeleted extends ChatSocketEvent {
  const ChatSocketConversationDeleted(this.conversationId);

  final String conversationId;
}

String deriveSocketUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  if (uri.host.isEmpty) {
    return apiBaseUrl;
  }

  final normalized = Uri(
    scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );

  return normalized.toString();
}
