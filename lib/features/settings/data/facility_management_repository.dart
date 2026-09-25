import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/staff_auth_repository.dart';

class FacilityDetail {
  final String id;
  final String facilityCode;
  final String facilityName;
  final String subscriptionStatus;
  final DateTime createdAt;

  FacilityDetail({
    required this.id,
    required this.facilityCode,
    required this.facilityName,
    required this.subscriptionStatus,
    required this.createdAt,
  });

  factory FacilityDetail.fromMap(Map<String, dynamic> map) {
    return FacilityDetail(
      id: map['id']?.toString() ?? '',
      facilityCode: map['facility_code']?.toString() ?? '',
      facilityName: map['facility_name']?.toString() ?? '',
      subscriptionStatus: map['subscription_status']?.toString() ?? 'ACTIVE',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

final facilityManagementRepositoryProvider = Provider<FacilityManagementRepository>((ref) {
  return FacilityManagementRepository(Supabase.instance.client, ref);
});

final currentFacilityDetailProvider = FutureProvider.autoDispose<FacilityDetail?>((ref) async {
  final repo = ref.watch(facilityManagementRepositoryProvider);
  return repo.fetchCurrentFacility();
});

final facilityStaffListProvider = FutureProvider.autoDispose<List<StaffProfile>>((ref) async {
  final repo = ref.watch(facilityManagementRepositoryProvider);
  return repo.fetchFacilityStaff();
});

class FacilityManagementRepository {
  final SupabaseClient _client;
  final Ref _ref;

  FacilityManagementRepository(this._client, this._ref);

  /// ดึงข้อมูลหน่วยบริการปัจจุบัน
  Future<FacilityDetail?> fetchCurrentFacility() async {
    try {
      final staff = await _ref.read(currentStaffProfileProvider.future);
      final facilityId = staff?.facilityId ?? '8f560a00-9b32-4185-a193-4c8afd4e2eb7';

      final res = await _client
          .from('facilities')
          .select()
          .eq('id', facilityId)
          .maybeSingle();

      if (res == null) return null;
      return FacilityDetail.fromMap(res);
    } catch (e) {
      debugPrint('⚠️ Fetch facility error: $e');
      return null;
    }
  }

  /// ดึงรายชื่อเจ้าหน้าที่ทั้งหมดในคลินิก
  Future<List<StaffProfile>> fetchFacilityStaff() async {
    try {
      final staff = await _ref.read(currentStaffProfileProvider.future);
      final facilityId = staff?.facilityId ?? '8f560a00-9b32-4185-a193-4c8afd4e2eb7';

      final res = await _client
          .from('staff_profiles')
          .select('*, facilities(facility_name)')
          .eq('facility_id', facilityId)
          .order('role', ascending: true);

      return (res as List<dynamic>).map((item) {
        final facName = item['facilities'] != null ? item['facilities']['facility_name']?.toString() : null;
        return StaffProfile.fromMap(item as Map<String, dynamic>, facilityName: facName);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Fetch staff list error: $e');
      return [];
    }
  }

  /// บันทึกและผูกสิทธิ์เจ้าหน้าที่เข้ากับหน่วยบริการ (เรียก Stored Procedure)
  Future<void> registerStaff({
    required String userId,
    required String email,
    required String fullName,
    required String role,
    String? licenseNo,
  }) async {
    await _client.rpc('admin_register_staff', params: {
      'p_user_id': userId.trim(),
      'p_email': email.trim(),
      'p_full_name': fullName.trim(),
      'p_role': role,
      'p_license_no': licenseNo?.trim().isNotEmpty == true ? licenseNo!.trim() : null,
    });
  }

  /// เปิด/ปิดสถานะการทำงานของเจ้าหน้าที่ (Deactivate/Activate)
  Future<void> toggleStaffStatus(String staffId, bool isActive) async {
    await _client.from('staff_profiles').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', staffId);
  }

  /// สร้างคลินิกใหม่ (Super Admin Feature)
  Future<Map<String, dynamic>> createNewFacility({
    required String facilityCode,
    required String facilityName,
  }) async {
    final res = await _client.from('facilities').insert({
      'facility_code': facilityCode.trim().toUpperCase(),
      'facility_name': facilityName.trim(),
      'subscription_status': 'ACTIVE',
    }).select().single();

    return res;
  }
}