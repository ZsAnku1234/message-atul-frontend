import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options have not been configured for this platform. Run flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDBMBEvo6-059sPIuKFcQiL-tsRSwCEYr4',
    appId: '1:247274581964:ios:1405ccf98e50fe0065f769',
    messagingSenderId: '247274581964',
    projectId: 'nuttgram-23e1e',
    storageBucket: 'nuttgram-23e1e.firebasestorage.app',
    iosBundleId: 'com.example.messageAppFrontend',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdb53uZtBz1IW5DLeUDZywQdXVXPmqTjY',
    appId: '1:247274581964:android:2556ecb55e73ebff65f769',
    messagingSenderId: '247274581964',
    projectId: 'nuttgram-23e1e',
    storageBucket: 'nuttgram-23e1e.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCSxgphimOY1qU67sm2mioFyqFVG_0K-yg",
    appId: "1:247274581964:web:de17c3ea88e48dd565f769",
    messagingSenderId: "247274581964",
    projectId: "nuttgram-23e1e",
    authDomain: "nuttgram-23e1e.firebaseapp.com",
    storageBucket: "nuttgram-23e1e.firebasestorage.app",
  );
}
