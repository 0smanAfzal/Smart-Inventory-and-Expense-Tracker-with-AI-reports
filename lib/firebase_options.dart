
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAe0vbZ6ezW3AbBwKJCxc_1X3xYFelK7dY',
    appId: '1:602736024434:android:cfce30cfa0b615d9a8dbeb',
    messagingSenderId: '602736024434',
    projectId: 'testproject-80298',
    storageBucket: 'testproject-80298.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_IOS_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'YOUR_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBVs32zwZxtUbhtS5mVmqamqOR5zCiVVOE',
    appId: '1:602736024434:web:008b081254b2c582a8dbeb',
    messagingSenderId: '602736024434',
    projectId: 'testproject-80298',
    storageBucket: 'testproject-80298.firebasestorage.app',
    authDomain: 'testproject-80298.firebaseapp.com',
    measurementId: 'G-PY4G5GJBNK',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_LINUX_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );
}
