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

  Future<Map<String, String?>> _loadRoleAndStationFromProfile(String uid) async {
    final profile = await _firestore.collection('users').doc(uid).get();
    final role = (profile.data()?['role'] as String?)?.trim().toLowerCase();
    final stationId = (profile.data()?['stationId'] as String?)?.trim();
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

    final profile = await _loadRoleAndStationFromProfile(user.uid);
    return profile['role'] == _adminRole;
  }

  Future<void> signOut() => _auth.signOut();
}
