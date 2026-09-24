import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffProfile {
  final String id;
  final String facilityId;
  final String facilityName;
  final String email;
  final String fullName;
  final String role; // 'ADMIN', 'DOCTOR', 'NURSE', 'PHARMACIST', 'REGISTRATION'
  final String? licenseNo;

  StaffProfile({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.email,
    required this.fullName,
    required this.role,
    this.licenseNo,
  });

  factory StaffProfile.fromMap(Map<String, dynamic> map, {String? facilityName}) {
    return StaffProfile(
      id: map['id']?.toString() ?? '',
      facilityId: map['facility_id']?.toString() ?? '',
      facilityName: facilityName ?? 'หน่วยบริการเวชปฏิบัติ',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      role: map['role']?.toString() ?? 'NURSE',
      licenseNo: map['license_no']?.toString(),
    );
  }
}

final staffAuthRepositoryProvider = Provider<StaffAuthRepository>((ref) {
  return StaffAuthRepository(Supabase.instance.client);
});

final currentStaffProfileProvider = FutureProvider.autoDispose<StaffProfile?>((ref) async {
  final repo = ref.watch(staffAuthRepositoryProvider);
  return repo.getCurrentStaffProfile();
});

class StaffAuthRepository {
  final SupabaseClient _client;

  StaffAuthRepository(this._client);

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentAuthUser => _client.auth.currentUser;

  Future<StaffProfile?> getCurrentStaffProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from('staff_profiles')
          .select('*, facilities(facility_name)')
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) return null;

      final facilityName = res['facilities'] != null ? res['facilities']['facility_name']?.toString() : null;
      return StaffProfile.fromMap(res, facilityName: facilityName);
    } catch (e) {
      debugPrint('⚠️ Fetch staff profile error: $e');
      return null;
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint('❌ Staff Login Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}