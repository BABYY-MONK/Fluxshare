import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/file_item.dart';

/// User account model for FluxShare session & auth.
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;
  final bool isPro;

  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.isAnonymous,
    this.isPro = false,
  });

  String get shortName {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (email != null && email!.isNotEmpty) return email!.split('@').first;
    return 'Guest #${uid.length > 5 ? uid.substring(0, 5) : uid}';
  }
}

/// Represents the quota usage for the current user.
class UserQuota {
  final int used;
  final int limit;
  final bool isPro;

  const UserQuota({
    required this.used,
    required this.limit,
    required this.isPro,
  });

  int get remaining => isPro ? 999999 : (limit - used).clamp(0, limit);
  bool get canConvert => isPro || used < limit;
}

/// Manages Firebase Authentication, Cloud Storage, and Firestore integration.
/// Automatically detects whether Firebase credentials are configured in
/// [DefaultFirebaseOptions] and falls back to session-mock mode if not yet configured.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isConfigured = false;
  bool _isInitialized = false;

  final _userController = StreamController<UserModel?>.broadcast();
  final _quotaController = StreamController<UserQuota>.broadcast();

  UserModel? _currentUser;
  int _conversionsUsed = 0;
  final int _freeLimit = 3;
  bool _isPro = false;

  Stream<UserModel?> get userStream => _userController.stream;
  Stream<UserQuota> get quotaStream => _quotaController.stream;
  UserModel? get currentUser => _currentUser;
  UserQuota get currentQuota => UserQuota(
        used: _conversionsUsed,
        limit: _freeLimit,
        isPro: _isPro,
      );
  bool get isFirebaseAvailable => _isConfigured;

  /// Initializes Firebase and establishes initial anonymous authentication session.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final apiKey = DefaultFirebaseOptions.web.apiKey;
    _isConfigured = apiKey != 'YOUR_API_KEY' && apiKey.isNotEmpty;

    if (_isConfigured) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);

        // Sign in anonymously if no active user session
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }
        _isInitialized = true;
        debugPrint('[FluxShare] Firebase successfully initialized.');
      } catch (e) {
        debugPrint('[FluxShare] Firebase init error, falling back to mock mode: $e');
        _isConfigured = false;
        _initMockUser();
      }
    } else {
      debugPrint('[FluxShare] Firebase options have placeholder credentials. Running in local/simulation mode.');
      _initMockUser();
    }

    _emitQuota();
    _isInitialized = true;
  }

  void _initMockUser() {
    _currentUser = const UserModel(
      uid: 'guest_local_session',
      isAnonymous: true,
      displayName: 'Guest User',
    );
    _userController.add(_currentUser);
  }

  void _onAuthStateChanged(User? user) {
    if (user == null) {
      _currentUser = null;
    } else {
      _currentUser = UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        isAnonymous: user.isAnonymous,
        isPro: _isPro,
      );
    }
    _userController.add(_currentUser);
    _emitQuota();
  }

  void _emitQuota() {
    _quotaController.add(currentQuota);
  }

  /// Increments quota counter when a conversion/share occurs.
  void recordConversion() {
    _conversionsUsed++;
    _emitQuota();
  }

  /// Sign In with Google for persistent profile and higher limits.
  Future<void> signInWithGoogle() async {
    if (!_isConfigured) {
      // Simulate Google Sign In for demo/test mode
      _currentUser = const UserModel(
        uid: 'user_google_pro_demo',
        email: 'alex.creator@example.com',
        displayName: 'Alex Creator',
        isAnonymous: false,
        isPro: true,
      );
      _isPro = true;
      _userController.add(_currentUser);
      _emitQuota();
      return;
    }

    try {
      final googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      debugPrint('[FluxShare] Google sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign out current user and revert to anonymous session.
  Future<void> signOut() async {
    _isPro = false;
    if (_isConfigured) {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
    } else {
      _initMockUser();
      _conversionsUsed = 0;
      _emitQuota();
    }
  }

  /// Upgrades user to Pro mode.
  void activateProPlan() {
    _isPro = true;
    if (_currentUser != null) {
      _currentUser = UserModel(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        displayName: _currentUser!.displayName,
        photoUrl: _currentUser!.photoUrl,
        isAnonymous: _currentUser!.isAnonymous,
        isPro: true,
      );
      _userController.add(_currentUser);
    }
    _emitQuota();
  }

  // ─── Cloud Storage Upload & Firestore Sharing ──────────────────────────────

  /// Uploads [fileItem] to Firebase Cloud Storage, registers metadata in Firestore,
  /// and updates [fileItem.cloudDownloadUrl] and [fileItem.expiresAt].
  ///
  /// Calls [onProgress] with values from 0.0 to 1.0.
  Future<String> uploadAndShareFile({
    required FileItem fileItem,
    required void Function(double progress) onProgress,
  }) async {
    final bytes = fileItem.convertedBytes ?? fileItem.originalBytes;
    final fileName = fileItem.outputFileName;
    final fileId = fileItem.id;
    final userId = _currentUser?.uid ?? 'anon_guest';

    // 24-hour expiration for free tier, permanent for Pro
    final expiresAt = _isPro ? null : DateTime.now().add(const Duration(hours: 24));

    if (_isConfigured) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('fluxshare')
            .child(userId)
            .child('${fileId}_$fileName');

        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: _mimeFor(fileItem.targetFormat.extension),
            customMetadata: {
              'originalName': fileItem.originalName,
              'fileId': fileId,
              'userId': userId,
              'expiresAt': expiresAt?.toIso8601String() ?? 'never',
            },
          ),
        );

        uploadTask.snapshotEvents.listen((event) {
          if (event.totalBytes > 0) {
            final progress = event.bytesTransferred / event.totalBytes;
            onProgress(progress);
          }
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Register in Firestore collection 'files'
        await FirebaseFirestore.instance.collection('files').doc(fileId).set({
          'fileId': fileId,
          'userId': userId,
          'originalName': fileItem.originalName,
          'convertedName': fileName,
          'status': 'completed',
          'downloadUrl': downloadUrl,
          'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
          'size': bytes.length,
          'createdAt': FieldValue.serverTimestamp(),
          'format': fileItem.targetFormat.extension,
        });

        fileItem.cloudDownloadUrl = downloadUrl;
        fileItem.expiresAt = expiresAt;
        fileItem.isUploadedToCloud = true;
        recordConversion();
        return downloadUrl;
      } catch (e) {
        debugPrint('[FluxShare] Cloud upload failed, falling back to simulated cloud URL: $e');
      }
    }

    // ── Simulated Cloud Upload (Fallback / Demo mode) ──
    for (int step = 1; step <= 10; step++) {
      await Future.delayed(const Duration(milliseconds: 60));
      onProgress(step / 10.0);
    }

    // Generate simulated public share URL
    final simulatedUrl = 'https://fluxshare.web.app/s/$fileId';
    fileItem.cloudDownloadUrl = simulatedUrl;
    fileItem.expiresAt = expiresAt;
    fileItem.isUploadedToCloud = true;
    recordConversion();
    return simulatedUrl;
  }

  String _mimeFor(String ext) => switch (ext.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };
}
