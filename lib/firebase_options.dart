import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Web ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpnyWgdV0wbsEa2CcUtbe-1XwLjGt6jBI',
    appId: '1:975428648183:web:c19de95352bb1abd8827f2',
    messagingSenderId: '975428648183',
    projectId: 'smartmind-new',
    authDomain: 'smartmind-new.firebaseapp.com',
    storageBucket: 'smartmind-new.firebasestorage.app',
    measurementId: 'G-PSHV5CGDN8',
  );

  // ── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBnfYJ3AhjmZ_x4lvdbgwa_gwwTECCVMk8',
    appId: '1:975428648183:android:0fa7ffc14de746ba8827f2',
    messagingSenderId: '975428648183',
    projectId: 'smartmind-new',
    storageBucket: 'smartmind-new.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCU8Av21VbT6wfw5K4PRJfwur7wj7waETk',
    appId: '1:975428648183:ios:3f3c6efda6afe72a8827f2',
    messagingSenderId: '975428648183',
    projectId: 'smartmind-new',
    storageBucket: 'smartmind-new.firebasestorage.app',
    iosBundleId: 'com.smartmind.app',
  );
}
