// lib/features/analytics/domain/population_kpi_rules.dart

import '../../overview/data/patient_triage_model.dart';
import '../../triage/domain/triage_rules.dart';

/// ประเภทกลุ่มประชากรคลินิก (Clinical Cohort Types)
enum ClinicalCohortType {
  htOnly,
  dmOnly,
  htWithDm,
  highCvRisk,
  all,
}

class PopulationKpiSummary {
  final int totalPatients;
  final int controlledBpCount;
  final int criticalBpCount;
  final int overTreatmentCount;
  final int lostToFollowUpCount;
  final double bpControlRate;
  final double criticalBpRate;
  final double overTreatmentRate;
  final double lostToFollowUpRate;

  // Cohort Counts
  final int htOnlyCount;
  final int dmOnlyCount;
  final int htWithDmCount;
  final int highCvRiskCount;

  PopulationKpiSummary({
    required this.totalPatients,
    required this.controlledBpCount,
    required this.criticalBpCount,
    required this.overTreatmentCount,
    required this.lostToFollowUpCount,
    required this.bpControlRate,
    required this.criticalBpRate,
    required this.overTreatmentRate,
    required this.lostToFollowUpRate,
    required this.htOnlyCount,
    required this.dmOnlyCount,
    required this.htWithDmCount,
    required this.highCvRiskCount,
  });
}

class PopulationKpiRules {
  /// ตรวจสอบการเป็นโรคความดันโลหิตสูง
  static bool hasHypertension(PatientTriageModel p) {
    final diseases = p.underlyingDiseases?.toLowerCase() ?? '';
    final hasDiseaseText = diseases.contains('ht') ||
        diseases.contains('hypertension') ||
        diseases.contains('ความดัน');
    final hasHighBp = (p.systolic ?? 0) >= 140 || (p.diastolic ?? 0) >= 90;
    // ใช้ p.hasMedication เท่านั้น ห้ามอ้างอิง medCount
    return hasDiseaseText || hasHighBp || p.hasMedication;
  }

  /// ตรวจสอบการเป็นโรคเบาหวาน
  static bool hasDiabetes(PatientTriageModel p) {
    final diseases = p.underlyingDiseases?.toLowerCase() ?? '';
    return diseases.contains('dm') ||
        diseases.contains('diabetes') ||
        diseases.contains('เบาหวาน');
  }

  /// ตรวจสอบความเสี่ยงโรคหลอดเลือดหัวใจและสมองสูง (High CVD Risk)
  static bool hasHighCvRisk(PatientTriageModel p) {
    final diseases = p.underlyingDiseases?.toLowerCase() ?? '';
    final hasCvdHistory = diseases.contains('cvd') ||
        diseases.contains('stroke') ||
        diseases.contains('mi') ||
        diseases.contains('cad') ||
        diseases.contains('หัวใจ') ||
        diseases.contains('อัมพฤกษ์') ||
        diseases.contains('อัมพาต');
    final isCrisis = (p.systolic ?? 0) >= 180 || (p.diastolic ?? 0) >= 110;
    return hasCvdHistory || isCrisis;
  }

  /// กรองผู้ป่วยตามกลุ่มประชากร (Cohort Filter for Interactive Drill-down)
  static List<PatientTriageModel> filterPatientsByCohort(
    List<PatientTriageModel> patients,
    ClinicalCohortType cohort,
  ) {
    switch (cohort) {
      case ClinicalCohortType.htOnly:
        return patients.where((p) => hasHypertension(p) && !hasDiabetes(p)).toList();
      case ClinicalCohortType.dmOnly:
        return patients.where((p) => hasDiabetes(p) && !hasHypertension(p)).toList();
      case ClinicalCohortType.htWithDm:
        return patients.where((p) => hasHypertension(p) && hasDiabetes(p)).toList();
      case ClinicalCohortType.highCvRisk:
        return patients.where((p) => hasHighCvRisk(p)).toList();
      case ClinicalCohortType.all:
        return List.from(patients);
    }
  }

  /// ประมวลผลภาพรวมตัวชี้วัดคุณภาพคลินิก
  static PopulationKpiSummary computeQualityKpis(List<PatientTriageModel> patients) {
    final int total = patients.length;
    if (total == 0) {
      return PopulationKpiSummary(
        totalPatients: 0,
        controlledBpCount: 0,
        criticalBpCount: 0,
        overTreatmentCount: 0,
        lostToFollowUpCount: 0,
        bpControlRate: 0.0,
        criticalBpRate: 0.0,
        overTreatmentRate: 0.0,
        lostToFollowUpRate: 0.0,
        htOnlyCount: 0,
        dmOnlyCount: 0,
        htWithDmCount: 0,
        highCvRiskCount: 0,
      );
    }

    int controlled = 0;
    int critical = 0;
    int overTx = 0;
    int lostToFollowUp = 0;

    int htOnly = 0;
    int dmOnly = 0;
    int htDm = 0;
    int highCv = 0;

    for (final p in patients) {
      final sbp = p.systolic ?? 0;
      final dbp = p.diastolic ?? 0;
      // ใช้ p.hasMedication เท่านั้น
      final category = TriageRules.evaluateTriage(
        systolic: sbp,
        diastolic: dbp,
        triageStatus: p.triageStatus,
        hasMeds: p.hasMedication,
      );

      if (category == TriageCategory.normal && sbp > 0) {
        controlled++;
      } else if (category == TriageCategory.critical) {
        critical++;
      } else if (category == TriageCategory.overTreatment) {
        overTx++;
      }

      if (p.lastBpDate != null && TriageRules.isLostToFollowUp(p.lastBpDate)) {
        lostToFollowUp++;
      }

      final isHt = hasHypertension(p);
      final isDm = hasDiabetes(p);

      if (isHt && !isDm) htOnly++;
      if (isDm && !isHt) dmOnly++;
      if (isHt && isDm) htDm++;
      if (hasHighCvRisk(p)) highCv++;
    }

    return PopulationKpiSummary(
      totalPatients: total,
      controlledBpCount: controlled,
      criticalBpCount: critical,
      overTreatmentCount: overTx,
      lostToFollowUpCount: lostToFollowUp,
      bpControlRate: (controlled / total) * 100.0,
      criticalBpRate: (critical / total) * 100.0,
      overTreatmentRate: (overTx / total) * 100.0,
      lostToFollowUpRate: (lostToFollowUp / total) * 100.0,
      htOnlyCount: htOnly,
      dmOnlyCount: dmOnly,
      htWithDmCount: htDm,
      highCvRiskCount: highCv,
    );
  }
}