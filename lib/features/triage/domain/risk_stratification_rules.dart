// lib/features/triage/domain/risk_stratification_rules.dart

enum ClinicalRiskLevel { high, moderate, low }

class PatientRiskAssessment {
  final ClinicalRiskLevel level;
  final int riskScore; // 0 - 100
  final List<String> primaryReasons;
  final String clinicalRecommendation;

  PatientRiskAssessment({
    required this.level,
    required this.riskScore,
    required this.primaryReasons,
    required this.clinicalRecommendation,
  });
}

class RiskStratificationRules {
  /// ประเมินระดับความเสี่ยงพหุมิติ (Multi-factor Risk Stratification) พร้อมเหตุผลประกอบ
  static PatientRiskAssessment evaluate({
    required Map<String, dynamic> patient,
    required List<Map<String, dynamic>> vitals,
    required Map<String, dynamic>? latestLab,
    required List<Map<String, dynamic>> appointments,
  }) {
    int score = 10; // Baseline
    final List<String> reasons = [];

    // 1. มิติสัญญาณชีพและความผันผวนของความดัน (Vital Signs & BP Trend)
    if (vitals.isNotEmpty) {
      final latest = vitals.first;
      final sys = (latest['systolic'] as num?)?.toInt() ?? 0;
      final dia = (latest['diastolic'] as num?)?.toInt() ?? 0;

      if (sys >= 180 || dia >= 110) {
        score += 40;
        reasons.add('ความดันโลหิตล่าสุดอยู่ในระดับวิกฤต (SBP ≥ 180 หรือ DBP ≥ 110 mmHg)');
      } else if (sys >= 160 || dia >= 100) {
        score += 25;
        reasons.add('ความดันโลหิตอยู่ในระดับสูงรุนแรง (Stage 2 Hypertension)');
      } else if (sys >= 140 || dia >= 90) {
        score += 15;
        reasons.add('ระดับความดันยังไม่บรรลุเป้าหมายการควบคุม (< 140/90 mmHg)');
      }

      // ตรวจสอบความดันเฉียบพลันต่ำ / เสี่ยง Over-treatment
      if ((sys > 0 && sys < 100) || (dia > 0 && dia < 60)) {
        score += 25;
        reasons.add('ตรวจพบภาวะความดันตกเฉียบพลัน เสี่ยงต่อภาวะหน้ามืดหกล้ม (Over-treatment Risk)');
      }

      // ตรวจสอบประวัติความดันสูงซ้ำซาก (Repeated High BP)
      int highBpCount = 0;
      for (final v in vitals.take(5)) {
        final s = (v['systolic'] as num?)?.toInt() ?? 0;
        if (s >= 140) highBpCount++;
      }
      if (highBpCount >= 3) {
        score += 15;
        reasons.add('ความดันโลหิตสูงต่อเนื่องอย่างน้อย 3 ครั้งในประวัติบันทึกล่าสุด');
      }
    } else {
      reasons.add('ยังไม่มีประวัติการบันทึกสัญญาณชีพเพื่อติดตามอาการ');
    }

    // 2. มิติผลการตรวจทางห้องปฏิบัติการ (Laboratory Abnormalities)
    if (latestLab != null) {
      final egfr = (latestLab['egfr'] as num?)?.toDouble() ?? 0.0;
      final k = (latestLab['potassium'] as num?)?.toDouble() ?? 0.0;
      final fbs = (latestLab['fasting_blood_sugar'] as num?)?.toDouble() ?? 0.0;
      final hba1c = (latestLab['hba1c'] as num?)?.toDouble() ?? 0.0;

      if (egfr > 0 && egfr < 45) {
        score += 25;
        reasons.add('การทำงานของไตลดลงรุนแรง (eGFR < 45 ml/min/1.73m² - CKD Stage 3b-5)');
      } else if (egfr >= 45 && egfr < 60) {
        score += 15;
        reasons.add('การทำงานของไตเสื่อมระดับปานกลาง (eGFR < 60 ml/min/1.73m²)');
      }

      if (k >= 5.2) {
        score += 20;
        reasons.add('ภาวะโพแทสเซียมในเลือดสูง (K+ ≥ 5.2 mEq/L) เสี่ยงต่อการใช้ยา ACEI/ARB');
      } else if (k > 0 && k < 3.5) {
        score += 15;
        reasons.add('ภาวะโพแทสเซียมในเลือดต่ำ (K+ < 3.5 mEq/L)');
      }

      if (hba1c >= 8.5 || fbs >= 200) {
        score += 20;
        reasons.add('ระดับน้ำตาลสะสมควบคุมไม่ได้ระดับวิกฤต (HbA1c ≥ 8.5% หรือ FBS ≥ 200 mg/dL)');
      }
    } else {
      reasons.add('ขาดผลการตรวจเลือดติดตามการทำงานของไตและน้ำตาล (Baseline Labs Missing)');
    }

    // 3. มิติโรคร่วมสำคัญ (Compelling Co-morbidities)
    final underlying = (patient['underlying_diseases'] ?? '').toString().toLowerCase();
    final bool hasCvd = underlying.contains('หัวใจ') || underlying.contains('หลอดเลือด') || patient['has_cvd'] == true;
    final bool hasDm = underlying.contains('เบาหวาน') || underlying.contains('dm');

    if (hasCvd) {
      score += 20;
      reasons.add('มีประวัติโรคหลอดเลือดหัวใจหรือหลอดเลือดสมอง (Established CVD)');
    }
    if (hasDm) {
      score += 10;
      reasons.add('มีภาวะเบาหวานร่วม (Diabetes Mellitus)');
    }

    // 4. มิติความต่อเนื่องของการรักษา (Continuity & Follow-up Adherence)
    bool hasFutureAppt = false;
    final now = DateTime.now();
    for (final a in appointments) {
      final apptDate = DateTime.tryParse(a['appointment_date']?.toString() ?? '');
      if (apptDate != null && apptDate.isAfter(now)) {
        hasFutureAppt = true;
        break;
      }
    }
    if (!hasFutureAppt) {
      score += 10;
      reasons.add('ไม่มีการนัดหมายติดตามอาการในระบบ');
    }

    // กำหนดเกณฑ์จำแนกชั้นความเสี่ยง
    score = score.clamp(0, 100);

    ClinicalRiskLevel level;
    String recommendation;

    if (score >= 60) {
      level = ClinicalRiskLevel.high;
      recommendation = 'ผู้ป่วยกลุ่มเสี่ยงสูง: ต้องได้รับการทบทวนแผนการรักษา นัดตรวจซ้ำใน 1-2 สัปดาห์ หรือปรึกษาแพทย์เฉพาะทาง';
    } else if (score >= 35) {
      level = ClinicalRiskLevel.moderate;
      recommendation = 'ผู้ป่วยกลุ่มเสี่ยงปานกลาง: ติดตามการวัดความดันที่บ้าน (HBPM) และทบทวนการปรับเปลี่ยนพฤติกรรม';
    } else {
      level = ClinicalRiskLevel.low;
      recommendation = 'ผู้ป่วยกลุ่มควบคุมได้ดี: นัดหมายติดตามอาการตามรอบมาตรฐานทุก 3-6 เดือน';
    }

    return PatientRiskAssessment(
      level: level,
      riskScore: score,
      primaryReasons: reasons,
      clinicalRecommendation: recommendation,
    );
  }
}