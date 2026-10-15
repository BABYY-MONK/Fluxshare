// ─────────────────────────────────────────────────────────────────────────────
//  SETUP INSTRUCTIONS
//  1. Create a Firebase project at https://console.firebase.google.com
//  2. Add a Web app and copy the config values below.
//  3. Enable:  Authentication → Anonymous, Google
//              Firestore Database
//              Storage
//  4. Replace every "YOUR_*" placeholder with the real value from Firebase.
//
//  Alternatively, run:  flutterfire configure
//  and this file will be generated automatically.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'FluxShare is a web-only app. No native Firebase config needed.',
    );
  }

  /// ⬇️  Replace these values with your Firebase project's web config.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'YOUR_API_KEY',
    authDomain:        'YOUR_PROJECT_ID.firebaseapp.com',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    appId:             'YOUR_APP_ID',
  );
}
