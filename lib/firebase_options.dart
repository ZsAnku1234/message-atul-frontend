import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase options have not been configured for web. Run flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options have not been configured for this platform. Run flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdb53uZtBz1IW5DLeUDZywQdXVXPmqTjY',
    appId: '1:247274581964:android:2556ecb55e73ebff65f769',
    messagingSenderId: '247274581964',
    projectId: 'nuttgram-23e1e',
    storageBucket: 'nuttgram-23e1e.firebasestorage.app',
  );
}
