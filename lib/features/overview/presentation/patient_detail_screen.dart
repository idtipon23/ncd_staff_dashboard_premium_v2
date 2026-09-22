// lib/features/overview/presentation/patient_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../triage/domain/risk_stratification_rules.dart';
import '../../../core/constants/clinical_theme.dart';
import '../../../screens/patient_clinical_recommendation_sheet.dart';
import '../../../services/ht_cdss_engine.dart';
import '../../triage/domain/care_gap_rules.dart';
import '../../triage/domain/triage_rules.dart';
import '../data/triage_repository.dart';
import 'widgets/vital_trend_chart.dart';
// เพิ่ม Import ด้านบนของ patient_detail_screen.dart
import '../../triage/domain/medication_safety_rules.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _noteController = TextEditingController();
  bool _isSaving = false;
  bool _sendToLine = true;

  final List<String> _quickPresets = [
    'ช่วงนี้ความดันตัวบนสูงกว่าปกติ แนะนำพักผ่อนให้เพียงพอและวัดซ้ำพรุ่งนี้เช้า',
    'ตรวจพบโซเดียมในมื้ออาหารสะสมสูง แนะนำหลีกเลี่ยงแกงกะทิและน้ำซุป',
    'ไม่พบบันทึกการทานยาต่อเนื่อง กรุณาทานยาตามที่แพทย์สั่งอย่างสม่ำเสมอ',
    'ความดันอยู่ในเกณฑ์ควบคุมได้ดีมาก ขอให้ปฏิบัติตัวต่อเนื่องครับ/ค่ะ',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // lib/features/overview/presentation/patient_detail_screen.dart
// (แทนที่ฟังก์ชัน _openClinicalRecommendations และเพิ่ม _showAcuteTodScreeningDialog)

  /// กล่องข้อความคัดกรอง Red Flags เมื่อพบความดันวิกฤต (BP >= 180/110 mmHg)
  Future<bool> _showAcuteTodScreeningDialog(int sbp, int dbp) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: ClinicalColors.criticalRed, size: 24),
            SizedBox(width: 8),
            Text(
              'คัดกรองภาวะวิกฤตฉุกเฉิน (Hypertensive Crisis)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ClinicalColors.criticalBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ระดับความดันล่าสุด: $sbp/$dbp mmHg',
                style: const TextStyle(fontWeight: FontWeight.bold, color: ClinicalColors.criticalRed, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ผู้ป่วยมีอาการเตือนของภาวะอวัยวะเป้าหมายถูกทำลายเฉียบพลัน (Acute Target-Organ Damage) หรือไม่?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '• เจ็บแน่นหน้าอกรุนแรง / ปวดร้าวไปกรามหรือหลัง (ACS / Aortic Dissection)\n'
              '• หอบเหนื่อย นอนราบไม่ได้ (Acute Pulmonary Edema)\n'
              '• แขนขาอ่อนแรง ปากเบี้ยว สับสน ชัก หมดสติ (Acute Stroke / Encephalopathy)\n'
              '• ตามัวมองไม่เห็นเฉียบพลัน (Papilledema)',
              style: TextStyle(fontSize: 12, color: ClinicalColors.textPrimary, height: 1.4),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่มีอาการ (Hypertensive Urgency)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalColors.criticalRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('มีอาการ (Hypertensive Emergency)'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openClinicalRecommendations(
    Map<String, dynamic> patient,
    List<Map<String, dynamic>> vitals,
    Map<String, dynamic>? latestLab,
  ) async {
    final String targetPatientId = patient['id']?.toString() ?? widget.patientId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
      ),
    );

    List<String> realMedClasses = [];
    int realMedCount = 0;
    double? baselineCreatinine;

    try {
      final medRes = await Supabase.instance.client
          .from('medication_logs')
          .select('medication_name')
          .eq('patient_id', targetPatientId);

      final List<dynamic> medLogs = medRes as List<dynamic>;
      final Set<String> detectedClasses = {};

      for (final m in medLogs) {
        final name = (m['medication_name'] ?? '').toString().toLowerCase().trim();
        if (name.isEmpty) continue;

        if (name.contains('amlo') || name.contains('dipine') || name.contains('norvasc') ||
            name.contains('manidipine') || name.contains('lercanidipine')) {
          detectedClasses.add('CCB');
        } else if (name.contains('enaril') || name.contains('enalapril') || name.contains('pril') ||
            name.contains('lisinopril') || name.contains('ramipril') || name.contains('captopril')) {
          detectedClasses.add('ACEI');
        } else if (name.contains('sartan')) {
          detectedClasses.add('ARB');
        } else if (name.contains('hctz') || name.contains('thiazide') || name.contains('indapamide') ||
            name.contains('chlorthalidone') || name.contains('natrilix')) {
          detectedClasses.add('Thiazide-Diuretic');
        } else if (name.contains('furosemide') || name.contains('lasix')) {
          detectedClasses.add('Loop-Diuretic');
        } else if (name.contains('spironolactone') || name.contains('aldactone')) {
          detectedClasses.add('Spironolactone');
        } else if (name.contains('lol')) {
          detectedClasses.add('Beta-blocker');
        } else if (name.contains('zosin') || name.contains('cardura')) {
          detectedClasses.add('Alpha-blocker');
        } else {
          detectedClasses.add(m['medication_name'].toString());
        }
      }

      realMedClasses = detectedClasses.toList();
      realMedCount = medLogs.length;

      final pastLabs = await Supabase.instance.client
          .from('lab_results')
          .select('creatinine')
          .eq('patient_id', targetPatientId)
          .order('lab_date', ascending: false)
          .limit(2);

      final labList = pastLabs as List<dynamic>;
      if (labList.length > 1) {
        baselineCreatinine = (labList[1]['creatinine'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('❌ Error fetching data for CDSS: $e');
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    // 1. 🔒 Clinical Safety Guard: ดึงสัญญาณชีพจริง ไม่ใส่ค่าสมมุติ (0 = Insufficient Vitals)
    final latestVital = vitals.isNotEmpty ? vitals.first : <String, dynamic>{};
    final int officeSbp = (latestVital['systolic'] as num?)?.toInt() ?? 0;
    final int officeDbp = (latestVital['diastolic'] as num?)?.toInt() ?? 0;
    final int heartRate = (latestVital['pulse'] as num?)?.toInt() ?? 0;

    // 2. ดึงข้อมูลประวัติโรคร่วมตามบันทึกเวชระเบียน
    final underlying = (patient['underlying_diseases'] ?? '').toString().toLowerCase();
    final bool hasDm = underlying.contains('เบาหวาน') ||
        underlying.contains('dm') ||
        ((latestLab?['fasting_blood_sugar'] as num?)?.toDouble() ?? 0) >= 126.0 ||
        ((latestLab?['hba1c'] as num?)?.toDouble() ?? 0) >= 6.5;

    final bool hasCvd = underlying.contains('หัวใจ') || underlying.contains('หลอดเลือด') || patient['has_cvd'] == true;
    final bool hasCad = underlying.contains('หลอดเลือดหัวใจ') || underlying.contains('cad') || patient['has_cad'] == true;
    final bool hasHf = underlying.contains('หัวใจล้มเหลว') || underlying.contains('hf') || patient['has_heart_failure'] == true;
    final bool hasProteinuria = underlying.contains('โปรตีนรั่ว') || patient['has_proteinuria'] == true;
    final bool hasGout = underlying.contains('เกาต์') || underlying.contains('gout') || patient['has_gout'] == true;
    final bool hasOsa = underlying.contains('osa') || underlying.contains('นอนกรน') || patient['has_osa'] == true;
    final bool isPregnant = patient['is_pregnant'] == true || underlying.contains('ตั้งครรภ์');
    final bool isSmoker = patient['smokes'] == true || patient['smokers'] == true;

    // 3. 🔒 Zero Assumption Lab Extraction: ปล่อยเป็น Null หากไม่มีผลตรวจจริง
    final double? egfr = (latestLab?['egfr'] as num?)?.toDouble();
    final double? potassium = (latestLab?['potassium'] as num?)?.toDouble();
    final double? sodium = (latestLab?['sodium'] as num?)?.toDouble();
    final double? uricAcid = (latestLab?['uric_acid'] as num?)?.toDouble();
    final double? currentCreatinine = (latestLab?['creatinine'] as num?)?.toDouble();
    final double? totalChol = (latestLab?['total_cholesterol'] as num?)?.toDouble();

    // 4. คำนวณ Internal Screening Priority Score (Non-validated heuristic)
    final int age = (patient['age'] as num?)?.toInt() ?? 0;
    double calculatedCvRisk = 4.0;
    if (hasCvd || hasCad || hasHf) {
      calculatedCvRisk = 25.0;
    } else {
      if (age >= 60) calculatedCvRisk += 6.0;
      if (isSmoker) calculatedCvRisk += 4.0;
      if (hasDm) calculatedCvRisk += 5.0;
      if (officeSbp >= 160) {
        calculatedCvRisk += 6.0;
      } else if (officeSbp >= 140) {
        calculatedCvRisk += 3.0;
      }
      if (totalChol != null && totalChol >= 240) {
        calculatedCvRisk += 4.0;
      } else if (totalChol != null && totalChol >= 200) {
        calculatedCvRisk += 2.0;
      }
    }

    // 5. 🔒 ตรวจสอบภาวะ Acute Target-Organ Damage เมื่อพบความดัน >= 180/110 mmHg
    bool hasAcuteTod = false;
    if (officeSbp >= 180 || officeDbp >= 110) {
      if (mounted) {
        hasAcuteTod = await _showAcuteTodScreeningDialog(officeSbp, officeDbp);
      }
    }

    // 6. ประกอบอินพุตเข้าสู่ HtPatientData
    final patientData = HtPatientData(
      age: age,
      sex: patient['gender'] ?? 'ไม่ระบุ',
      officeSbp: officeSbp,
      officeDbp: officeDbp,
      homeSbp: (patient['home_sbp'] as num?)?.toInt(),
      homeDbp: (patient['home_dbp'] as num?)?.toInt(),
      heartRate: heartRate,
      hasCvd: hasCvd,
      hasDm: hasDm,
      cvRiskScore: calculatedCvRisk,
      hasHmod: patient['has_hmod'] == true,
      egfr: egfr,
      potassium: potassium,
      serumSodium: sodium,
      serumUricAcid: uricAcid,
      baselineCreatinine: baselineCreatinine,
      currentCreatinine: currentCreatinine,
      isFrail: patient['is_frail'] == true,
      hasHighNocturnalBp: patient['has_high_nocturnal_bp'] == true,
      medCount: realMedCount,
      currentMedClasses: realMedClasses,
      isMaxToleratedDose: patient['is_max_tolerated_dose'] == true,
      historyHighBp: vitals.length > 1,
      visitCount: vitals.length,
      hasPersistentLowDbp: TriageRules.checkPersistentLowDbp(vitals),
      hasCad: hasCad,
      hasHeartFailure: hasHf,
      hasProteinuria: hasProteinuria,
      hasGout: hasGout,
      isPregnant: isPregnant,
      hasSleepApnea: hasOsa,
      hasClassicPheoTriad: patient['has_pheo_triad'] == true,
      hasAcuteTargetOrganDamage: hasAcuteTod,
    );

    // 7. ประมวลผลผ่าน HtCdssEngine
    final result = HtCdssEngine.evaluate(patientData);

    // 8. แสดง Modal พร้อมการบันทึก CDSS Audit Provenance
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.90,
          child: PatientClinicalRecommendationSheet(
            patient: patient,
            patientData: patientData,
            result: result,
            onApplyToNote: (choiceText) {
              setState(() {
                _noteController.text = choiceText;
              });
            },
            onDecision: ({
              required String action,
              required String recommendationText,
              String? overrideReason,
            }) async {
              try {
                final bool isLabComplete = egfr != null && potassium != null;

                await ref.read(triageRepositoryProvider).logCdssEvent(
                  patientId: targetPatientId,
                  ruleId: 'TH_HT_CDSS_2024',
                  ruleVersion: 'TH-HT-2024.2',
                  severity: result.safetyAlerts.isNotEmpty ? 'CRITICAL' : 'ROUTINE',
                  inputSnapshot: {
                    'sbp': patientData.officeSbp,
                    'dbp': patientData.officeDbp,
                    'hr': patientData.heartRate,
                    'egfr': patientData.egfr,
                    'potassium': patientData.potassium,
                    'sodium': patientData.serumSodium,
                    'creatinine': patientData.currentCreatinine,
                    'baseline_creatinine': patientData.baselineCreatinine,
                    'med_count': patientData.medCount,
                    'med_classes': patientData.currentMedClasses,
                    'has_acute_tod': patientData.hasAcuteTargetOrganDamage,
                    'data_quality_status': isLabComplete ? 'COMPLETE' : 'INSUFFICIENT_LAB_DATA',
                  },
                  recommendation: {
                    'diagnosis': result.diagnosisEvaluation,
                    'selected_recommendation': recommendationText,
                    'target_office': result.bpTargetOffice,
                    'missing_lab_alerts': result.missingLabAlerts,
                    'safety_alerts': result.safetyAlerts,
                  },
                  staffAction: action,
                  overrideReason: overrideReason,
                );
                ref.invalidate(patientTimelineProvider(widget.patientId));
              } catch (e) {
                debugPrint('❌ Error logging CDSS audit event: $e');
              }
            },
          ),
        ),
      );
    }
  }
  /// การ์ดแสดงผลการประเมินความเสี่ยงพหุมิติพร้อมเหตุผลประกอบ (Explainable Risk Card)
  Widget _buildRiskStratificationBanner(PatientRiskAssessment risk) {
    Color bg;
    Color border;
    Color badgeBg;
    Color textColor;
    String label;
    IconData icon;

    switch (risk.level) {
      case ClinicalRiskLevel.high:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFCA5A5);
        badgeBg = ClinicalColors.criticalRed;
        textColor = const Color(0xFF991B1B);
        label = 'ความเสี่ยงสูง (HIGH CLINICAL RISK)';
        icon = Icons.warning_rounded;
        break;
      case ClinicalRiskLevel.moderate:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFCD34D);
        badgeBg = const Color(0xFFD97706);
        textColor = const Color(0xFF92400E);
        label = 'ความเสี่ยงปานกลาง (MODERATE RISK)';
        icon = Icons.info_rounded;
        break;
      case ClinicalRiskLevel.low:
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        badgeBg = ClinicalColors.primaryEmerald;
        textColor = const Color(0xFF166534);
        label = 'ความเสี่ยงต่ำ / ควบคุมได้ดี (LOW RISK)';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: badgeBg, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'การประเมินความเสี่ยงพหุมิติ: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Text(
                'Clinical Score: ${risk.riskScore}/100',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '📌 ปัจจัยบ่งชี้ความเสี่ยง (Clinical Evidence):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          ...risk.primaryReasons.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(fontSize: 12, color: textColor, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: badgeBg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    risk.clinicalRecommendation,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildOverTreatmentBanner(List<Map<String, dynamic>> vitals) {
    final latestVital = vitals.isNotEmpty ? vitals.first : <String, dynamic>{};
    final int sbp = (latestVital['systolic'] as num?)?.toInt() ?? 0;
    final int dbp = (latestVital['diastolic'] as num?)?.toInt() ?? 0;

    final bool isHypo = (sbp > 0 && sbp < 100) || (dbp > 0 && dbp < 60);
    final bool isPersistentLowDbp = TriageRules.checkPersistentLowDbp(vitals);
    final bool isExcessiveDbpLowering = dbp > 0 && dbp < 70 && sbp >= 140;

    if (!isHypo && !isPersistentLowDbp && !isExcessiveDbpLowering) {
      return const SizedBox.shrink();
    }

    String title = '';
    String description = '';

    if (isHypo) {
      title = '🚨 แจ้งเตือน: ผู้ป่วยมีความดันโลหิตต่ำกว่าเกณฑ์ (< 100/60 mmHg)';
      description = 'เสี่ยงต่อภาวะหน้ามืด วิงเวียน หรือหกล้ม แนะนำแพทย์พิจารณาปรับลดขนาดยา (Step-down) หรือหยุดยา 1 ชนิดชั่วคราว';
    } else if (isPersistentLowDbp) {
      title = '🚨 แจ้งเตือน Over-treatment: ตรวจพบ DBP < 70 mmHg ต่อเนื่อง 3 วันขึ้นไป';
      description = 'ผู้ป่วยได้รับยาลดความดันอยู่และมี DBP ต่ำต่อเนื่อง เสี่ยงต่อกล้ามเนื้อหัวใจขาดเลือด (J-Curve) แนะนำแพทย์พิจารณาปรับลดขนาดยา (De-escalation)';
    } else if (isExcessiveDbpLowering) {
      title = '⚠️ ข้อควรระวัง: DBP ต่ำกว่า 70 mmHg ขณะที่ SBP ยังสูง (≥ 140 mmHg)';
      description = 'ภาวะ Isolated Systolic HT ที่ DBP ลดต่ำเกินไป ให้ปรับยาด้วยความระมัดระวังเป็นพิเศษ และห้ามตั้งเป้าหมาย DBP < 70 mmHg';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF87171), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// การ์ดแสดงผลช่องว่างการดูแลที่ตรวจพบ (Care Gaps Card)
  Widget _buildCareGapsCard(List<CareGapItem> careGaps) {
    if (careGaps.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_rounded, color: ClinicalColors.primaryEmerald, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ไม่พบช่องว่างการดูแล (No Care Gaps) — การติดตามครบถ้วนตามเกณฑ์มาตรฐาน',
                style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late_rounded, color: Color(0xFFEA580C), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ช่องว่างการดูแลที่ต้องดำเนินการ (Actionable Care Gaps)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${careGaps.length} ข้อบ่งชี้',
                  style: const TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...careGaps.map((gap) {
            Color tagBg = const Color(0xFFFEF3C7);
            Color tagText = const Color(0xFFB45309);
            if (gap.severity == CareGapSeverity.critical) {
              tagBg = const Color(0xFFFEE2E2);
              tagText = ClinicalColors.criticalRed;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          gap.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C2D12)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          gap.gapType,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gap.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '💡 ข้อแนะนำ: ${gap.recommendedAction}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFC2410C)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: ClinicalColors.primaryEmerald,
                          side: const BorderSide(color: ClinicalColors.primaryEmerald),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 13),
                        label: const Text('ใช้ข้อความ LINE', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            _noteController.text = gap.defaultLineText;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('คัดลอกข้อความแนะนำเข้ากล่องส่ง LINE เรียบร้อยแล้ว'),
                              backgroundColor: ClinicalColors.primaryEmerald,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  Widget _buildMedicationCard(
    List<Map<String, dynamic>> medications,
    List<MedicationSafetyAlert> safetyAlerts,
    bool isLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: safetyAlerts.any((a) => a.severity == MedicationAlertSeverity.critical)
              ? const Color(0xFFFCA5A5)
              : ClinicalColors.borderLight,
        ),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.medication_rounded, size: 20, color: ClinicalColors.primaryEmerald),
                  SizedBox(width: 8),
                  Text(
                    'รายการยาปัจจุบัน & การเฝ้าระวัง (Medication Review)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ClinicalColors.canvasBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${medications.length} รายการ',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClinicalColors.deepCocoa),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // แสดงแบนเนอร์แจ้งเตือนความปลอดภัยของยา (ถ้ามี)
          if (safetyAlerts.isNotEmpty) ...[
            ...safetyAlerts.map((alert) {
              final isCritical = alert.severity == MedicationAlertSeverity.critical;
              final alertColor = isCritical ? ClinicalColors.criticalRed : ClinicalColors.warningOrange;
              final alertBg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
              final alertBorder = isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alertBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: alertBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: alertColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.description,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A3833), height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '👉 คำแนะนำ: ${alert.recommendation}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: alertColor),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 16),
          ],

          // รายการยารายตัวพร้อมเวลาทาน
          if (medications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: isLoading
                    ? const CircularProgressIndicator(strokeWidth: 2, color: ClinicalColors.primaryEmerald)
                    : const Text('ไม่มีบันทึกประวัติยาประจำตัว', style: TextStyle(color: ClinicalColors.textMuted, fontSize: 13)),
              ),
            )
          else
            ...medications.map((m) {
              // โค้ดแสดงผลการ์ดยาคงเดิม
              final drugName = m['medication_name'] ?? 'ไม่ระบุชื่อยา';
              final drugClass = MedicationSafetyRules.classifyDrug(drugName);
              final isMorning = m['is_morning_active'] == true;
              final isNoon = m['is_noon_active'] == true;
              final isEvening = m['is_evening_active'] == true;
              final isBedtime = m['is_bedtime_active'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ClinicalColors.canvasBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drugName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'กลุ่ม: $drugClass',
                            style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (isMorning) _buildMealBadge('เช้า'),
                        if (isNoon) _buildMealBadge('กลางวัน'),
                        if (isEvening) _buildMealBadge('เย็น'),
                        if (isBedtime) _buildMealBadge('ก่อนนอน'),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMealBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCEEAD6)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(patientDetailProvider(widget.patientId));

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      appBar: AppBar(
        backgroundColor: ClinicalColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'เวชระเบียนผู้ป่วยรายบุคคล (Clinical Workspace & Audit)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: ClinicalColors.primaryEmerald,
                labelColor: ClinicalColors.primaryEmerald,
                unselectedLabelColor: ClinicalColors.textMuted,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'ภาพรวมการดูแล (Workspace)'),
                  Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'ประวัติเหตุการณ์ (Clinical Timeline)'),
                ],
              ),
              const Divider(height: 1, color: ClinicalColors.borderLight),
            ],
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('ไม่สามารถโหลดข้อมูลผู้ป่วยได้: $err', style: const TextStyle(color: ClinicalColors.criticalRed)),
          ),
        ),
        data: (data) {
          // ใช้ patient ID ที่ตรงกับ CDSS เพื่อความแม่นยำ
          final targetId = data.patient['id']?.toString() ?? widget.patientId;
          final medsAsync = ref.watch(patientMedicationsProvider(targetId));
          final medications = medsAsync.value ?? const [];

          List<Map<String, dynamic>> patientAppointments = const [];
          try {
            final dyn = data as dynamic;
            if (dyn.appointments != null) {
              patientAppointments = List<Map<String, dynamic>>.from(dyn.appointments);
            }
          } catch (_) {}

          final careGaps = CareGapRules.evaluateCareGaps(
            patient: data.patient,
            vitals: data.vitalSigns,
            latestLab: data.latestLab,
            appointments: patientAppointments,
          );

          final riskAssessment = RiskStratificationRules.evaluate(
            patient: data.patient,
            vitals: data.vitalSigns,
            latestLab: data.latestLab,
            appointments: patientAppointments,
          );

          // 🌟 สแกนความปลอดภัยของยา
          final medSafetyAlerts = MedicationSafetyRules.evaluateSafety(
            medications: medications,
            latestLab: data.latestLab,
            vitals: data.vitalSigns,
            patient: data.patient,
          );

          return TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPatientHeader(data.patient, data.vitalSigns, data.latestLab),
                    const SizedBox(height: 16),
                    _buildRiskStratificationBanner(riskAssessment),
                    _buildOverTreatmentBanner(data.vitalSigns),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 950;
                        if (isDesktop) {
                          final leftWidth = (constraints.maxWidth - 24) * 0.58;
                          final rightWidth = (constraints.maxWidth - 24) * 0.42;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: leftWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildCareGapsCard(careGaps),
                                    _buildVitalSignsCard(data.vitalSigns),
                                    const SizedBox(height: 24),
                                    _buildLabCard(data.latestLab),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: rightWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildMedicationCard(medications, medSafetyAlerts, medsAsync.isLoading), // 👈 แสดงการ์ดยาและความปลอดภัย
                                    const SizedBox(height: 24),
                                    _buildFoodLogsCard(data.recentFoods),
                                    const SizedBox(height: 24),
                                    _buildClinicalActionCard(data.staffNotes, data.patient['line_user_id']),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCareGapsCard(careGaps),
                              _buildVitalSignsCard(data.vitalSigns),
                              const SizedBox(height: 24),
                              _buildLabCard(data.latestLab),
                              const SizedBox(height: 24),
                              _buildMedicationCard(medications, medSafetyAlerts, medsAsync.isLoading), // 👈 แสดงการ์ดยาและความปลอดภัย
                              const SizedBox(height: 24),
                              _buildFoodLogsCard(data.recentFoods),
                              const SizedBox(height: 24),
                              _buildClinicalActionCard(data.staffNotes, data.patient['line_user_id']),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              _buildTimelineTab(),
            ],
          );
        },
      ),
    );
  }

  /// แท็บแสดงกระแสเหตุการณ์ทางคลินิกตามลำดับเวลา (Clinical Timeline)
  Widget _buildTimelineTab() {
    final timelineAsync = ref.watch(patientTimelineProvider(widget.patientId));

    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald)),
      error: (e, _) => Center(child: Text('ไม่สามารถดึงข้อมูลไทม์ไลน์ได้: $e', style: const TextStyle(color: ClinicalColors.criticalRed))),
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Text('ยังไม่มีบันทึกเหตุการณ์ทางคลินิกของผู้ป่วยรายนี้', style: TextStyle(color: ClinicalColors.textMuted)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final ev = events[index];
            final dateStr = '${ev.timestamp.day}/${ev.timestamp.month}/${ev.timestamp.year} ${ev.timestamp.hour.toString().padLeft(2, '0')}:${ev.timestamp.minute.toString().padLeft(2, '0')} น.';

            Color dotColor = ClinicalColors.primaryEmerald;
            IconData eventIcon = Icons.medical_information_outlined;

            if (ev.severity == 'CRITICAL') {
              dotColor = ClinicalColors.criticalRed;
              eventIcon = Icons.crisis_alert_rounded;
            } else if (ev.severity == 'WARNING') {
              dotColor = ClinicalColors.warningOrange;
              eventIcon = Icons.warning_amber_rounded;
            } else if (ev.eventType == TimelineEventType.staffAction) {
              dotColor = const Color(0xFF6366F1);
              eventIcon = Icons.send_rounded;
            } else if (ev.eventType == TimelineEventType.appointment) {
              dotColor = const Color(0xFF0284C7);
              eventIcon = Icons.calendar_today_rounded;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dotColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: dotColor, width: 2),
                      ),
                      child: Icon(eventIcon, size: 16, color: dotColor),
                    ),
                    if (index != events.length - 1)
                      Container(width: 2, height: 64, color: ClinicalColors.borderLight),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ClinicalColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ClinicalColors.borderLight),
                      boxShadow: ClinicalColors.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ev.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: ev.severity == 'CRITICAL' ? ClinicalColors.criticalRed : ClinicalColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(dateStr, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(ev.description, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A3833), height: 1.3)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 13, color: ClinicalColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'ผู้ดำเนินการ: ${ev.actor ?? "ระบบอัตโนมัติ"}',
                              style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPatientHeader(Map<String, dynamic> p, List<Map<String, dynamic>> vitals, Map<String, dynamic>? latestLab) {
    final name = p['name'] ?? '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;

          final profileInfo = Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ClinicalColors.primaryEmerald.withAlpha(30),
                child: const Icon(Icons.person, color: ClinicalColors.primaryEmerald, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('HN: ${p['hn'] ?? '-'} | อายุ: ${p['age'] ?? '-'} ปี | เพศ: ${p['gender'] ?? '-'}',
                        style: const TextStyle(color: ClinicalColors.textMuted, fontSize: 13), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('โรคประจำตัว: ${p['underlying_diseases'] ?? 'ยังไม่ระบุ'}',
                        style: const TextStyle(color: ClinicalColors.deepCocoa, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0FDF4),
                  foregroundColor: ClinicalColors.primaryEmerald,
                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _openClinicalRecommendations(p, vitals, latestLab),
                icon: const Icon(Icons.medical_information_rounded, size: 18, color: ClinicalColors.primaryEmerald),
                label: const Text('แนวทางรักษา HT (CDSS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClinicalColors.canvasBg,
                  foregroundColor: ClinicalColors.deepCocoa,
                  side: const BorderSide(color: ClinicalColors.borderLight),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _showFollowUpDialog,
                icon: const Icon(Icons.calendar_month_outlined, size: 18, color: ClinicalColors.primaryEmerald),
                label: const Text('นัดหมาย F/U / ส่งต่อ', style: TextStyle(fontSize: 13)),
              ),
            ],
          );
          

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [profileInfo, const SizedBox(height: 16), actionButtons],
            );
          } else {
            return Row(
              children: [Expanded(child: profileInfo), const SizedBox(width: 16), actionButtons],
            );
          }
        },
      ),
    );
  }

  Widget _buildVitalSignsCard(List<Map<String, dynamic>> vitals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('แนวโน้มความดันโลหิต (Vital Signs Trend & Target Limit)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          VitalTrendChart(vitals: vitals),
          const Divider(height: 32),
          const Text('บันทึกล่าสุดย้อนหลัง:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (vitals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('ไม่มีข้อมูลสัญญาณชีพ', style: TextStyle(color: ClinicalColors.textMuted, fontSize: 13)),
            )
          else
            ...vitals.take(3).map((v) {
              final sys = v['systolic'] ?? 0;
              final dia = v['diastolic'] ?? 0;
              final isHigh = sys >= 180 || dia >= 110;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isHigh ? ClinicalColors.criticalBg : ClinicalColors.canvasBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ความดัน: $sys/$dia mmHg (ชีพจร: ${v['pulse'] ?? '-'})',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isHigh ? ClinicalColors.criticalRed : ClinicalColors.textPrimary, fontSize: 13)),
                    Text('${v['recorded_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLabCard(Map<String, dynamic>? lab) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ผลตรวจแล็บล่าสุด (Laboratory Results)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (lab == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ไม่มีประวัติผลแล็บ', style: TextStyle(color: ClinicalColors.textMuted)),
              ),
            )
          else
            Row(
              children: [
                _buildLabItem('FBS (น้ำตาล)', '${lab['fasting_blood_sugar'] ?? '-'} mg/dL'),
                _buildLabItem('HbA1c', '${lab['hba1c'] ?? '-'} %'),
                _buildLabItem('eGFR (ไต)', '${lab['egfr'] ?? '-'}'),
                _buildLabItem('Creatinine', '${lab['creatinine'] ?? '-'}'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLabItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClinicalColors.primaryEmerald)),
        ],
      ),
    );
  }

  Widget _buildFoodLogsCard(List<Map<String, dynamic>> foods) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('บันทึกอาหารล่าสุด (Nutrition Log)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (foods.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ไม่มีบันทึกอาหาร', style: TextStyle(color: ClinicalColors.textMuted)),
              ),
            )
          else
            ...foods.map((f) {
              final sodium = (f['sodium_mg'] as num?)?.toInt() ?? 0;
              final isHighSodium = sodium > 800;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ClinicalColors.canvasBg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f['food_name'] ?? 'อาหารทั่วไป', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('พลังงาน: ${f['calories'] ?? 0} kcal', style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHighSodium ? ClinicalColors.warningBg : ClinicalColors.normalBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'โซเดียม: $sodium mg',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isHighSodium ? ClinicalColors.warningOrange : ClinicalColors.normalGreen),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildClinicalActionCard(List<Map<String, dynamic>> notes, String? lineUserId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.send_rounded, size: 18, color: ClinicalColors.primaryEmerald),
              SizedBox(width: 8),
              Text('ส่งคำแนะนำทางการแพทย์ (Clinical Action)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('เลือกข้อความสำเร็จรูป (Preset):', style: TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickPresets
                .map((preset) => ActionChip(
                      backgroundColor: ClinicalColors.canvasBg,
                      side: const BorderSide(color: ClinicalColors.borderLight),
                      label: Text(preset, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _noteController.text = preset),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'พิมพ์คำแนะนำเพิ่มเติมหรือปรับแต่งข้อความก่อนส่ง...',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _sendToLine,
                activeColor: ClinicalColors.primaryEmerald,
                onChanged: (val) => setState(() => _sendToLine = val ?? true),
              ),
              const Text('ส่งแจ้งเตือนเข้า LINE คนไข้', style: TextStyle(fontSize: 13)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _submitClinicalAction(lineUserId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClinicalColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, size: 16),
                label: const Text('ส่งคำแนะนำ'),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('ประวัติคำแนะนำที่เคยส่ง:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...notes.take(3).map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${n['note_text']} (${n['staff_name'] ?? 'เจ้าหน้าที่'})', style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _submitClinicalAction(String? lineUserId) async {
    if (_noteController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    final staffName = (currentUser?.userMetadata?['full_name'] ??
            currentUser?.userMetadata?['name'] ??
            currentUser?.email ??
            'พยาบาลวิชาชีพเวชปฏิบัติ')
        .toString();

    try {
      await ref.read(triageRepositoryProvider).sendClinicalAction(
            patientId: widget.patientId,
            noteText: _noteController.text.trim(),
            staffName: staffName,
            sendToLine: _sendToLine,
            lineUserId: lineUserId,
          );
      _noteController.clear();
      ref.invalidate(patientDetailProvider(widget.patientId));
      ref.invalidate(patientTimelineProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำแนะนำและบันทึกข้อมูลเรียบร้อยแล้ว'), backgroundColor: ClinicalColors.primaryEmerald),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: ClinicalColors.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showFollowUpDialog() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    final reasonController = TextEditingController(text: 'ตรวจติดตามระดับความดันและผลแล็บ');
    final clinicController = TextEditingController(text: 'คลินิก NCDs รพ.สต.');
    bool needFasting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('นัดหมายติดตามอาการ / ส่งต่อแพทย์', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('วันที่นัดหมาย:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(selectedDate.toIso8601String().split('T').first),
                ),
                const SizedBox(height: 12),
                TextField(controller: clinicController, decoration: const InputDecoration(labelText: 'แพทย์ / แผนก / คลินิกที่นัด', isDense: true)),
                const SizedBox(height: 12),
                TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'เหตุผลการนัดหมาย', isDense: true)),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('ต้องงดน้ำ-อาหารก่อนตรวจ (เจาะเลือด)'),
                  value: needFasting,
                  activeColor: ClinicalColors.primaryEmerald,
                  onChanged: (val) => setDialogState(() => needFasting = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ClinicalColors.primaryEmerald, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(triageRepositoryProvider).scheduleFollowUp(
                      patientId: widget.patientId,
                      followUpDate: selectedDate,
                      reason: reasonController.text,
                      doctorOrClinic: clinicController.text,
                      needFasting: needFasting,
                    );
                ref.invalidate(patientDetailProvider(widget.patientId));
                ref.invalidate(patientTimelineProvider(widget.patientId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('บันทึกการนัดหมายและลงตารางนัดเรียบร้อยแล้ว'), backgroundColor: ClinicalColors.primaryEmerald),
                  );
                }
              },
              child: const Text('บันทึกนัดหมาย'),
            ),
          ],
        ),
      ),
    );
  }
}