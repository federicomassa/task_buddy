// Placeholder Firebase configuration.
//
// Run `flutterfire configure` from the project root to generate the real
// version of this file for your Firebase project. That command overwrites
// this file in place, so nothing further needs to change once you do.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBISXNXUGym-n4scedUMnumxCySuygoTOo',
    appId: '1:1046350224596:web:fb261009d72b5814626f41',
    messagingSenderId: '1046350224596',
    projectId: 'taskbuddy-d62a2',
    authDomain: 'taskbuddy-d62a2.firebaseapp.com',
    storageBucket: 'taskbuddy-d62a2.firebasestorage.app',
    measurementId: 'G-LQFZPD884G',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA3--OjMi22Qkwoc6WvC_psb9k32yp0D54',
    appId: '1:1046350224596:android:3d1ed80c62de7c42626f41',
    messagingSenderId: '1046350224596',
    projectId: 'taskbuddy-d62a2',
    storageBucket: 'taskbuddy-d62a2.firebasestorage.app',
  );
}
