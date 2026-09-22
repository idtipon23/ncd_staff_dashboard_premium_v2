// lib/features/triage/domain/care_gap_rules.dart

enum CareGapSeverity { critical, high, warning, info }

class CareGapItem {
  final String id;
  final String gapType;
  final String title;
  final String description;
  final CareGapSeverity severity;
  final String recommendedAction;
  final String defaultLineText;

  CareGapItem({
    required this.id,
    required this.gapType,
    required this.title,
    required this.description,
    required this.severity,
    required this.recommendedAction,
    required this.defaultLineText,
  });
}

class CareGapRules {
  /// วิเคราะห์หาช่องว่างการดูแลสุขภาพตามเวชปฏิบัติโรคความดันและเบาหวาน
  static List<CareGapItem> evaluateCareGaps({
    required Map<String, dynamic> patient,
    required List<Map<String, dynamic>> vitals,
    required Map<String, dynamic>? latestLab,
    required List<Map<String, dynamic>> appointments,
  }) {
    final List<CareGapItem> gaps = [];
    final now = DateTime.now();

    // 1. ตรวจสอบการควบคุมระดับความดันโลหิต (Uncontrolled BP Gap)
    if (vitals.isNotEmpty) {
      final latest = vitals.first;
      final sys = (latest['systolic'] as num?)?.toInt() ?? 0;
      final dia = (latest['diastolic'] as num?)?.toInt() ?? 0;

      if (sys >= 160 || dia >= 100) {
        gaps.add(CareGapItem(
          id: 'gap_bp_uncontrolled_high',
          gapType: 'BP_CONTROL',
          title: 'ความดันยังควบคุมไม่ได้ระดับรุนแรง (Stage 2 HT)',
          description: 'ความดันล่าสุด $sys/$dia mmHg เกินเกณฑ์มาตรฐานอย่างมีนัยสำคัญ',
          severity: CareGapSeverity.critical,
          recommendedAction: 'พิจารณาปรับเพิ่มขนาดยา หรือนัดพบแพทย์ก่อนกำหนด',
          defaultLineText: 'ความดันโลหิตล่าสุด ($sys/$dia mmHg) ยังสูงกว่าเป้าหมาย ขอแนะนำให้นั่งพักผ่อนและวัดซ้ำ หากมีอาการปวดศีรษะให้ติดต่อเจ้าหน้าที่ทันทีนะคะ',
        ));
      } else if (sys >= 140 || dia >= 90) {
        gaps.add(CareGapItem(
          id: 'gap_bp_uncontrolled_mild',
          gapType: 'BP_CONTROL',
          title: 'ความดันยังไม่บรรลุเป้าหมายการรักษา (Target BP)',
          description: 'ความดันล่าสุด $sys/$dia mmHg สูงกว่าเกณฑ์เป้าหมาย < 140/90 mmHg',
          severity: CareGapSeverity.warning,
          recommendedAction: 'ทบทวนการรับประทานอาหารเค็ม และการรับประทานยาต่อเนื่อง',
          defaultLineText: 'ระดับความดันยังสูงกว่าเป้าหมายเล็กน้อย แนะนำลดเค็มและรับประทานยาตามเวลาอย่างเคร่งครัดนะคะ',
        ));
      }
    } else {
      gaps.add(CareGapItem(
        id: 'gap_bp_missing',
        gapType: 'VITAL_MONITORING',
        title: 'ขาดบันทึกสัญญาณชีพแรกรับ',
        description: 'ยังไม่มีประวัติการบันทึกระดับความดันในระบบ',
        severity: CareGapSeverity.high,
        recommendedAction: 'แนะนำผู้ป่วยวัดความดันและบันทึกผ่านแอปพลิเคชัน',
        defaultLineText: 'กรุณาวัดความดันโลหิตและบันทึกค่าลงในระบบ เพื่อให้ทีมแพทย์สามารถติดตามอาการได้อย่างต่อเนื่องค่ะ',
      ));
    }

    // 2. ตรวจสอบรอบการตรวจแล็บติดตามโรค (Lab Monitoring Overdue Gap: 180 วัน)
    if (latestLab != null) {
      final labDateStr = latestLab['test_date'] ?? latestLab['created_at'];
      final labDate = DateTime.tryParse(labDateStr?.toString() ?? '');

      if (labDate != null) {
        final daysSinceLab = now.difference(labDate).inDays;
        if (daysSinceLab > 180) {
          gaps.add(CareGapItem(
            id: 'gap_lab_overdue',
            gapType: 'LAB_MONITORING',
            title: 'ครบกำหนดตรวจแล็บติดตามประจำปี/รอบ 6 เดือน',
            description: 'ผลแล็บล่าสุดตรวจเมื่อ $daysSinceLab วันที่แล้ว (เกิน 180 วัน)',
            severity: CareGapSeverity.high,
            recommendedAction: 'ออกใบนัดหมายเจาะเลือดตรวจ eGFR, Lipid profile, HbA1c',
            defaultLineText: 'ครบกำหนดการตรวจเลือดติดตามประจำรอบแล้ว ขอเชิญนัดหมายเข้าตรวจแล็บที่คลินิก NCDs นะคะ',
          ));
        }
      }
    } else {
      gaps.add(CareGapItem(
        id: 'gap_lab_never',
        gapType: 'LAB_MONITORING',
        title: 'ยังไม่เคยได้รับการตรวจทางห้องปฏิบัติการ (Baseline Lab Missing)',
        description: 'ไม่พบประวัติผลแล็บเคมีในเลือด (eGFR, K+, Lipid, FBS) ในระบบ',
        severity: CareGapSeverity.high,
        recommendedAction: 'แนะนำส่งตรวจ Baseline Labs สำหรับผู้ป่วย NCDs รายใหม่',
        defaultLineText: 'เพื่อการวางแผนการรักษาที่ปลอดภัย แนะนำเข้ารับการตรวจเลือดพื้นฐานที่โรงพยาบาลส่งเสริมสุขภาพตำบลนะคะ',
      ));
    }

    // 3. ตรวจสอบการนัดหมายและการขาดการติดต่อ (Follow-up Continuity Gap)
    bool hasUpcomingAppt = false;
    for (final appt in appointments) {
      final apptDate = DateTime.tryParse(appt['appointment_date']?.toString() ?? '');
      if (apptDate != null && apptDate.isAfter(now)) {
        hasUpcomingAppt = true;
        break;
      }
    }

    if (!hasUpcomingAppt) {
      gaps.add(CareGapItem(
        id: 'gap_no_appointment',
        gapType: 'CONTINUITY_OF_CARE',
        title: 'ไม่มีนัดหมายติดตามอาการในอนาคต',
        description: 'ผู้ป่วยยังไม่มีตารางนัดพบแพทย์หรือคลินิกติดตามอาการต่อเนื่อง',
        severity: CareGapSeverity.warning,
        recommendedAction: 'สร้างนัดหมาย F/U เพื่อตรวจประเมินซ้ำตามรอบ',
        defaultLineText: 'เพื่อการดูแลที่ต่อเนื่อง เจ้าหน้าที่ขอแนะนำให้ลงตารางนัดหมายติดตามอาการรอบถัดไปค่ะ',
      ));
    }

    return gaps;
  }
}