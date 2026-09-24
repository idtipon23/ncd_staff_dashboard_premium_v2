import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final clinicalEntryRepositoryProvider = Provider<ClinicalEntryRepository>((ref) {
  return ClinicalEntryRepository(Supabase.instance.client);
});

class ClinicalEntryRepository {
  final SupabaseClient _client;
  ClinicalEntryRepository(this._client);

  /// 1. บันทึกสัญญาณชีพและอาการ (V/S & Symptoms)
  Future<void> saveVitalSigns({
    required String patientId,
    required int systolic,
    required int diastolic,
    required int pulse,
    double? temperature,
    int? respiratoryRate,
    double? weightKg,
    double? heightCm,
    String? symptomsOrFeedback,
  }) async {
    final user = _client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'เจ้าหน้าที่คลินิก';

    // คำนวณระดับความเร่งด่วนตามเกณฑ์ Triage
    String urgency = 'NORMAL';
    if (systolic >= 180 || diastolic >= 110) {
      urgency = 'CRITICAL';
    } else if ((systolic > 0 && systolic < 100) || (diastolic > 0 && diastolic < 60)) {
      urgency = 'WARNING';
    } else if (systolic >= 140 || diastolic >= 90) {
      urgency = 'WARNING';
    }

    await _client.from('vital_signs').insert({
      'patient_id': patientId,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'temperature': temperature,
      'respiratory_rate': respiratoryRate,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'spoken_feedback': symptomsOrFeedback,
      'urgency_level': urgency,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });

    final vitalSummary = 'บันทึก V/S: $systolic/$diastolic mmHg, ชีพจร $pulse bpm'
        '${temperature != null ? ', T $temperature°C' : ''}'
        '${symptomsOrFeedback != null && symptomsOrFeedback.isNotEmpty ? ' | อาการ: $symptomsOrFeedback' : ''}';

    await _client.from('staff_notes').insert({
      'patient_id': patientId,
      'staff_name': staffName,
      'note_text': vitalSummary,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 2. บันทึกผลแล็บเลือดและปัสสาวะ (Lab Results)
  Future<void> saveLabResults({
    required String patientId,
    required DateTime labDate,
    double? fbs,
    double? hba1c,
    double? creatinine,
    double? egfr,
    double? potassium,
    double? totalCholesterol,
    double? ldl,
    double? hdl,
    double? triglycerides,
    String? interpretation,
    String? imageUrl,
  }) async {
    final user = _client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'เจ้าหน้าที่ชันสูตร';

    await _client.from('lab_results').insert({
      'patient_id': patientId,
      'lab_date': labDate.toIso8601String().split('T').first,
      'test_type': 'LAB',
      'fbs': fbs,
      'hba1c': hba1c,
      'creatinine': creatinine,
      'egfr': egfr,
      'potassium': potassium,
      'cholesterol': totalCholesterol,
      'ldl': ldl,
      'hdl': hdl,
      'triglycerides': triglycerides,
      'clinical_interpretation': interpretation,
      'image_url': imageUrl,
      'staff_recorder_name': staffName,
    });
  }

  /// 3. บันทึกผลการตรวจ X-Ray หรือ EKG พร้อมภาพแนบ
  Future<void> saveDiagnosticImaging({
    required String patientId,
    required String testType, // 'XRAY' หรือ 'EKG'
    required DateTime examDate,
    required String interpretation,
    String? imageUrl,
  }) async {
    final user = _client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'แพทย์/เจ้าหน้าที่รังสี';

    await _client.from('lab_results').insert({
      'patient_id': patientId,
      'lab_date': examDate.toIso8601String().split('T').first,
      'test_type': testType,
      'clinical_interpretation': interpretation,
      'image_url': imageUrl,
      'staff_recorder_name': staffName,
    });

    final testNameThai = testType == 'XRAY'
        ? 'ภาพเอกซเรย์ทรวงอก (Chest X-Ray)'
        : 'คลื่นไฟฟ้าหัวใจ (EKG 12-Lead)';

    await _client.from('staff_notes').insert({
      'patient_id': patientId,
      'staff_name': staffName,
      'note_text': '[$testNameThai] $interpretation',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 4. อัปโหลดภาพไปยัง Supabase Storage
  Future<String> uploadClinicalImage({
    required String patientId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = '$patientId/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';

    await _client.storage.from('clinical_attachments').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _client.storage.from('clinical_attachments').getPublicUrl(filePath);
  }
}