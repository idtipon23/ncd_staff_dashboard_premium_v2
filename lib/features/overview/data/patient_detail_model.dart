// lib/features/overview/data/patient_detail_model.dart

class PatientDetailData {
  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> vitalSigns;
  final Map<String, dynamic>? latestLab;
  final List<Map<String, dynamic>> recentFoods;
  final List<Map<String, dynamic>> staffNotes;
  final List<Map<String, dynamic>> appointments;

  PatientDetailData({
    required this.patient,
    required this.vitalSigns,
    this.latestLab,
    required this.recentFoods,
    required this.staffNotes,
    required this.appointments,
  });
}