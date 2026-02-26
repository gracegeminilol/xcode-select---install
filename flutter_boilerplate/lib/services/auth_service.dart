import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService(this._supabase);

  final SupabaseClient _supabase;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authState => _supabase.auth.onAuthStateChange;

  Future<void> signUpStudent({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.endsWith('@illinois.edu')) {
      throw const AuthException('Student sign-up requires an @illinois.edu email.');
    }

    final response = await _supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {'full_name': fullName ?? ''},
      emailRedirectTo: null,
    );

    if (response.user == null) {
      throw const AuthException('Unable to create student account.');
    }

    await _supabase.from('profiles').upsert({
      'id': response.user!.id,
      'email': normalizedEmail,
      'full_name': fullName,
      'user_type': 'student',
      'id_verification_status': 'verified',
    });
  }

  Future<void> signUpResident({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {'full_name': fullName ?? ''},
      emailRedirectTo: null,
    );

    if (response.user == null) {
      throw const AuthException('Unable to create resident account.');
    }

    await _supabase.from('profiles').upsert({
      'id': response.user!.id,
      'email': normalizedEmail,
      'full_name': fullName,
      'user_type': 'resident',
      'id_verification_status': 'pending',
    });
  }

  Future<void> launchIdentityVerification({required String userId}) async {
    // Placeholder for server-side Stripe Identity session creation.
    // In production, call Supabase Edge Function that creates Stripe Identity
    // VerificationSession and returns a redirect URL.
    await _supabase.from('profiles').update({
      'stripe_identity_verification_session_id': 'pending_session',
    }).eq('id', userId);
  }

  Future<AppUser?> getCurrentProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final payload = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (payload == null) return null;
    return AppUser.fromJson(payload);
  }

  Future<void> signIn({required String email, required String password}) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _supabase.auth.signOut();
}
