import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/clinical_theme.dart';
import '../../data/opd_visit_repository.dart';
import 'opd_encounter_dialog.dart';

class OpdVisitHistoryView extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final int? latestSbp;
  final int? latestDbp;
  final int? latestPulse;

  const OpdVisitHistoryView({
    super.key,
    required this.patientId,
    required this.patientName,
    this.latestSbp,
    this.latestDbp,
    this.latestPulse,
  });

  @override
  ConsumerState<OpdVisitHistoryView> createState() => _OpdVisitHistoryViewState();
}

class _OpdVisitHistoryViewState extends ConsumerState<OpdVisitHistoryView> {
  String? _selectedVisitId;

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(patientOpdVisitsProvider(widget.patientId));

    return visitsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: ClinicalColors.criticalRed, size: 40),
              const SizedBox(height: 12),
              Text('เกิดข้อผิดพลาดในการโหลดประวัติการรักษา: $err',
                  style: const TextStyle(color: ClinicalColors.textMuted)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(patientOpdVisitsProvider(widget.patientId)),
                child: const Text('ลองใหม่อีกครั้ง'),
              ),
            ],
          ),
        ),
      ),
      data: (visits) {
        if (visits.isEmpty) {
          return _buildEmptyState(context);
        }

        // หากยังไม่ได้เลือก ให้เลือกใบล่าสุดเป็นค่าเริ่มต้น
        final currentVisit = visits.firstWhere(
          (v) => v.id == _selectedVisitId,
          orElse: () => visits.first,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;

            if (isNarrow) {
              return Column(
                children: [
                  _buildHeaderBar(context),
                  const SizedBox(height: 16),
                  _buildVisitsDropdown(visits, currentVisit),
                  const SizedBox(height: 16),
                  _buildOpdCardDetail(currentVisit),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderBar(context),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ฝั่งซ้าย: รายการประวัติวันที่มาตรวจ (Visit Timeline List)
                      SizedBox(
                        width: 320,
                        child: _buildVisitsList(visits, currentVisit),
                      ),
                      const SizedBox(width: 20),
                      // ฝั่งขวา: เวชระเบียนฉบับเต็ม (Full OPD Card)
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildOpdCardDetail(currentVisit),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_edu_rounded, color: Color(0xFF0284C7), size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เวชระเบียนผู้ป่วยนอก (OPD Encounters)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                ),
                Text(
                  'บันทึกการตรวจร่างกาย ซักประวัติ และคำสั่งการรักษาแต่ละครั้ง',
                  style: TextStyle(fontSize: 12, color: ClinicalColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openNewEncounterDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('บันทึกการตรวจครั้งใหม่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsList(List<OpdVisitModel> visits, OpdVisitModel currentVisit) {
    return Container(
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: visits.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: ClinicalColors.borderLight),
        itemBuilder: (context, index) {
          final v = visits[index];
          final isSelected = v.id == currentVisit.id;
          final dateStr = '${v.visitDate.day}/${v.visitDate.month}/${v.visitDate.year + 543}';
          final timeStr = '${v.visitDate.hour.toString().padLeft(2, '0')}:${v.visitDate.minute.toString().padLeft(2, '0')} น.';

          return InkWell(
            onTap: () => setState(() => _selectedVisitId = v.id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? const Color(0xFF0284C7) : ClinicalColors.textPrimary)),
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dx: ${v.diagnosisText}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ClinicalColors.deepCocoa),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (v.sbp != null && v.dbp != null) ...[
                        Text('BP: ${v.sbp}/${v.dbp}', style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          v.doctorName,
                          style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisitsDropdown(List<OpdVisitModel> visits, OpdVisitModel currentVisit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVisit.id,
          isExpanded: true,
          items: visits.map((v) {
            final dateStr = '${v.visitDate.day}/${v.visitDate.month}/${v.visitDate.year + 543}';
            return DropdownMenuItem(
              value: v.id,
              child: Text('$dateStr - Dx: ${v.diagnosisText} (${v.doctorName})', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedVisitId = val);
          },
        ),
      ),
    );
  }

  Widget _buildOpdCardDetail(OpdVisitModel v) {
    final dateStr = '${v.visitDate.day}/${v.visitDate.month}/${v.visitDate.year + 543}';
    final timeStr = '${v.visitDate.hour.toString().padLeft(2, '0')}:${v.visitDate.minute.toString().padLeft(2, '0')} น.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ส่วนหัว OPD Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('บันทึกการตรวจวันที่: $dateStr ($timeStr)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('เสร็จสิ้น (COMPLETED)',
                            style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('แพทย์ผู้ตรวจรักษา: ${v.doctorName}',
                      style: const TextStyle(fontSize: 13, color: ClinicalColors.textMuted)),
                ],
              ),
            ],
          ),
          const Divider(height: 32, color: ClinicalColors.borderLight),

          // 1. สัญญาณชีพ (Vital Signs Snapshot)
          if (v.sbp != null || v.temperature != null || v.weightKg != null) ...[
            const Text('สัญญาณชีพแรกรับ (Vital Signs Snapshot)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClinicalColors.deepCocoa)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (v.sbp != null && v.dbp != null)
                  _buildSnapshotChip('BP', '${v.sbp}/${v.dbp} mmHg', Icons.favorite_outline),
                if (v.pulse != null)
                  _buildSnapshotChip('ชีพจร', '${v.pulse} bpm', Icons.monitor_heart_outlined),
                if (v.temperature != null)
                  _buildSnapshotChip('อุณหภูมิ', '${v.temperature} °C', Icons.thermostat_outlined),
                if (v.respiratoryRate != null)
                  _buildSnapshotChip('อัตราหายใจ', '${v.respiratoryRate} /min', Icons.air_outlined),
                if (v.weightKg != null)
                  _buildSnapshotChip('น้ำหนัก', '${v.weightKg} kg', Icons.scale_outlined),
                if (v.heightCm != null)
                  _buildSnapshotChip('ส่วนสูง', '${v.heightCm} cm', Icons.height_outlined),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // 2. การซักประวัติ (History Taking)
          _buildSectionHeader('1. การซักประวัติ (History Taking)', Icons.history_edu_rounded),
          const SizedBox(height: 10),
          _buildInfoRow('อาการสำคัญ (CC)', v.chiefComplaint, isBold: true),
          if (v.presentIllness != null && v.presentIllness!.isNotEmpty)
            _buildInfoRow('ประวัติปัจจุบัน (PI)', v.presentIllness!),
          if (v.pastHistory != null && v.pastHistory!.isNotEmpty)
            _buildInfoRow('ประวัติอดีต/โรคประจำตัว (PH)', v.pastHistory!),
          if (v.medicationAllergy != null && v.medicationAllergy!.isNotEmpty)
            _buildInfoRow('ประวัติแพ้ยา', v.medicationAllergy!, isAlert: true),

          const SizedBox(height: 20),

          // 3. การตรวจร่างกาย (Physical Examination)
          _buildSectionHeader('2. การตรวจร่างกาย (Physical Examination: PE)', Icons.accessibility_new_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ClinicalColors.canvasBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClinicalColors.borderLight),
            ),
            child: Column(
              children: [
                _buildPeRow('General', v.peGeneral ?? 'Normal'),
                _buildPeRow('HEENT', v.peHeent ?? 'Normal'),
                _buildPeRow('Heart', v.peHeart ?? 'Normal S1 S2, no murmur'),
                _buildPeRow('Lungs', v.peLungs ?? 'Clear both lungs'),
                _buildPeRow('Abdomen', v.peAbdomen ?? 'Soft, not tender'),
                _buildPeRow('Extremities', v.peExtremities ?? 'No edema'),
                if (v.peNeuro != null && v.peNeuro!.isNotEmpty)
                  _buildPeRow('Neuro', v.peNeuro!),
                if (v.peOther != null && v.peOther!.isNotEmpty)
                  _buildPeRow('Other', v.peOther!),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. การวินิจฉัยโรค (Assessment & Diagnosis)
          _buildSectionHeader('3. การวินิจฉัยโรค (Diagnosis)', Icons.assignment_turned_in_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  v.diagnosisText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                ),
              ),
              if (v.icd10Code != null && v.icd10Code!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'ICD-10: ${v.icd10Code}',
                    style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 5. แผนการรักษาและสั่งยา (Plan & Orders)
          _buildSectionHeader('4. คำสั่งการรักษา & รายการยา (Plan & Prescriptions)', Icons.medication_rounded),
          const SizedBox(height: 10),
          if (v.treatmentPlan != null && v.treatmentPlan!.isNotEmpty)
            _buildInfoRow('คำแนะนำ/แผนการดูแล', v.treatmentPlan!),

          if (v.prescriptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('รายการยาที่สั่งจ่าย (Rx):',
                      style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  for (var item in v.prescriptions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${item['item_name'] ?? item.toString()}',
                          style: const TextStyle(color: ClinicalColors.deepCocoa, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.note_alt_outlined, color: Color(0xFF0284C7), size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              'ยังไม่มีประวัติการตรวจรักษาผู้ป่วยนอก (OPD Visits)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'บันทึกการซักประวัติ ตรวจร่างกาย และสั่งการรักษาของแพทย์ เพื่อเริ่มต้นเวชระเบียน',
              style: TextStyle(fontSize: 13, color: ClinicalColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openNewEncounterDialog(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('บันทึกการตรวจรักษาครั้งแรก', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewEncounterDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OpdEncounterDialog(
        patientId: widget.patientId,
        patientName: widget.patientName,
        sbp: widget.latestSbp,
        dbp: widget.latestDbp,
        pulse: widget.latestPulse,
        onSaved: () {
          ref.invalidate(patientOpdVisitsProvider(widget.patientId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกเวชระเบียนการตรวจรักษา (OPD Visit) สำเร็จ'),
              backgroundColor: ClinicalColors.primaryEmerald,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0284C7)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClinicalColors.deepCocoa)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: ClinicalColors.textPrimary, height: 1.5),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.bold, color: isAlert ? ClinicalColors.criticalRed : ClinicalColors.textMuted),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isAlert ? ClinicalColors.criticalRed : ClinicalColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeRow(String system, String finding) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(system, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ClinicalColors.textMuted)),
          ),
          Expanded(
            child: Text(finding, style: const TextStyle(fontSize: 12, color: ClinicalColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ClinicalColors.canvasBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ClinicalColors.textMuted),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary)),
        ],
      ),
    );
  }
}