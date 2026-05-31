import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  UserProfile? _profile;
  bool _isLoading = true;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  SupabaseClient get supabase => _supabase;

  AuthProvider() {
    _init();
  }

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await fetchProfile();
      } else {
        _profile = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> fetchProfile() async {
    if (_user == null) return;
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      if (response != null) {
        _profile = UserProfile.fromJson(response);
      } else {
        _profile = null;
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> signUp(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Returns true if role is successfully set
  Future<bool> setRole(String role) async {
    if (_user == null) return false;
    try {
        final existing = await _supabase.from('users').select().eq('id', _user!.id).maybeSingle();
        if (existing != null) {
            return false; // Already has role
        }
      await _supabase.from('users').insert({
        'id': _user!.id,
        'email': _user!.email,
        'role': role,
      });
      await fetchProfile();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error setting role: $e");
      return false;
    }
  }
}
