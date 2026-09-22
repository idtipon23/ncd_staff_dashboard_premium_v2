// lib/features/followup/data/appointment_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment_model.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository(Supabase.instance.client);
});

final appointmentsListProvider = FutureProvider.autoDispose<List<AppointmentItemModel>>((ref) async {
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.fetchAllAppointments();
});

class AppointmentRepository {
  final SupabaseClient _client;

  AppointmentRepository(this._client);

  /// ดึงรายการนัดหมายทั้งหมดพร้อมข้อมูลผู้ป่วย
  Future<List<AppointmentItemModel>> fetchAllAppointments() async {
    final res = await _client
        .from('appointments')
        .select('''
          id,
          patient_id,
          appointment_date,
          appointment_time,
          clinic_name,
          doctor_name,
          reason,
          need_fasting,
          status,
          created_at,
          patients!inner (
            first_name,
            last_name,
            hn,
            phone
          )
        ''')
        .order('appointment_date', ascending: true);

    final list = res as List<dynamic>;
    return list.map((item) => AppointmentItemModel.fromMap(item as Map<String, dynamic>)).toList();
  }

  /// อัปเดตสถานะนัดหมาย (completed, missed, cancelled)
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    required String patientId,
    String? note,
  }) async {
    await _client.from('appointments').update({
      'status': status,
    }).eq('id', appointmentId);

    // บันทึกลง staff_notes โดยไม่มีคอลัมน์ sent_to_line
    final user = _client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'พยาบาลเวชปฏิบัติ';

    String actionText = 'อัปเดตสถานะนัดหมายเป็น: $status';
    if (status == 'completed') {
      actionText = 'ผู้ป่วยมาตรวจตามนัดหมายเรียบร้อยแล้ว';
    } else if (status == 'missed') {
      actionText = 'ผู้ป่วยขาดนัด (Missed Appointment) อยู่ระหว่างประสานติดตาม';
    }

    if (note != null && note.isNotEmpty) {
      actionText += ' (บันทึก: $note)';
    }

    await _client.from('staff_notes').insert({
      'patient_id': patientId,
      'staff_name': staffName,
      'note_text': actionText,
    });
  }

  /// เลื่อนวันนัดหมาย (Reschedule)
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDate,
    required String newTime,
    required String patientId,
    required String reason,
  }) async {
    final dateStr = newDate.toIso8601String().split('T').first;

    await _client.from('appointments').update({
      'appointment_date': dateStr,
      'appointment_time': newTime,
      'status': 'scheduled',
      'is_notified_3days': false,
      'is_notified_1day': false,
    }).eq('id', appointmentId);

    final user = _client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'พยาบาลเวชปฏิบัติ';

    await _client.from('staff_notes').insert({
      'patient_id': patientId,
      'staff_name': staffName,
      'note_text': 'เลื่อนวันนัดหมายเป็นวันที่ $dateStr เวลา $newTime น. (เหตุผล: $reason)',
    });
  }
}