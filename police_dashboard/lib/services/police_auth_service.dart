import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PoliceSession {
  const PoliceSession({
    required this.uid,
    required this.stationId,
  });

  final String uid;
  final String stationId;
}

class PoliceAuthService {
  PoliceAuthService._();

  static final PoliceAuthService instance = PoliceAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static const String _policeRole = 'police';

  static const String _adminRole = 'admin';

  static const Set<String> _bootstrapAdminEmails = <String>{
    'surakshasetu47@gmail.com',
  };

  bool _isBootstrapAdminEmail(String? email) {
    if (email == null) {
      return false;
    }
    return _bootstrapAdminEmails.contains(email.trim().toLowerCase());
  }

  String? _claimString(
    IdTokenResult tokenResult,
    String key,
  ) {
    final value = tokenResult.claims?[key];
    if (value == null) {
      return null;
    }
    return value.toString().trim();
  }

  Future<Map<String, String?>> _loadRoleAndStationFromProfile(
      String uid) async {
    String? role;
    String? stationId;
    try {
      final profile = await _firestore.collection('users').doc(uid).get();
      role = (profile.data()?['role'] as String?)?.trim().toLowerCase();
      stationId = (profile.data()?['stationId'] as String?)?.trim();
    } on FirebaseException {
      // If profile lookup is blocked/unavailable, rely on custom claims only.
      role = null;
      stationId = null;
    }
    return <String, String?>{
      'role': role,
      'stationId': stationId,
    };
  }

  Future<PoliceSession?> _resolvePoliceSession(
    User user, {
    bool forceRefresh = false,
  }) async {
    var tokenResult = await user.getIdTokenResult(forceRefresh);
    var role = _claimString(tokenResult, 'role')?.toLowerCase();
    var stationId = _claimString(tokenResult, 'stationId');

    if ((role != _policeRole || stationId == null || stationId.isEmpty) &&
        !forceRefresh) {
      tokenResult = await user.getIdTokenResult(true);
      role = _claimString(tokenResult, 'role')?.toLowerCase();
      stationId = _claimString(tokenResult, 'stationId');
    }

    // Fallback for legacy/partially provisioned police accounts:
    // use Firestore profile role + station when token claims are missing.
    if (role != _policeRole || stationId == null || stationId.isEmpty) {
      final profile = await _loadRoleAndStationFromProfile(user.uid);
      role = role == _policeRole ? role : profile['role'];
      stationId = (stationId == null || stationId.isEmpty)
          ? profile['stationId']
          : stationId;
    }

    if (role != _policeRole) {
      return null;
    }

    if (stationId == null || stationId.isEmpty) {
      return null;
    }

    return PoliceSession(uid: user.uid, stationId: stationId);
  }

  Future<PoliceSession> signInPolice({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final userId = credential.user?.uid;
    if (userId == null) {
      throw StateError('Invalid authenticated user.');
    }

    final session = await _resolvePoliceSession(
      credential.user!,
      forceRefresh: true,
    );
    if (session == null) {
      await _auth.signOut();
      throw StateError(
        'Access denied. This account is not approved as a police user.',
      );
    }

    return session;
  }

  Future<PoliceSession?> getCurrentPoliceSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return _resolvePoliceSession(user);
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    var tokenResult = await user.getIdTokenResult(false);
    var role = _claimString(tokenResult, 'role')?.toLowerCase();
    if (role == _adminRole) {
      return true;
    }

    tokenResult = await user.getIdTokenResult(true);
    role = _claimString(tokenResult, 'role')?.toLowerCase();
    if (role == _adminRole) {
      return true;
    }

    final tokenEmail = _claimString(tokenResult, 'email');
    if (_isBootstrapAdminEmail(tokenEmail) ||
        _isBootstrapAdminEmail(user.email)) {
      return true;
    }

    final profile = await _loadRoleAndStationFromProfile(user.uid);
    return profile['role'] == _adminRole || _isBootstrapAdminEmail(user.email);
  }

  Future<void> refreshCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    await user.getIdToken(true);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw StateError('Enter your email so we can send a reset link.');
    }
    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  Future<void> signOut() => _auth.signOut();
}
