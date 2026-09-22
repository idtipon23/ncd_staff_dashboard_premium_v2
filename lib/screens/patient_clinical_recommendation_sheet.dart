// lib/screens/patient_clinical_recommendation_sheet.dart

import 'package:flutter/material.dart';
import '../services/ht_cdss_engine.dart';

class PatientClinicalRecommendationSheet extends StatelessWidget {
  final Map<String, dynamic> patient;
  final HtPatientData patientData;
  final ClinicalRecommendationResult result;
  final Function(String noteText) onApplyToNote;
  final void Function({
    required String action, // 'ACCEPTED', 'OVERRIDDEN', 'DISMISSED'
    required String recommendationText,
    String? overrideReason,
  })? onDecision;

  const PatientClinicalRecommendationSheet({
    super.key,
    required this.patient,
    required this.patientData,
    required this.result,
    required this.onApplyToNote,
    this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนหัว Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.medical_information_rounded,
                        color: Color(0xFF2F9E82),
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ข้อเสนอแนะและแนะนำการรักษาสำหรับผู้ป่วยรายนี้ (CDSS)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A3833),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    onDecision?.call(
                      action: 'DISMISSED',
                      recommendationText: 'ปิดหน้าต่างโดยไม่ได้เลือกข้อเสนอแนะ',
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 1. Safety Alerts (ถ้ามี)
            if (result.safetyAlerts.isNotEmpty) ...[
              _buildSafetySection(),
              const SizedBox(height: 18),
            ],

            // 2. Secondary HT Workup Triggers
            if (result.secondaryHtWorkupAlerts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF4FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0ABFC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.biotech_rounded, color: Color(0xFF9333EA), size: 20),
                        SizedBox(width: 8),
                        Text(
                          '🔍 สัญญาณเตือนตรวจคัดกรองความดันโลหิตสูงทุติยภูมิ (Secondary HT Workup)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...result.secondaryHtWorkupAlerts.map(
                      (txt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          txt,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF581C87)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // คำเตือนดุลยพินิจแพทย์
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อเสนอแนะนี้ประมวลผลตาม Thai HT Guidelines 2024 เพื่อสนับสนุนการตัดสินใจ การรักษาและสั่งยาต้องอยู่ภายใต้ดุลยพินิจของแพทย์ผู้รักษาเท่านั้น',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Snapshot สุขภาพ
            _buildSnapshotSection(),
            const SizedBox(height: 18),

            // 4. เป้าหมายความดัน
            _buildTargetSection(),
            const SizedBox(height: 18),

            // 5. ทางเลือกการปรับยา
            _buildMedicationChoicesSection(context),
            const SizedBox(height: 18),

            // 6. ทางเลือกการปรับพฤติกรรม & Dosing
            _buildLifestyleSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotSection() {
    final bpText = patientData.officeSbp > 0
        ? '${patientData.officeSbp}/${patientData.officeDbp} mmHg'
        : 'ยังไม่มีบันทึก';
    final hrText = patientData.heartRate > 0 ? '${patientData.heartRate} bpm' : 'ไม่ระบุ';
    final egfrText = patientData.egfr != null && patientData.egfr! > 0 ? '${patientData.egfr} ml/min' : 'ยังไม่มีผลแล็บ';
    final kText = patientData.potassium != null && patientData.potassium! > 0 ? '${patientData.potassium} mEq/L' : 'ยังไม่มีผลแล็บ';
    final medListText = patientData.currentMedClasses.isNotEmpty
        ? patientData.currentMedClasses.join(", ")
        : 'ไม่มีประวัติใช้ยาความดัน';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEADBCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📌 สรุปข้อมูลทางคลินิก (Clinical Snapshot)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF4A3833),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• การประเมิน: ${result.diagnosisEvaluation}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2F9E82),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• BP ล่าสุด: $bpText | HR: $hrText | Thai CV Risk: ${patientData.cvRiskScore.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 13, color: Color(0xFF4A3833)),
          ),
          const SizedBox(height: 4),
          Text(
            '• ผลแล็บ: eGFR $egfrText | K+ $kText | ประวัติ CVD: ${patientData.hasCvd ? "มี" : "ไม่มี"} | เบาหวาน: ${patientData.hasDm ? "มี" : "ไม่มี"}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A7568)),
          ),
          const SizedBox(height: 4),
          Text(
            '• ยาปัจจุบัน (${patientData.medCount} รายการ): $medListText',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A7568)),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: result.safetyAlerts
            .map(
              (alert) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  alert,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTargetSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEADBCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎯 เป้าหมายความดันโลหิต (Target BP)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF4A3833),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• Office BP Target: ${result.bpTargetOffice}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2F9E82),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '• Home BP Target (HBPM): ${result.bpTargetHome}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF8A7568)),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationChoicesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F9E82).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💊 ทางเลือกการปรับขนาดยา/สูตรยา (Medication Choices)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2F9E82),
            ),
          ),
          const SizedBox(height: 10),
          ...result.medicationChoices.map(
            (choice) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      choice,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF2F9E82)),
                    label: const Text('ใช้ Choice นี้', style: TextStyle(fontSize: 12, color: Color(0xFF2F9E82))),
                    onPressed: () {
                      onDecision?.call(action: 'ACCEPTED', recommendationText: choice);
                      onApplyToNote(choice);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 🌟 ปุ่ม Override แผนการรักษา (แพทย์ต้องการใช้สูตรอื่น)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD97706)),
                foregroundColor: const Color(0xFFD97706),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text(
                'ปรับแผนการรักษาอื่นนอกเหนือจากคำแนะนำ (Override CDSS)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showOverrideDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showOverrideDialog(BuildContext context) {
    final customMedCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ระบุแผนการรักษาและเหตุผล (Override CDSS)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('แผนการรักษา/สูตรยาที่แพทย์สั่งจริง:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: customMedCtrl,
                decoration: const InputDecoration(
                  hintText: 'เช่น สั่ง Manidipine 10 mg 1x1 แทน...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('เหตุผลความจำเป็นทางคลินิก (Override Rationale):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'เช่น ผู้ป่วยเคยมีอาการขาบวมจาก Amlodipine...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            onPressed: () {
              if (customMedCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) {
                return;
              }
              final customText = 'แผนการรักษา (Override): ${customMedCtrl.text.trim()} [เหตุผล: ${reasonCtrl.text.trim()}]';
              onDecision?.call(
                action: 'OVERRIDDEN',
                recommendationText: customMedCtrl.text.trim(),
                overrideReason: reasonCtrl.text.trim(),
              );
              onApplyToNote(customText);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('บันทึกคำสั่งการ'),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9EBCF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🥗 ข้อเสนอแนะพฤติกรรม & การรับประทานยา (ส่งหาคนไข้ได้ปลอดภัย)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF3E5E33),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• เวลาทานยา: ${result.defaultDosingTimeAdvice}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4C7A3F),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...result.lifestyleAndMonitoringChoices.map(
            (act) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $act',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5C7A50)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2F9E82)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF2F9E82)),
              label: const Text(
                'คัดลอกเฉพาะคำแนะนำพฤติกรรมลงช่องส่ง LINE',
                style: TextStyle(color: Color(0xFF2F9E82), fontSize: 12),
              ),
              onPressed: () {
                final lifestyleText =
                    'คำแนะนำสุขภาพเพิ่มเติม:\n- ${result.defaultDosingTimeAdvice}\n- ${result.lifestyleAndMonitoringChoices.join("\n- ")}';
                onDecision?.call(action: 'ACCEPTED', recommendationText: lifestyleText);
                onApplyToNote(lifestyleText);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}