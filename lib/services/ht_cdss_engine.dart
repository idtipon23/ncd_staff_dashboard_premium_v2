// lib/services/ht_cdss_engine.dart

class HtPatientData {
  final int age;
  final String sex;
  final int officeSbp;
  final int officeDbp;
  final int? homeSbp;
  final int? homeDbp;
  final int heartRate;
  final bool hasCvd;
  final bool hasDm;
  final double cvRiskScore;
  final bool hasHmod;

  // 🔒 Clinical Safety: รองรับค่าว่าง (Null) เพื่อกำจัดการ Mock หรือสมมุติตัวเลขแล็บ
  final double? egfr;
  final double? potassium;
  final double? serumSodium;
  final double? serumUricAcid;
  final double? baselineCreatinine;
  final double? currentCreatinine;

  final bool isFrail;
  final bool hasHighNocturnalBp;
  final int medCount;
  final List<String> currentMedClasses;
  final bool isMaxToleratedDose;
  final String setting;
  final bool historyHighBp;
  final int visitCount;
  final bool hasPersistentLowDbp;

  // อาการแสดงทางคลินิกและโรคร่วมตาม Thai HT Guidelines 2024
  final bool hasCad;
  final bool hasHeartFailure;
  final bool hasProteinuria;
  final bool hasGout;
  final bool isPregnant;
  final bool hasSleepApnea;
  final bool hasClassicPheoTriad;

  // 🔒 Clinical Safety Guard: แยก Urgency ออกจาก Emergency อย่างแท้จริง
  final bool hasAcuteTargetOrganDamage;

  HtPatientData({
    required this.age,
    required this.sex,
    required this.officeSbp,
    required this.officeDbp,
    this.homeSbp,
    this.homeDbp,
    required this.heartRate,
    required this.hasCvd,
    required this.hasDm,
    required this.cvRiskScore,
    required this.hasHmod,
    this.egfr,
    this.potassium,
    this.serumSodium,
    this.serumUricAcid,
    this.baselineCreatinine,
    this.currentCreatinine,
    required this.isFrail,
    required this.hasHighNocturnalBp,
    required this.medCount,
    required this.currentMedClasses,
    this.isMaxToleratedDose = false,
    this.setting = 'Out-patient',
    this.historyHighBp = false,
    this.visitCount = 1,
    this.hasPersistentLowDbp = false,
    this.hasCad = false,
    this.hasHeartFailure = false,
    this.hasProteinuria = false,
    this.hasGout = false,
    this.isPregnant = false,
    this.hasSleepApnea = false,
    this.hasClassicPheoTriad = false,
    this.hasAcuteTargetOrganDamage = false,
  });
}

class ClinicalRecommendationResult {
  final String diagnosisEvaluation;
  final String bpTargetOffice;
  final String bpTargetHome;
  final List<String> medicationChoices;
  final List<String> safetyAlerts;
  final List<String> secondaryHtWorkupAlerts;
  final List<String> lifestyleAndMonitoringChoices;
  final String defaultDosingTimeAdvice;

  // 🔒 หมวดหมู่การแจ้งเตือนผลแล็บที่ขาดหายโดยเฉพาะ
  final List<String> missingLabAlerts;

  ClinicalRecommendationResult({
    required this.diagnosisEvaluation,
    required this.bpTargetOffice,
    required this.bpTargetHome,
    required this.medicationChoices,
    required this.safetyAlerts,
    required this.secondaryHtWorkupAlerts,
    required this.lifestyleAndMonitoringChoices,
    required this.defaultDosingTimeAdvice,
    this.missingLabAlerts = const [],
  });
}

class HtCdssEngine {
  static ClinicalRecommendationResult evaluate(HtPatientData data) {
    final int sbp = data.officeSbp;
    final int dbp = data.officeDbp;
    final bool hasMeds = data.medCount > 0 || data.currentMedClasses.isNotEmpty;

    List<String> safetyAlerts = [];
    List<String> secondaryWorkup = [];
    List<String> medChoices = [];
    List<String> missingLabAlerts = [];

    // -------------------------------------------------------------
    // 🔒 P0 GUARD: ข้อมูลสัญญาณชีพไม่ครบถ้วน (Zero/Missing Vitals)
    // -------------------------------------------------------------
    if (sbp <= 0 || dbp <= 0) {
      return ClinicalRecommendationResult(
        diagnosisEvaluation: "INSUFFICIENT DATA / ข้อมูลสัญญาณชีพไม่เพียงพอ",
        bpTargetOffice: "ไม่สามารถกำหนดเป้าหมายได้ (ขาดข้อมูลความดัน)",
        bpTargetHome: "ไม่สามารถกำหนดเป้าหมายได้",
        medicationChoices: [
          "⛔ ระงับการประเมินแผนการรักษาทางยา: ต้องวัดและบันทึกระดับความดันโลหิต (SBP/DBP) ก่อนทำการวิเคราะห์",
        ],
        safetyAlerts: [
          "⚠️ ข้อมูลทางคลินิกไม่สมบูรณ์: ไม่พบค่าความดันโลหิตที่เป็นบวก (> 0 mmHg)",
        ],
        secondaryHtWorkupAlerts: [],
        lifestyleAndMonitoringChoices: [
          "วัดความดันโลหิตซ้ำในท่านั่งพักอย่างน้อย 5 นาทีด้วยเครื่องวัดมาตรฐาน",
        ],
        defaultDosingTimeAdvice: "รอผลการวัดความดันโลหิตก่อนให้คำแนะนำ",
        missingLabAlerts: [
          "ไม่พบข้อมูลความดันโลหิตล่าสุด",
        ],
      );
    }

    // -------------------------------------------------------------
    // ตรวจสอบความสมบูรณ์ของผลตรวจทางห้องปฏิบัติการ (Lab Data Completeness)
    // -------------------------------------------------------------
    final bool hasEgfr = data.egfr != null && data.egfr! > 0;
    final bool hasPotassium = data.potassium != null && data.potassium! > 0;
    final bool hasSodium = data.serumSodium != null && data.serumSodium! > 0;
    final bool hasUricAcid = data.serumUricAcid != null && data.serumUricAcid! > 0;
    final bool hasCreatinine = data.currentCreatinine != null && data.currentCreatinine! > 0;

    if (!hasEgfr) {
      missingLabAlerts.add("ขาดผลตรวจ eGFR: ไม่สามารถประเมินระยะการทำงานของไตและการปรับขนาดยาขับปัสสาวะ/MRA ได้อย่างแม่นยำ");
      safetyAlerts.add("ℹ️ ไม่พบผลตรวจ eGFR ล่าสุด: ควรส่งตรวจประเมินการทำงานของไตก่อนปรับขนาดยา");
    }
    if (!hasPotassium) {
      missingLabAlerts.add("ขาดผลตรวจ Serum Potassium (K+): ห้ามเริ่ม Spironolactone หรือเพิ่มยา RAS Blocker ขนาดสูงจนกว่าจะตรวจยืนยัน");
      safetyAlerts.add("ℹ️ ไม่พบผลตรวจ Serum K+: ควรตรวจระดับเกลือแร่ในเลือดเพื่อความปลอดภัย");
    }
    if (!hasCreatinine) {
      missingLabAlerts.add("ขาดผลตรวจ Serum Creatinine: ขาดค่าตั้งต้นสำหรับประเมินภาวะไตขาดเลือดเฉียบพลัน");
    }

    // -------------------------------------------------------------
    // มิติที่ 1: สตรีตั้งครรภ์ (Pregnancy Gatekeeper)
    // -------------------------------------------------------------
    if (data.isPregnant) {
      safetyAlerts.add("⛔ ข้อห้ามเด็ดขาดระดับสูงสุด: ห้ามใช้ยาในกลุ่ม ACEI, ARB, ARNI และ Spironolactone ในสตรีมีครรภ์ (อันตรายร้ายแรงต่อทารกในครรภ์)");
      if (data.currentMedClasses.contains("ACEI") ||
          data.currentMedClasses.contains("ARB") ||
          data.currentMedClasses.contains("Spironolactone")) {
        safetyAlerts.add("🚨 ตรวจพบการใช้ยาต้องห้ามในหญิงตั้งครรภ์! กรุณาหยุดยากลุ่ม RAS Blockers / MRA ทันที และส่งต่อสูตินรีแพทย์");
      }

      medChoices.add("ทางเลือก 1 (แนะนำตาม Guideline): Labetalol รับประทาน (เริ่ม 100-200 mg วันละ 2 ครั้ง)");
      medChoices.add("ทางเลือก 2: Nifedipine ชนิดออกฤทธิ์ยาว (Extended-release) 20-60 mg/วัน");
      medChoices.add("ทางเลือก 3: Methyldopa 250-500 mg วันละ 2-3 ครั้ง");
      medChoices.add("ทางเลือก 4: ส่งตัวพบสูตินรีแพทย์เพื่อประเมินภาวะ Preeclampsia (ครรภ์เป็นพิษ) ทันที");

      return ClinicalRecommendationResult(
        diagnosisEvaluation: "ภาวะความดันโลหิตสูงในสตรีมีครรภ์ (Hypertension in Pregnancy)",
        bpTargetOffice: "130–135 / 80–85 mmHg (หลีกเลี่ยง DBP < 80 mmHg)",
        bpTargetHome: "เฝ้าระวังอาการปวดศีรษะ ตาพร่ามัว จุกแน่นใต้ลิ้นปี่",
        medicationChoices: medChoices,
        safetyAlerts: safetyAlerts,
        secondaryHtWorkupAlerts: ["ตรวจโปรตีนในปัสสาวะ (Urine dipstick / Proteinuria) เพื่อคัดกรอง Preeclampsia"],
        lifestyleAndMonitoringChoices: ["พักผ่อนให้เพียงพอ", "งดกิจกรรมหนัก", "วัดความดันสม่ำเสมอวันละ 2 รอบ"],
        defaultDosingTimeAdvice: "รับประทานยาตามเวลาที่แพทย์สั่งอย่างเคร่งครัด",
        missingLabAlerts: missingLabAlerts,
      );
    }

    // -------------------------------------------------------------
    // มิติที่ 2: การตรวจสอบความปลอดภัยของหัวใจและเกลือแร่ (Safety & HR Rules)
    // -------------------------------------------------------------
    if (data.currentMedClasses.contains("ACEI") && data.currentMedClasses.contains("ARB")) {
      safetyAlerts.add("⛔ ข้อห้ามเด็ดขาด: พบการใช้ยาคู่ ACEI + ARB พร้อมกัน กรุณาหยุดตัวใดตัวหนึ่งทันที");
    }

    if (data.heartRate > 0 && data.heartRate < 55) {
      safetyAlerts.add("⛔ ข้อห้าม: ชีพจรต่ำกว่า 55 bpm (Bradycardia: ${data.heartRate} bpm) ห้ามเริ่มหรือเพิ่มขนาดยา Beta-blocker และ Non-DHP CCB (Verapamil, Diltiazem)");
    }

    if (hasPotassium) {
      if (data.potassium! >= 5.5) {
        safetyAlerts.add("🚨 วิกฤต Hyperkalemia (K+ = ${data.potassium} mEq/L): ต้องหยุดยา Spironolactone ทันที และหยุด/ลดขนาดยา ACEI หรือ ARB พร้อมตรวจ EKG");
      } else if (data.potassium! > 5.0) {
        safetyAlerts.add("⚠️ เฝ้าระวัง Hyperkalemia (K+ = ${data.potassium} mEq/L): ระงับการปรับเพิ่มขนาดยา ACEI/ARB/Spironolactone และตรวจเลือดซ้ำใน 1 สัปดาห์");
      }
    }

    if (data.baselineCreatinine != null &&
        data.currentCreatinine != null &&
        data.baselineCreatinine! > 0 &&
        data.currentCreatinine! > 0) {
      final double risePercent =
          ((data.currentCreatinine! - data.baselineCreatinine!) / data.baselineCreatinine!) * 100.0;
      if (risePercent > 30.0) {
        safetyAlerts.add("⚠️ ตรวจพบ Creatinine เพิ่มขึ้น ${risePercent.toStringAsFixed(1)}% (> 30% จากค่าเดิม): สงสัยภาวะ Renal Artery Stenosis หรือไตขาดเลือด ให้ปรับลดยาหรือหยุด RAS Blocker ชั่วคราว");
      }
    }

    if (hasEgfr && data.egfr! < 30 && data.currentMedClasses.contains("Spironolactone")) {
      safetyAlerts.add("⛔ ข้อห้าม: ห้ามใช้ Spironolactone เมื่อ eGFR < 30 ml/min หรือ K+ > 4.5 mEq/L");
    }

    if (hasSodium && data.serumSodium! < 130) {
      safetyAlerts.add("⚠️ ภาวะ Hyponatremia (Na+ = ${data.serumSodium} mEq/L): ระวังการใช้ยาขับปัสสาวะ Thiazide โดยเฉพาะในผู้สูงอายุ");
    }

    if (data.hasGout || (hasUricAcid && data.serumUricAcid! >= 8.5)) {
      safetyAlerts.add("⚠️ ผู้ป่วยมีประวัติโรคเกาต์/กรดยูริกสูง: หลีกเลี่ยงยาขับปัสสาวะกลุ่ม Thiazide/Thiazide-like เพราะขัดขวางการขับกรดยูริก แนะนำเลือกใช้ CCB หรือ Losartan");
    }

    // -------------------------------------------------------------
    // มิติที่ 3: ตรวจจับสัญญาณเตือนความดันโลหิตสูงทุติยภูมิ (Secondary HT Workup)
    // -------------------------------------------------------------
    if (data.age < 30 && (sbp >= 140 || dbp >= 90)) {
      secondaryWorkup.add("• ผู้ป่วยอายุน้อยกว่า 30 ปีที่ตรวจพบความดันสูง: ควรส่งตรวจคัดกรอง Secondary HT (Renal duplex ultrasound, ตรวจปัสสาวะ, และคัดกรองฮอร์โมนต่อมหมวกไต)");
    }
    if (data.age > 65 && data.visitCount <= 2 && sbp >= 160) {
      secondaryWorkup.add("• เพิ่งเริ่มมีความดันสูงรุนแรงในวัยสูงอายุ (> 65 ปี): ควรตรวจประเมิน Atherosclerotic Renal Artery Stenosis");
    }
    if (hasPotassium && data.potassium! < 3.5) {
      bool onDiuretic = data.currentMedClasses.any((m) =>
          m.contains('Diuretic') || m.contains('Thiazide') || m.contains('Loop'));
      if (!onDiuretic) {
        secondaryWorkup.add("• ตรวจพบโพแทสเซียมต่ำ (K+ = ${data.potassium} mEq/L) โดยไม่ได้ทานยาขับปัสสาวะ: สงสัยภาวะ Primary Aldosteronism ควรส่งตรวจ Aldosterone-to-Renin Ratio (ARR)");
      }
    }
    if (data.hasClassicPheoTriad) {
      secondaryWorkup.add("• พบไตรอาการปวดศีรษะ เหงื่อแตก ใจสั่นร่วมกับความดันสูง: สงสัย Pheochromocytoma แนะนำส่งตรวจ Plasma/Urine Metanephrines");
    }
    if (data.hasSleepApnea || (data.isMaxToleratedDose && data.medCount >= 3)) {
      secondaryWorkup.add("• มีประวัตินอนกรน/สงสัย OSA หรือความดันดื้อยา: แนะนำประเมิน Epworth Sleepiness Scale หรือทำ Sleep Test");
    }

    // -------------------------------------------------------------
    // มิติที่ 4: การตรวจจับ Over-treatment และจำแนกระดับความดัน
    // -------------------------------------------------------------
    final bool isHypotension = (sbp > 0 && sbp < 100) || (dbp > 0 && dbp < 60);
    final bool isLowDbp = dbp > 0 && dbp < 70;
    final bool isIsolatedSystolicLowDbp = sbp >= 140 && isLowDbp;
    final bool isOverTreated = hasMeds && (isHypotension || (isLowDbp && sbp < 140) || data.hasPersistentLowDbp);

    final bool isOfficeHigh = sbp >= 140 || dbp >= 90;
    final bool isOfficePreHt = (sbp >= 130 && sbp <= 139) || (dbp >= 80 && dbp <= 89);
    final bool isOfficeOptimal = sbp > 0 && sbp < 120 && dbp > 0 && dbp < 80;
    final bool isOfficeNormal = sbp >= 120 && sbp <= 129 && dbp > 0 && dbp < 80;

    final bool hasHomeData = data.homeSbp != null && data.homeDbp != null && data.homeSbp! > 0 && data.homeDbp! > 0;
    final bool hasHighHomeBp = hasHomeData && (data.homeSbp! >= 135 || data.homeDbp! >= 85);
    final bool hasNormalHomeBp = hasHomeData && (data.homeSbp! < 135 && data.homeDbp! < 85);

    String diagnosis = "ปกติ (Optimal / Normal Blood Pressure)";
    if (isOverTreated) {
      diagnosis = isHypotension
          ? "ภาวะความดันต่ำจากการรักษาเกินขนาด (Hypotension / Over-treatment)"
          : "เฝ้าระวัง Over-treatment: DBP ต่ำกว่า 70 mmHg ขณะได้รับยา";
      if (isHypotension) {
        safetyAlerts.add("🚨 ผู้ป่วยมีความดันโลหิตต่ำกว่าเกณฑ์ (< 100/60 mmHg) ระวังภาวะหน้ามืด วิงเวียน หรือหกล้ม");
      } else if (data.hasPersistentLowDbp) {
        safetyAlerts.add("🚨 แจ้งเตือน Over-treatment: ตรวจพบ DBP < 70 mmHg ต่อเนื่อง 3 วันขึ้นไป ขณะได้รับยา เสี่ยงต่อกล้ามเนื้อหัวใจขาดเลือด (J-Curve)");
      }
    } else if (isIsolatedSystolicLowDbp) {
      diagnosis = "Isolated Systolic HT ร่วมกับ DBP ต่ำ (< 70 mmHg)";
      safetyAlerts.add("⚠️ ข้อควรระวัง: DBP ต่ำกว่า 70 mmHg ขณะที่ SBP ยังสูง ให้ปรับยาด้วยความระมัดระวัง (ห้ามตั้งเป้า DBP < 70)");
    }
    // 🔒 P0: แยก Urgency vs Emergency ตามการประเมิน Acute Target-Organ Damage
    else if (sbp >= 180 || dbp >= 110) {
      if (data.hasAcuteTargetOrganDamage) {
        diagnosis = "Hypertensive Emergency (สงสัยภาวะอวัยวะเป้าหมายถูกทำลายเฉียบพลัน)";
        safetyAlerts.add("🚨 HYPERTENSIVE EMERGENCY: BP ≥ 180/110 mmHg ร่วมกับมีอาการสงสัยอวัยวะเป้าหมายถูกทำลายเฉียบพลัน (เช่น แน่นหน้าอก หอบเหนื่อย อัมพฤกษ์เฉียบพลัน สับสน) ต้องส่งต่อห้องฉุกเฉินทันทีเพื่อพิจารณาให้ยาลดความดันชนิดฉีด");
      } else {
        diagnosis = "Grade 3 Severe Hypertension (Hypertensive Urgency / BP ≥ 180/110 mmHg)";
        safetyAlerts.add("⚠️ GRADE 3 SEVERE HYPERTENSION (URGENCY): ความดันโลหิตสูงระดับรุนแรงโดยไม่มี Acute Target-Organ Damage แนะนำให้พักผ่อน ปรับยาลดความดันชนิดรับประทาน และนัดตรวจติดตามซ้ำใน 24–72 ชั่วโมง (หลีกเลี่ยงการลดความดันเร็วจนเกินไป)");
      }
    } else if (isOfficeHigh && hasNormalHomeBp) {
      diagnosis = "สงสัยภาวะ White-Coat Hypertension (WCH)";
    } else if (isOfficePreHt && hasHighHomeBp) {
      diagnosis = "สงสัยภาวะ Masked Hypertension (MH)";
    } else if (isOfficeHigh && (hasHighHomeBp || data.historyHighBp || data.visitCount > 1)) {
      diagnosis = "Confirmed Hypertension";
    } else if (isOfficeHigh) {
      diagnosis = "Elevated Office BP (แนะนำตรวจยืนยันด้วย HBPM หรือตรวจซ้ำ)";
    } else if (isOfficePreHt) {
      diagnosis = "ความดันโลหิตค่อนข้างสูง (Pre-hypertension)";
    }

    // -------------------------------------------------------------
    // เป้าหมายความดันโลหิต (Target BP)
    // -------------------------------------------------------------
    String officeTarget = "< 130/80 mmHg";
    String homeTarget = "< 125/75 mmHg";
    int targetSbp = 130;
    int targetDbp = 80;

    if (data.isFrail) {
      officeTarget = "Individualized (ตามสภาพความทนทานของผู้ป่วย)";
      homeTarget = "Individualized";
      targetSbp = 140;
      targetDbp = 90;
    } else if (data.age >= 80) {
      officeTarget = "SBP 140–150 / DBP < 80 mmHg (พิจารณา 130–139 หากทนยาได้)";
      homeTarget = "< 140/80 mmHg";
      targetSbp = 150;
      targetDbp = 80;
    } else if (data.age >= 65 && data.age <= 79) {
      if (sbp >= 140 && dbp < 90) {
        officeTarget = "Isolated Systolic HT: SBP 140–150 (ปรับลง 130–139 หากทนยาได้)";
        targetSbp = 150;
      } else {
        officeTarget = "Primary: < 140/90 (ปรับลง < 130/80 หากทนยาได้)";
        targetSbp = 140;
        targetDbp = 90;
      }
      homeTarget = "< 135/85 mmHg";
    }

    // -------------------------------------------------------------
    // มิติที่ 5: Compelling Indications & แผนการรักษาทางยา
    // -------------------------------------------------------------
    // 🔴 1. ภาวะ Over-treatment
    if (isOverTreated) {
      medChoices.add("ทางเลือกที่ 1 (แนะนำเร่งด่วน): ปรับลดขนาดยาลง (Step-down / Down-titration) เช่น ลดขนาดยาลง 50% เพื่อพยุง DBP ให้ ≥ 70 mmHg");
      if (data.medCount >= 2) {
        medChoices.add("ทางเลือกที่ 2 (De-escalation): พิจารณาหยุดยา 1 ชนิดชั่วคราว (เช่น หยุดยาขับปัสสาวะ หรือลด CCB/ACEI)");
      } else {
        medChoices.add("ทางเลือกที่ 2 (De-escalation): พิจารณาหยุดยาชั่วคราวและติดตามความดันซ้ำใน 24-48 ชั่วโมง");
      }
      medChoices.add("ทางเลือกที่ 3: ประเมินภาวะความดันตกในท่ายืน (Orthostatic Hypotension) โดยวัดความดันเปรียบเทียบท่านอนและท่ายืน 3 นาที");
    }
    // 🟡 2. Isolated Systolic HT with Low DBP
    else if (isIsolatedSystolicLowDbp) {
      medChoices.add("ทางเลือกที่ 1 (แนะนำ): ปรับยาด้วยความระมัดระวังเป็นพิเศษเพื่อไม่ให้ DBP ลดต่ำลงไปอีก (ห้ามตั้งเป้าหมาย DBP < 70 หรือ SBP < 120)");
      medChoices.add("ทางเลือกที่ 2: หากจำเป็นต้องลด SBP ให้พิจารณาใช้ยากลุ่มที่ลด Pulse Wave Velocity หรือเริ่มจากขนาดยาต่ำ");
    }
    // 🟢 3. Compelling Indications (มีโรคร่วมบังคับกลุ่มยา)
    else if (data.hasCad) {
      medChoices.add("ทางเลือกที่ 1 (Compelling: โรคหลอดเลือดหัวใจ CAD/Post-MI): สูตรหลักต้องมี Beta-blocker + ACEI/ARB");
      medChoices.add("  • ตัวเลือกเสริม: เพิ่ม DHP-CCB (Amlodipine) ได้หากมีอาการเจ็บหน้าอกหรือความดันยังไม่ถึงเป้า");
    } else if (data.hasHeartFailure) {
      medChoices.add("ทางเลือกที่ 1 (Compelling: ภาวะหัวใจล้มเหลว Heart Failure): แนะนำสูตร 4 เสาหลัก (Quadruple Therapy)");
      medChoices.add("  • สูตรหลัก: ARNI (หรือ ACEI/ARB) + Evidence-based Beta-blocker + Spironolactone (MRA) + SGLT2i");
      safetyAlerts.add("⛔ ข้อห้าม: ผู้ป่วยหัวใจล้มเหลว ห้ามใช้ยา Non-DHP CCB (Verapamil, Diltiazem) เพราะมีฤทธิ์กดการบีบตัวของกล้ามเนื้อหัวใจ");
    } else if (data.hasProteinuria) {
      medChoices.add("ทางเลือกที่ 1 (Compelling: ไตเรื้อรังมีโปรตีนรั่ว CKD with Proteinuria): บังคับเลือก ACEI หรือ ARB เป็นยาตัวแรกเพื่อชะลอการเสื่อมของไต");
      medChoices.add("  • สูตรเสริม: หากยังไม่ถึงเป้าหมาย ให้เพิ่ม CCB หรือ Thiazide-like diuretic (ห้ามจับคู่ ACEI + ARB พร้อมกัน)");
    }
    // 🌿 4. ผู้ป่วยที่ยังไม่ได้รับประทานยา (medCount == 0)
    else if (!hasMeds) {
      if (isOfficeHigh && hasNormalHomeBp) {
        medChoices.add("ทางเลือกที่ 1 (แนะนำตาม Guideline 2024): สงสัย White-Coat HT ยังไม่จำเป็นต้องเริ่มยา ให้ปรับเปลี่ยนพฤติกรรมชีวิต (Lifestyle Modification)");
        medChoices.add("ทางเลือกที่ 2: ตรวจติดตามความดันที่บ้าน (HBPM Protocol) สม่ำเสมอ และนัดประเมินซ้ำทุก 3–6 เดือน");
      } else if (isOfficeOptimal || isOfficeNormal) {
        medChoices.add("ทางเลือกที่ 1 (แนะนำ): ไม่มีความจำเป็นต้องเริ่มยาลดความดันโลหิต (No medication indicated)");
        medChoices.add("ทางเลือกที่ 2: ส่งเสริมพฤติกรรมสุขภาพที่ดี (DASH Diet, ออกกำลังกาย, คุมน้ำหนัก)");
      } else if (isOfficePreHt) {
        if (data.hasCvd || data.hasDm || data.hasHmod || data.cvRiskScore >= 10.0) {
          medChoices.add("ทางเลือกที่ 1 (แนะนำ): ปรับพฤติกรรมเข้มงวด + พิจารณาเริ่มยาเดี่ยว (Monotherapy: ACEI หรือ ARB)");
        } else {
          medChoices.add("ทางเลือกที่ 1 (แนะนำตาม Guideline): ปรับเปลี่ยนพฤติกรรมชีวิตอย่างเข้มงวด (Lifestyle Modification) 3–6 เดือน ยังไม่ต้องเริ่มยา");
        }
      } else if (data.age >= 80 || data.isFrail) {
        medChoices.add("ทางเลือกที่ 1 (แนะนำ): เริ่มยาเดี่ยวขนาดต่ำ (Low-dose Monotherapy: Start low, go slow)");
        medChoices.add("สูตรยาทางเลือก: CCB หรือ ACEI/ARB หรือ Thiazide-like diuretic");
      } else {
        medChoices.add("ทางเลือกที่ 1 (แนะนำตาม Thai HT 2024): เริ่มต้นด้วย Dual Combination (Single Pill Combination: SPC)");
        medChoices.add("  • สูตรยาหลัก: (ACEI หรือ ARB) + (CCB หรือ Thiazide/Thiazide-like diuretic)");
        medChoices.add("ทางเลือกที่ 2: เริ่มยาเดี่ยว (Monotherapy) หากแพทย์ต้องการประเมินการตอบสนองเป็นพิเศษ");
      }
    }
    // 🔵 5. ผู้ป่วยที่รับประทานยาอยู่แล้ว (medCount > 0)
    else {
      final bool isControlled = sbp < targetSbp && dbp < targetDbp && sbp >= 100 && dbp >= 70;

      if (isControlled) {
        medChoices.add("ทางเลือกที่ 1 (แนะนำ): ควบคุมความดันได้ตามเป้าหมายและปลอดภัย ให้คงการรักษาและขนาดยาเดิม (Maintain current regimen)");
        medChoices.add("ทางเลือกที่ 2: ติดตามความสม่ำเสมอในการรับประทานยา (Adherence) และเฝ้าระวังผลข้างเคียง");
      } else {
        if (data.heartRate >= 80 && !data.currentMedClasses.contains("Beta-blocker")) {
          medChoices.add("💡 ข้อสังเกต: ชีพจรขณะพักค่อนข้างเร็ว (HR = ${data.heartRate} bpm) อาจมี Sympathetic Hyperactivity พิจารณาเสริม Beta-blocker");
        }

        if (data.medCount == 1) {
          medChoices.add("ทางเลือกที่ 1 (แนะนำ Step 1 Escalation): ปรับเพิ่มเป็น Dual Combination (Single Pill Combination: SPC) โดยจับคู่ A+C หรือ A+D");
          medChoices.add("ทางเลือกที่ 2: Titrate ขนาดยาเดิมขึ้นเป็น Max tolerated dose ก่อนพิจารณาเพิ่มยาขนานที่ 2");
        } else if (data.medCount == 2) {
          medChoices.add("ทางเลือกที่ 1 (แนะนำ Step 2 Triple Therapy): ปรับเพิ่มเป็น Triple Therapy (Single Pill Combination: SPC) ประกอบด้วย (ACEI หรือ ARB) + CCB + Thiazide/Thiazide-like");
          medChoices.add("ทางเลือกที่ 2: ปรับขนาดยาทั้ง 2 ตัวเดิมให้ถึง Max tolerated dose");
        } else {
          bool hasAceiOrArb = data.currentMedClasses.contains("ACEI") || data.currentMedClasses.contains("ARB");
          bool hasCcb = data.currentMedClasses.contains("CCB");
          bool hasDiuretic = data.currentMedClasses.any((c) => c.contains("Diuretic") || c.contains("Thiazide"));

          if (hasAceiOrArb && hasCcb && hasDiuretic && data.isMaxToleratedDose) {
            medChoices.add("📌 เข้าเกณฑ์ Apparent Treatment-Resistant HT: ประเมิน Pseudo-resistance (Adherence, ปลอกแขน, WCH)");
            medChoices.add("ทางเลือกที่ 1 (Resistant Protocol - Diuretic switch):");

            // 🔒 Clinical Safety Guard: ห้ามเดา eGFR
            if (!hasEgfr) {
              medChoices.add("  • ⚠️ ขาดผล eGFR: จำเป็นต้องตรวจเลือดก่อนพิจารณาสลับยาขับปัสสาวะ (Thiazide-like สำหรับ eGFR ≥ 30 หรือ Loop Diuretic สำหรับ eGFR < 30)");
            } else if (data.egfr! >= 30) {
              medChoices.add("  • เปลี่ยน Diuretic เดิมเป็น Chlorthalidone หรือ Indapamide (eGFR = ${data.egfr!.toStringAsFixed(1)} ≥ 30)");
            } else {
              medChoices.add("  • เปลี่ยน Diuretic เดิมเป็น Loop Diuretic (eGFR = ${data.egfr!.toStringAsFixed(1)} < 30)");
            }

            // 🔒 Clinical Safety Guard: ห้ามสั่ง Spironolactone หากขาดผล eGFR หรือ K+
            if (!hasEgfr || !hasPotassium) {
              medChoices.add("ทางเลือกที่ 2 (Add-on MRA): ⛔ ระงับคำแนะนำ Spironolactone ชั่วคราว เนื่องจากขาดผลตรวจ eGFR หรือ Serum K+ (ต้องยืนยัน eGFR ≥ 30 และ K+ ≤ 4.5 ก่อนสั่งยา)");
              safetyAlerts.add("⛔ ข้อห้ามทางคลินิก: ขาดผลแล็บ eGFR หรือ K+ ห้ามสั่งจ่าย Spironolactone เพื่อป้องกันภาวะ Hyperkalemia วิกฤต");
            } else if (data.egfr! >= 30 && data.potassium! <= 4.5) {
              medChoices.add("ทางเลือกที่ 2 (Add-on MRA): เพิ่ม Spironolactone 25–50 mg/วัน (ติดตาม eGFR และ K+ หลังเริ่ม 1-2 สัปดาห์)");
            } else {
              medChoices.add("ทางเลือกที่ 2: ไม่แนะนำ Spironolactone เนื่องจาก eGFR < 30 หรือ K+ > 4.5 mEq/L (พิจารณา Chlorthalidone หรือยาขนานอื่น)");
            }

            if (data.heartRate >= 70 && !data.currentMedClasses.contains("Beta-blocker")) {
              medChoices.add("ทางเลือกที่ 3 (Add-on BB): เพิ่ม Beta-blocker เนื่องจาก Resting HR ≥ 70 bpm");
            } else {
              medChoices.add("ทางเลือกที่ 3 (Add-on Alpha-blocker): เพิ่ม Doxazosin ER 4–8 mg/วัน หรือ Alpha-2 agonist");
            }

            if (data.medCount >= 5) {
              medChoices.add("🚨 เข้าเกณฑ์ Refractory HT: ได้รับยา ≥ 5 ตัวรวม Spironolactone ยังไม่ถึงเป้าหมาย ส่งต่อแพทย์ผู้เชี่ยวชาญ");
            }
          } else {
            medChoices.add("ทางเลือกที่ 1 (Titration): ปรับขนาดยาทั้ง 3 กลุ่มเดิมให้ถึงขนาดสูงสุดที่ผู้ป่วยทนได้ (Max tolerated dose)");
            medChoices.add("ทางเลือกที่ 2: เสริมยาขับปัสสาวะ Thiazide-like diuretic หากยังไม่ได้รับในสูตรยาเดิม");
          }
        }
      }
    }

    // -------------------------------------------------------------
    // ข้อแนะนำพฤติกรรมและการให้คำปรึกษา
    // -------------------------------------------------------------
    List<String> lifestyleOptions = [
      "จำกัดปริมาณโซเดียมในอาหาร (DASH Diet) ไม่เกิน 2,000 มก./วัน (งดซดน้ำแกง/เลี่ยงอาหารแปรรูป)",
      "ควบคุมน้ำหนักตัว และออกกำลังกายระดับปานกลางสม่ำเสมอ 150 นาที/สัปดาห์",
      "โปรโตคอล HBPM 7 วัน: วัดเช้า (หลังตื่นใน 1 ชม.) และก่อนนอน รอบละ 2 ครั้งห่างกัน 1 นาที บันทึกก่อนพบแพทย์",
    ];

    String dosingTime = "แนะนำรับประทานยาตอนเช้าตามเวลาปกติเพื่อความสม่ำเสมอ";
    if (data.hasHighNocturnalBp) {
      dosingTime = "แนะนำปรับเวลารับประทานยาเป็นเวลาก่อนนอน (Documented High Nocturnal BP)";
    } else if (isOverTreated) {
      dosingTime = "พิจารณาหยุดหรือเลื่อนมื้อยาลดความดันออกไปก่อนจนกว่าระดับความดันจะกลับมาปกติ";
    }

    return ClinicalRecommendationResult(
      diagnosisEvaluation: diagnosis,
      bpTargetOffice: officeTarget,
      bpTargetHome: homeTarget,
      medicationChoices: medChoices,
      safetyAlerts: safetyAlerts,
      secondaryHtWorkupAlerts: secondaryWorkup,
      lifestyleAndMonitoringChoices: lifestyleOptions,
      defaultDosingTimeAdvice: dosingTime,
      missingLabAlerts: missingLabAlerts,
    );
  }
}