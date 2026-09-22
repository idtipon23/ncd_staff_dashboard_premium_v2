class PatientTriageModel {
  final String patientId;
  final String? hn;
  final String fullName;
  final int? age;
  final String? gender;
  final String? underlyingDiseases;
  final String? phone;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final String? urgencyLevel;
  final DateTime? lastBpDate;
  final double? fbs;
  final double? hba1c;
  final double? egfr;
  final bool hasMedication;
  final int activeAlertsCount;
  final String triageStatus;

  PatientTriageModel({
    required this.patientId,
    this.hn,
    required this.fullName,
    this.age,
    this.gender,
    this.underlyingDiseases,
    this.phone,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.urgencyLevel,
    this.lastBpDate,
    this.fbs,
    this.hba1c,
    this.egfr,
    required this.hasMedication,
    required this.activeAlertsCount,
    required this.triageStatus,
  });

  factory PatientTriageModel.fromMap(Map<String, dynamic> map) {
    return PatientTriageModel(
      patientId: map['patient_id'] as String,
      hn: map['hn'] as String?,
      fullName: map['full_name'] as String? ?? 'ไม่ระบุชื่อ',
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      underlyingDiseases: map['underlying_diseases'] as String?,
      phone: map['phone'] as String?,
      systolic: map['systolic'] as int?,
      diastolic: map['diastolic'] as int?,
      pulse: map['pulse'] as int?,
      urgencyLevel: map['urgency_level'] as String?,
      lastBpDate: map['last_bp_date'] != null
          ? DateTime.tryParse(map['last_bp_date'] as String)
          : null,
      fbs: map['fasting_blood_sugar'] != null
          ? double.tryParse(map['fasting_blood_sugar'].toString())
          : null,
      hba1c: map['hba1c'] != null ? double.tryParse(map['hba1c'].toString()) : null,
      egfr: map['egfr'] != null ? double.tryParse(map['egfr'].toString()) : null,
      hasMedication: map['has_medication'] == true,
      activeAlertsCount: (map['active_alerts_count'] as int?) ?? 0,
      triageStatus: map['triage_status'] as String? ?? 'NORMAL',
    );
  }
}