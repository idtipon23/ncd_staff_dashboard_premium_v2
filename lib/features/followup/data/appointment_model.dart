// lib/features/followup/data/appointment_model.dart

enum AppointmentStatusCategory {
  dueToday,
  upcoming,
  overdue,
  completed,
  missed,
}

class AppointmentItemModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? hn;
  final String? phone;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String clinicName;
  final String? doctorName;
  final String reason;
  final bool needFasting;
  final String status; // 'scheduled', 'completed', 'missed', 'cancelled'
  final DateTime createdAt;

  AppointmentItemModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.hn,
    this.phone,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.clinicName,
    this.doctorName,
    required this.reason,
    required this.needFasting,
    required this.status,
    required this.createdAt,
  });

  factory AppointmentItemModel.fromMap(Map<String, dynamic> map) {
    final patient = map['patients'] as Map<String, dynamic>?;
    final firstName = patient?['first_name'] ?? '';
    final lastName = patient?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    final dateStr = map['appointment_date']?.toString() ?? '';
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    return AppointmentItemModel(
      id: map['id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      patientName: fullName.isEmpty ? 'ไม่ระบุชื่อ' : fullName,
      hn: patient?['hn'],
      phone: patient?['phone'],
      appointmentDate: parsedDate,
      appointmentTime: map['appointment_time'] ?? '09:00',
      clinicName: map['clinic_name'] ?? 'คลินิก NCDs',
      doctorName: map['doctor_name'],
      reason: map['reason'] ?? 'ตรวจติดตามอาการ',
      needFasting: map['need_fasting'] == true,
      status: map['status'] ?? 'scheduled',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// คำนวณหมวดหมู่สถานะเทียบกับวันปัจจุบัน
  AppointmentStatusCategory get category {
    if (status == 'completed') return AppointmentStatusCategory.completed;
    if (status == 'missed' || status == 'cancelled') return AppointmentStatusCategory.missed;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);

    if (apptDay.isAtSameMomentAs(today)) {
      return AppointmentStatusCategory.dueToday;
    } else if (apptDay.isAfter(today)) {
      return AppointmentStatusCategory.upcoming;
    } else {
      return AppointmentStatusCategory.overdue;
    }
  }
}