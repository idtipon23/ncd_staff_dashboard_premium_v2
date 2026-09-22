// lib/features/triage/domain/medication_safety_rules.dart

enum MedicationAlertSeverity { critical, warning, info }

class MedicationSafetyAlert {
  final MedicationAlertSeverity severity;
  final String title;
  final String description;
  final String recommendation;
  final List<String> implicatedDrugs;

  MedicationSafetyAlert({
    required this.severity,
    required this.title,
    required this.description,
    required this.recommendation,
    required this.implicatedDrugs,
  });
}

class MedicationSafetyRules {
  /// จำแนกกลุ่มยาจากชื่อยา
  static String classifyDrug(String rawName) {
    final name = rawName.toLowerCase().trim();
    if (name.contains('amlo') || name.contains('dipine') || name.contains('norvasc') || name.contains('manidipine') || name.contains('lercanidipine')) {
      return 'CCB';
    }
    if (name.contains('enaril') || name.contains('enalapril') || name.contains('pril') || name.contains('lisinopril') || name.contains('ramipril') || name.contains('captopril')) {
      return 'ACEI';
    }
    if (name.contains('sartan') || name.contains('losartan') || name.contains('valsartan') || name.contains('candesartan')) {
      return 'ARB';
    }
    if (name.contains('hctz') || name.contains('thiazide') || name.contains('indapamide') || name.contains('chlorthalidone') || name.contains('natrilix')) {
      return 'Thiazide-Diuretic';
    }
    if (name.contains('furosemide') || name.contains('lasix')) {
      return 'Loop-Diuretic';
    }
    if (name.contains('spironolactone') || name.contains('aldactone')) {
      return 'Spironolactone (MRA)';
    }
    if (name.contains('lol') || name.contains('atenolol') || name.contains('metoprolol') || name.contains('carvedilol') || name.contains('bisoprolol')) {
      return 'Beta-blocker';
    }
    if (name.contains('zosin') || name.contains('cardura') || name.contains('doxazosin')) {
      return 'Alpha-blocker';
    }
    return 'Other';
  }

  /// ตรวจสอบความปลอดภัยของการใช้ยาเทียบกับผลแล็บ สัญญาณชีพ และประวัติโรค
  static List<MedicationSafetyAlert> evaluateSafety({
    required List<Map<String, dynamic>> medications,
    required Map<String, dynamic>? latestLab,
    required List<Map<String, dynamic>> vitals,
    required Map<String, dynamic> patient,
  }) {
    final List<MedicationSafetyAlert> alerts = [];
    final List<String> drugNames = medications
        .map((m) => (m['medication_name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();

    final List<String> classes = drugNames.map(classifyDrug).toList();

    // 1. ตรวจสอบข้อห้ามใช้เด็ดขาด: ACEI ร่วมกับ ARB (Dual RAAS Blockade)
    final bool hasAcei = classes.contains('ACEI');
    final bool hasArb = classes.contains('ARB');
    if (hasAcei && hasArb) {
      alerts.add(MedicationSafetyAlert(
        severity: MedicationAlertSeverity.critical,
        title: '⛔ ข้อห้ามเด็ดขาด: พบการสั่งใช้ยาคู่ ACEI ร่วมกับ ARB พร้อมกัน',
        description: 'การใช้ ACEI และ ARB ร่วมกันเพิ่มความเสี่ยงต่อไตวายเฉียบพลันและภาวะโพแทสเซียมสูงรุนแรง โดยไม่มีประโยชน์ทางคลินิกเพิ่มเติม',
        recommendation: 'กรุณาหยุดยาตัวใดตัวหนึ่งทันที และคงการรักษาด้วยยากลุ่มเดียว',
        implicatedDrugs: drugNames.where((d) => classifyDrug(d) == 'ACEI' || classifyDrug(d) == 'ARB').toList(),
      ));
    }

    // 2. ตรวจสอบความปลอดภัยร่วมกับผลแล็บ (Drug-Lab Interactions)
    if (latestLab != null) {
      final k = (latestLab['potassium'] as num?)?.toDouble() ?? 0.0;
      final egfr = (latestLab['egfr'] as num?)?.toDouble() ?? 0.0;
      final bool hasMra = classes.contains('Spironolactone (MRA)');

      // ภาวะโพแทสเซียมสูง (Hyperkalemia)
      if (k >= 5.2 && (hasMra || hasAcei || hasArb)) {
        alerts.add(MedicationSafetyAlert(
          severity: MedicationAlertSeverity.critical,
          title: '🚨 เสี่ยงโพแทสเซียมวิกฤต: K+ ≥ 5.2 mEq/L ขณะใช้ยาที่กักโพแทสเซียม',
          description: 'ระดับโพแทสเซียมล่าสุด $k mEq/L เสี่ยงต่อภาวะหัวใจเต้นผิดจังหวะรุนแรง',
          recommendation: hasMra ? 'พิจารณาหยุด Spironolactone ชั่วคราว และปรับลดยา ACEI/ARB พร้อมนัดเจาะ K+ ซ้ำใน 1 สัปดาห์' : 'ลดขนาดยา ACEI/ARB และติดตามระดับเกลือแร่ซ้ำ',
          implicatedDrugs: drugNames.where((d) => classifyDrug(d) == 'Spironolactone (MRA)' || classifyDrug(d) == 'ACEI' || classifyDrug(d) == 'ARB').toList(),
        ));
      }

      // ภาวะไตเสื่อมรุนแรงกับยา Thiazide (eGFR < 30)
      final bool hasThiazide = classes.contains('Thiazide-Diuretic');
      if (egfr > 0 && egfr < 30 && hasThiazide) {
        alerts.add(MedicationSafetyAlert(
          severity: MedicationAlertSeverity.warning,
          title: '⚠️ ยาขับปัสสาวะไม่ได้ผล: eGFR < 30 ml/min กับยากลุ่ม Thiazide',
          description: 'ไตมีอัตราการกรองต่ำ (eGFR $egfr ml/min) ทำให้ Thiazide ขับโซเดียมได้ไม่เต็มประสิทธิภาพ',
          recommendation: 'พิจารณาเปลี่ยนเป็นยากลุ่ม Loop Diuretics (เช่น Furosemide) แทนตามแนวทางเวชปฏิบัติ',
          implicatedDrugs: drugNames.where((d) => classifyDrug(d) == 'Thiazide-Diuretic').toList(),
        ));
      }
    }

    // 3. ตรวจสอบความปลอดภัยร่วมกับสัญญาณชีพ (Drug-Vital Interactions)
    if (vitals.isNotEmpty) {
      final latest = vitals.first;
      final hr = (latest['pulse'] as num?)?.toInt() ?? 0;
      final sys = (latest['systolic'] as num?)?.toInt() ?? 0;
      final dia = (latest['diastolic'] as num?)?.toInt() ?? 0;
      final bool hasBetaBlocker = classes.contains('Beta-blocker');

      // หัวใจเต้นช้ากับ Beta-blocker
      if (hr > 0 && hr < 55 && hasBetaBlocker) {
        alerts.add(MedicationSafetyAlert(
          severity: MedicationAlertSeverity.warning,
          title: '⚠️ หัวใจเต้นช้ากว่าเกณฑ์ (Bradycardia): ชีพจร $hr bpm กับยา Beta-blocker',
          description: 'ตรวจพบชีพจรต่ำกว่า 55 ครั้งต่อนาที เสี่ยงต่ออาการหน้ามืดเป็นลมหรือภาวะหัวใจขัดจังหวะ (AV Block)',
          recommendation: 'พิจารณาปรับลดขนาดยาหรือหยุดยา Beta-blocker และตรวจคลื่นไฟฟ้าหัวใจ (EKG)',
          implicatedDrugs: drugNames.where((d) => classifyDrug(d) == 'Beta-blocker').toList(),
        ));
      }

      // ภาวะความดันตกขณะใช้ยาหลายขนาน (Polypharmacy Hypotension)
      final bool isLowBp = (sys > 0 && sys < 100) || (dia > 0 && dia < 60);
      if (isLowBp && medications.length >= 2) {
        alerts.add(MedicationSafetyAlert(
          severity: MedicationAlertSeverity.warning,
          title: '⚠️ ความดันตกจากการรักษา (Over-treatment): BP $sys/$dia mmHg กับยา ${medications.length} ชนิด',
          description: 'ผู้ป่วยได้รับยาลดความดันหลายชนิดและมีความดันต่ำกว่าเกณฑ์ เสี่ยงต่อการหกล้มในผู้สูงอายุ',
          recommendation: 'พิจารณาปรับลดยา 1 ชนิด (Step-down de-escalation) โดยเริ่มจากยาลำดับรอง',
          implicatedDrugs: drugNames,
        ));
      }
    }

    return alerts;
  }
}