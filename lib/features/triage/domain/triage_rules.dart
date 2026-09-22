// lib/features/triage/domain/triage_rules.dart

/// หมวดหมู่การคัดกรองความเสี่ยงทางคลินิก (Clinical Triage Classification)
enum TriageCategory {
  critical,         // วิกฤตความดันโลหิตสูง (Grade 3 HT / Hypertensive Crisis)
  overTreatment,    // ความดันตกจากการรักษา (Hypotension in medicated patient)
  hypotension,      // ความดันต่ำในผู้ป่วยไม่ได้รับยา (Drug-naive hypotension)
  warning,          // เฝ้าระวังความดันสูง (Stage 1-2 HT)
  normal,           // ระดับความดันควบคุมได้ตามเกณฑ์
  insufficientData, // ข้อมูลสัญญาณชีพไม่ครบถ้วน / ยังไม่ได้บันทึก
}

/// การจัดระดับความรุนแรงของวิกฤตความดันโลหิตสูง (Hypertension Crisis Severity)
enum HypertensionCrisisType {
  none,
  grade3Severe,          // BP >= 180/110 mmHg ไม่มี Acute Target-Organ Damage (Urgency)
  hypertensiveEmergency, // BP >= 180/110 mmHg ร่วมกับ Acute Target-Organ Damage
}

/// กฎและตรรกะทางคลินิกตาม Thai Guidelines on the Treatment of Hypertension 2024
class TriageRules {
  /// ตรวจสอบว่าผู้ป่วยมีประวัติได้รับยาลดความดันหรือไม่ (Zero Clinical Assumption)
  static bool isPatientMedicated({
    String? triageStatus,
    bool? hasMedication,
    int? medCount,
    List<dynamic>? currentMedClasses,
  }) {
    if (triageStatus == 'OVER_TREATMENT') return true;
    if (triageStatus == 'HYPOTENSION') return false;

    // ตรวจสอบหลักฐานการใช้ยาที่เป็นรูปธรรมเท่านั้น
    if (hasMedication == true) return true;
    if (medCount != null && medCount > 0) return true;
    if (currentMedClasses != null && currentMedClasses.isNotEmpty) return true;

    // 🔒 Clinical Safety Guard: ห้ามเดาว่าผู้ป่วยได้รับยาหากไม่มีหลักฐานยืนยัน
    return false;
  }

  /// ตรวจสอบว่า DBP < 70 mmHg ต่อเนื่องอย่างน้อย 3 บันทึกล่าสุดหรือไม่ (J-Curve Risk)
  static bool checkPersistentLowDbp(List<Map<String, dynamic>> vitals) {
    if (vitals.length < 3) return false;
    int lowCount = 0;
    for (int i = 0; i < 3 && i < vitals.length; i++) {
      final dia = (vitals[i]['diastolic'] as num?)?.toInt() ?? 0;
      if (dia > 0 && dia < 70) {
        lowCount++;
      }
    }
    return lowCount >= 3;
  }

  /// ตรวจสอบภาวะขาดการติดต่อ (Lost to Follow-up) เกณฑ์มาตรฐาน 30 วัน
  static bool isLostToFollowUp(DateTime? lastBpDate, {int thresholdDays = 30}) {
    if (lastBpDate == null) return false;
    return DateTime.now().difference(lastBpDate).inDays > thresholdDays;
  }

  /// จำแนกภาวะ Hypertensive Urgency vs Emergency ตามบริบททางคลินิก
  static HypertensionCrisisType classifySevereHypertension({
    required int systolic,
    required int diastolic,
    bool hasAcuteTargetOrganDamage = false,
  }) {
    if (systolic < 180 && diastolic < 110) {
      return HypertensionCrisisType.none;
    }
    if (hasAcuteTargetOrganDamage) {
      return HypertensionCrisisType.hypertensiveEmergency;
    }
    return HypertensionCrisisType.grade3Severe;
  }

  /// ฟังก์ชันประเมินระดับ Triage ของผู้ป่วยรายบุคคล
  static TriageCategory evaluateTriage({
    required int systolic,
    required int diastolic,
    required String? triageStatus,
    required bool hasMeds,
  }) {
    // 1. 🔒 Clinical Safety Guard: ป้องกัน False Normal กรณีข้อมูลสัญญาณชีพไม่ครบ
    if (systolic <= 0 || diastolic <= 0) {
      if (triageStatus == 'OVER_TREATMENT') return TriageCategory.overTreatment;
      if (triageStatus == 'CRITICAL') return TriageCategory.critical;
      if (triageStatus == 'WARNING') return TriageCategory.warning;
      return TriageCategory.insufficientData;
    }

    // 2. ตรวจสอบสถานะ Over-treatment จากระบบหลังบ้าน
    if (triageStatus == 'OVER_TREATMENT') {
      return TriageCategory.overTreatment;
    }

    // 3. ตรวจจับภาวะความดันต่ำ (SBP < 100 หรือ DBP < 60)
    final bool isLowBp = systolic < 100 || diastolic < 60;
    if (isLowBp || triageStatus == 'HYPOTENSION') {
      return hasMeds ? TriageCategory.overTreatment : TriageCategory.hypotension;
    }

    // 4. ความดันโลหิตสูงระดับรุนแรง (Grade 3 HT / Urgency / Crisis)
    if (systolic >= 180 || diastolic >= 110 || triageStatus == 'CRITICAL') {
      return TriageCategory.critical;
    }

    // 5. เฝ้าระวังความดันสูง (Stage 1-2 HT: SBP 140-179 หรือ DBP 90-109)
    if (systolic >= 140 || diastolic >= 90 || triageStatus == 'WARNING') {
      return TriageCategory.warning;
    }

    // 6. ควบคุมความดันได้ตามเกณฑ์ (SBP 100-139 และ DBP 60-89)
    return TriageCategory.normal;
  }
}