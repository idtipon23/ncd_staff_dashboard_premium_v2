import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/staff_auth_repository.dart';

final patientRegistrationRepositoryProvider = Provider<PatientRegistrationRepository>((ref) {
  return PatientRegistrationRepository(Supabase.instance.client, ref);
});

class PatientRegistrationParams {
  final String? hn;
  final String firstName;
  final String lastName;
  final int age;
  final String gender;
  final String? phone;
  final String? underlyingDiseases;
  final String patientCategory;
  final double? weightKg;
  final double? heightCm;

  PatientRegistrationParams({
    this.hn,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.gender,
    this.phone,
    this.underlyingDiseases,
    this.patientCategory = 'GENERAL',
    this.weightKg,
    this.heightCm,
  });
}

class PatientRegistrationRepository {
  final SupabaseClient _client;
  final Ref _ref;

  PatientRegistrationRepository(this._client, this._ref);

  Future<Map<String, dynamic>> registerPatient(PatientRegistrationParams params) async {
    // 1. ดึงข้อมูล Facility ID ของเจ้าหน้าที่ที่กำลังล็อกอินอยู่
    final staffProfile = await _ref.read(currentStaffProfileProvider.future);
    final facilityId = staffProfile?.facilityId ?? '8f560a00-9b32-4185-a193-4c8afd4e2eb7';

    // 2. คำนวณ BMI หากระบุน้ำหนักและส่วนสูง
    String? bmi;
    if (params.weightKg != null && params.heightCm != null && params.heightCm! > 0) {
      final hMeters = params.heightCm! / 100;
      final bmiVal = params.weightKg! / (hMeters * hMeters);
      bmi = bmiVal.toStringAsFixed(1);
    }

    // 3. กำหนด HN: หากไม่ได้กรอก ให้เรียก RPC ดึงเลขตามฟอร์แมต 69-XXXXXX
    String finalHn = params.hn?.trim() ?? '';
    if (finalHn.isEmpty) {
      try {
        final hnRes = await _client.rpc('generate_clinic_hn', params: {
          'p_facility_id': facilityId,
        });
        finalHn = hnRes?.toString() ?? '';
      } catch (e) {
        debugPrint('⚠️ Error calling generate_clinic_hn RPC: $e');
        // หากต่อ RPC สะดุด ให้ส่งว่างเพื่อให้ Trigger ใน Database ออกเลขให้แทน
        finalHn = '';
      }
    }

    // 4. บันทึกข้อมูลขึ้นตาราง patients
    final insertData = {
      'hospital_id': facilityId,
      if (finalHn.isNotEmpty) 'hn': finalHn,
      'first_name': params.firstName.trim(),
      'last_name': params.lastName.trim(),
      'name': '${params.firstName.trim()} ${params.lastName.trim()}',
      'age': params.age,
      'gender': params.gender,
      'phone': params.phone?.trim().isNotEmpty == true ? params.phone!.trim() : null,
      'underlying_diseases': params.underlyingDiseases ?? 'ไม่มีโรคประจำตัว',
      'patient_category': params.patientCategory,
      'weight_kg': params.weightKg?.toString(),
      'height_cm': params.heightCm?.toString(),
      'bmi': bmi,
      'is_active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _client
          .from('patients')
          .insert(insertData)
          .select()
          .single();

      debugPrint('✅ สร้างเวชระเบียนผู้ป่วยใหม่สำเร็จ: ${response['id']} (HN: $finalHn, Facility: $facilityId)');
      return response;
    } catch (e) {
      debugPrint('❌ เกิดข้อผิดพลาดในการลงทะเบียนผู้ป่วย: $e');
      rethrow;
    }
  }
  /// ยืนยันรหัสผ่านเจ้าของคลินิก/แพทย์ แล้วสั่งลบข้อมูลผู้ป่วยทั้งหมด
  Future<void> deletePatientWithReAuth({
    required String patientId,
    required String email,
    required String password,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('ไม่พบเซสชันการเข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่');
    }

    // 1. Re-authenticate: ยืนยันความถูกต้องของ Email และ Password ของผู้ใช้งานปัจจุบัน
    try {
      final authTest = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (authTest.user == null) {
        throw Exception('การยืนยันตัวตนล้มเหลว');
      }
    } catch (e) {
      throw Exception('อีเมลหรือรหัสผ่านยืนยันไม่ถูกต้อง ไม่อนุญาตให้ลบข้อมูล');
    }

    // 2. เรียก Database Function เพื่อล้างข้อมูลผู้ป่วยและประวัติที่เกี่ยวข้องทั้งหมด
    try {
      await _client.rpc('admin_delete_patient', params: {
        'p_patient_id': patientId,
      });
      debugPrint('🗑️ ลบข้อมูลเวชระเบียนผู้ป่วย $patientId สำเร็จ');
    } catch (e) {
      debugPrint('❌ ไม่สามารถลบข้อมูลผู้ป่วยได้: $e');
      rethrow;
    }
  }
}