// lib/features/analytics/domain/data_quality_rules.dart

import '../../overview/data/patient_triage_model.dart';

enum DataQualitySeverity {
  critical(label: 'ข้อมูลผิดพลาดรุนแรง', code: 'CRITICAL'),
  warning(label: 'ข้อมูลไม่สมบูรณ์', code: 'WARNING'),
  info(label: 'ควรตรวจสอบเพิ่มเติม', code: 'INFO');

  final String label;
  final String code;
  const DataQualitySeverity({required this.label, required this.code});
}

class PatientDataQualityIssue {
  final PatientTriageModel patient;
  final List<String> issues;
  final DataQualitySeverity severity;

  PatientDataQualityIssue({
    required this.patient,
    required this.issues,
    required this.severity,
  });
}

class DataQualitySummary {
  final int totalPatientsAudited;
  final int totalIssuesFound;
  final int missingHnCount;
  final int invalidVitalsCount;
  final int missingPhoneCount;
  final int missingBaselineBpCount;
  final List<PatientDataQualityIssue> issueItems;

  DataQualitySummary({
    required this.totalPatientsAudited,
    required this.totalIssuesFound,
    required this.missingHnCount,
    required this.invalidVitalsCount,
    required this.missingPhoneCount,
    required this.missingBaselineBpCount,
    required this.issueItems,
  });

  double get dataCompletenessRate {
    if (totalPatientsAudited == 0) return 100.0;
    final cleanPatients = totalPatientsAudited - issueItems.length;
    return (cleanPatients / totalPatientsAudited) * 100.0;
  }
}

class DataQualityRules {
  /// ตรวจสอบความถูกต้องและความสมบูรณ์ของข้อมูลผู้ป่วยทั้งคลินิก (Protocol ข้อ 18)
  static DataQualitySummary auditDataQuality(List<PatientTriageModel> patients) {
    final List<PatientDataQualityIssue> issueList = [];

    int missingHn = 0;
    int invalidVitals = 0;
    int missingPhone = 0;
    int missingBaselineBp = 0;

    for (final p in patients) {
      final List<String> patientIssues = [];
      DataQualitySeverity highestSeverity = DataQualitySeverity.info;

      // 1. ตรวจสอบเลข HN
      if (p.hn == null || p.hn!.trim().isEmpty || p.hn == '-') {
        patientIssues.add('ไม่มีเลขประจำตัวผู้ป่วย (Missing HN)');
        missingHn++;
        highestSeverity = DataQualitySeverity.critical;
      }

      // 2. ตรวจสอบเบอร์โทรศัพท์ติดต่อ
      if (p.phone == null || p.phone!.trim().isEmpty || p.phone == '-') {
        patientIssues.add('ไม่มีเบอร์โทรศัพท์สำหรับติดต่อติดตาม (Missing Phone)');
        missingPhone++;
        if (highestSeverity != DataQualitySeverity.critical) {
          highestSeverity = DataQualitySeverity.warning;
        }
      }

      // 3. ตรวจสอบข้อมูลสัญญาณชีพที่ผิดปกติทางสรีรวิทยา (Out of physiological range)
      final sbp = p.systolic;
      final dbp = p.diastolic;
      final pulse = p.pulse;

      if (sbp != null || dbp != null) {
        if (sbp != null && (sbp < 50 || sbp > 260)) {
          patientIssues.add('ค่า SYS ($sbp mmHg) ผิดปกติวิกฤต/เกินช่วงสรีรวิทยา');
          invalidVitals++;
          highestSeverity = DataQualitySeverity.critical;
        }
        if (dbp != null && (dbp < 30 || dbp > 160)) {
          patientIssues.add('ค่า DIA ($dbp mmHg) ผิดปกติวิกฤต/เกินช่วงสรีรวิทยา');
          invalidVitals++;
          highestSeverity = DataQualitySeverity.critical;
        }
        if (sbp != null && dbp != null && sbp <= dbp) {
          patientIssues.add('ค่าความดันขัดแย้ง (SYS $sbp ≤ DIA $dbp mmHg)');
          invalidVitals++;
          highestSeverity = DataQualitySeverity.critical;
        }
        if (pulse != null && (pulse < 30 || pulse > 220)) {
          patientIssues.add('ค่าชีพจร ($pulse bpm) ผิดปกติวิกฤต/เกินช่วงสรีรวิทยา');
          invalidVitals++;
          highestSeverity = DataQualitySeverity.critical;
        }
      } else {
        // ไม่มีบันทึกความดันตั้งต้นเลย
        patientIssues.add('ไม่พบบันทึกสัญญาณชีพตั้งต้น (No Baseline Vitals)');
        missingBaselineBp++;
        if (highestSeverity != DataQualitySeverity.critical) {
          highestSeverity = DataQualitySeverity.warning;
        }
      }

      // 4. ตรวจสอบอายุ
      if (p.age == null || p.age! <= 0) {
        patientIssues.add('ไม่ได้ระบุอายุผู้ป่วย');
        if (highestSeverity != DataQualitySeverity.critical) {
          highestSeverity = DataQualitySeverity.warning;
        }
      }

      if (patientIssues.isNotEmpty) {
        issueList.add(PatientDataQualityIssue(
          patient: p,
          issues: patientIssues,
          severity: highestSeverity,
        ));
      }
    }

    return DataQualitySummary(
      totalPatientsAudited: patients.length,
      totalIssuesFound: issueList.length,
      missingHnCount: missingHn,
      invalidVitalsCount: invalidVitals,
      missingPhoneCount: missingPhone,
      missingBaselineBpCount: missingBaselineBp,
      issueItems: issueList,
    );
  }
}