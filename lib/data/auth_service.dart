import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/i18n/app_country.dart';
import 'models.dart';

class AppSession {
  const AppSession({this.phone, this.profileId, this.userId});

  final String? phone;
  final String? profileId;
  final String? userId;
}

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<AuthResponse> signIn({
    required String phone,
    required String password,
    AppCountry country = AppCountry.iq,
  }) {
    final local = country.normalizePhone(phone);
    if (!country.isValidPhone(local)) {
      throw AuthException(
          'أدخل رقماً صحيحاً لـ${country.nameAr} (${country.phoneHint})');
    }
    if (password.isEmpty) {
      throw const AuthException('أدخل كلمة المرور');
    }
    return _client.auth.signInWithPassword(
      phone: country.toE164(local),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? inviteCode,
    AppCountry country = AppCountry.iq,
  }) async {
    final name = fullName.trim();
    if (name.length < 3) {
      throw const AuthException('أدخل الاسم الكامل (3 أحرف على الأقل)');
    }
    final local = country.normalizePhone(phone);
    if (!country.isValidPhone(local)) {
      throw AuthException(
          'أدخل رقماً صحيحاً لـ${country.nameAr} (${country.phoneHint})');
    }
    if (password.length < 8) {
      throw const AuthException('كلمة المرور يجب أن تكون 8 أحرف على الأقل');
    }
    if (role != UserRole.tenant) {
      final valid = await _client.rpc('check_invite_code', params: {
        'p_role': role.dbValue,
        'p_invite_code': (inviteCode ?? '').trim(),
      });
      if (valid != true) {
        throw const AuthException('رمز الدعوة غير صحيح. تواصل مع إدارة النظام');
      }
    }

    return _client.auth.signUp(
      phone: country.toE164(local),
      password: password,
      data: {
        'full_name': name,
        'phone': local,
        'country': country.code,
      },
    );
  }

  Future<AuthResponse> verifySignupOtp({
    required String phone,
    required String code,
    required UserRole role,
    String? inviteCode,
    AppCountry country = AppCountry.iq,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: country.toE164(phone),
      token: code.trim(),
      type: OtpType.sms,
    );
    if (role != UserRole.tenant) {
      await _client.rpc('claim_role', params: {
        'p_role': role.dbValue,
        'p_invite_code': (inviteCode ?? '').trim(),
      });
    }
    return response;
  }

  Future<void> resendSignupOtp(String phone,
      {AppCountry country = AppCountry.iq}) {
    return _client.auth.signInWithOtp(phone: country.toE164(phone));
  }

  Future<void> updatePassword(String password) async {
    if (password.length < 8) {
      throw const AuthException('كلمة المرور يجب أن تكون 8 أحرف على الأقل');
    }
    await _client.auth.updateUser(UserAttributes(password: password));
  }
}

class SessionController extends ChangeNotifier {
  SessionController(this._auth) {
    _init();
  }

  final AuthService _auth;

  AppSession? session;
  bool loading = true;
  StreamSubscription<AuthState>? _authSub;

  Future<void> _init() async {
    _authSub = _auth.client.auth.onAuthStateChange.listen((state) {
      _applySupabaseSession(state.session);
    });
    _applySupabaseSession(_auth.client.auth.currentSession);
    loading = false;
    notifyListeners();
  }

  void _applySupabaseSession(Session? supabaseSession) {
    if (supabaseSession == null) {
      session = null;
    } else {
      final user = supabaseSession.user;
      final phone = user.phone?.isNotEmpty == true
          ? user.phone
          : user.userMetadata?['phone']?.toString();
      session = AppSession(
        phone: phone,
        userId: user.id,
        profileId: user.id,
      );
    }
    loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.client.auth.signOut();
    session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
