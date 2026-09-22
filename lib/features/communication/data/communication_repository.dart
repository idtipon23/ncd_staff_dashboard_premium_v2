// lib/features/communication/data/communication_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationLogModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? hn;
  final String? phone;
  final String? lineUserId;
  final String staffName;
  final String noteText;
  final DateTime createdAt;

  CommunicationLogModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.hn,
    this.phone,
    this.lineUserId,
    required this.staffName,
    required this.noteText,
    required this.createdAt,
  });

  factory CommunicationLogModel.fromMap(Map<String, dynamic> map) {
    final patient = map['patients'] as Map<String, dynamic>?;
    final firstName = patient?['first_name'] ?? '';
    final lastName = patient?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    return CommunicationLogModel(
      id: map['id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      patientName: fullName.isEmpty ? 'ไม่ระบุชื่อ' : fullName,
      hn: patient?['hn'],
      phone: patient?['phone'],
      lineUserId: patient?['line_user_id'],
      staffName: map['staff_name'] ?? 'เจ้าหน้าที่',
      noteText: map['note_text'] ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get hasLineConnected => lineUserId != null && lineUserId!.trim().isNotEmpty;
}

final communicationRepositoryProvider = Provider<CommunicationRepository>((ref) {
  return CommunicationRepository(Supabase.instance.client);
});

final communicationLogsProvider = FutureProvider.autoDispose<List<CommunicationLogModel>>((ref) async {
  final repo = ref.watch(communicationRepositoryProvider);
  return repo.fetchCommunicationLogs();
});

class CommunicationRepository {
  final SupabaseClient _client;

  CommunicationRepository(this._client);

  /// ดึงประวัติการสื่อสารจาก staff_notes ร่วมกับข้อมูลผู้ป่วย
  Future<List<CommunicationLogModel>> fetchCommunicationLogs() async {
    final res = await _client
        .from('staff_notes')
        .select('''
          id,
          patient_id,
          staff_name,
          note_text,
          created_at,
          patients!inner (
            first_name,
            last_name,
            hn,
            phone,
            line_user_id
          )
        ''')
        .order('created_at', ascending: false)
        .limit(100);

    final list = res as List<dynamic>;
    return list.map((e) => CommunicationLogModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// ส่งข้อความผ่าน Edge Function line-notifier และบันทึกลง staff_notes
  Future<void> sendDirectMessage({
    required String patientId,
    required String message,
    String? lineUserId,
  }) async {
    final user = _client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'พยาบาลเวชปฏิบัติ';

    // 1. ส่งผ่าน Edge Function หากผู้ป่วยมี LINE ID
    if (lineUserId != null && lineUserId.trim().isNotEmpty) {
      await _client.functions.invoke(
        'line-notifier',
        body: {
          'patientId': patientId,
          'message': message,
          'staffName': staffName,
          'lineUserId': lineUserId,
        },
      );
    }

    // 2. บันทึกลง staff_notes (เฉพาะคอลัมน์ที่มีอยู่จริง)
    await _client.from('staff_notes').insert({
      'patient_id': patientId,
      'staff_name': staffName,
      'note_text': message,
    });
  }
}