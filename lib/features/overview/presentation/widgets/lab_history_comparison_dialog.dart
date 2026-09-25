import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/clinical_theme.dart';
import '../../../../core/widgets/resizable_clinical_dialog.dart';
import '../../data/clinical_entry_repository.dart';

class LabHistoryComparisonDialog extends ConsumerWidget {
  final String patientId;
  final String patientName;
  final String hn;

  const LabHistoryComparisonDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.hn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labHistoryAsync = ref.watch(patientLabHistoryProvider(patientId));

    return ResizableClinicalDialog(
      startMaximized: true,
      minWidth: 850,
      minHeight: 550,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ประวัติและตารางเปรียบเทียบผลแล็บย้อนหลัง (Lab History & Trends)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'ผู้ป่วย: $patientName | HN: $hn',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              tooltip: 'รีเฟรชข้อมูล',
              onPressed: () => ref.invalidate(patientLabHistoryProvider(patientId)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
        ),
        body: labHistoryAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('เกิดข้อผิดพลาดในการโหลดผลแล็บ: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
          data: (labs) {
            if (labs.isEmpty) {
              return const Center(
                child: Text('ยังไม่มีประวัติการบันทึกผลแล็บของผู้ป่วยรายนี้', style: TextStyle(color: Color(0xFF64748B))),
              );
            }

            final dates = labs.map((l) => l['lab_date']?.toString() ?? '-').toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        const Text(
                          'ค่าที่แสดงแถบสีแดง หมายถึง มีค่าเกินหรือต่ำกว่าเกณฑ์มาตรฐาน (Abnormal Reference Range)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        const Spacer(),
                        Text(
                          'ตรวจทั้งหมด: ${labs.length} ครั้ง',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                        columnSpacing: 28,
                        horizontalMargin: 16,
                        columns: [
                          const DataColumn(
                            label: Text(
                              'รายการตรวจ (Test / Unit)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          ...dates.asMap().entries.map((entry) {
                            final isLatest = entry.key == 0;
                            return DataColumn(
                              label: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isLatest ? const Color(0xFF059669) : const Color(0xFF334155),
                                    ),
                                  ),
                                  if (isLatest)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ล่าสุด',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                        rows: [
                          _buildSectionRow('1. กลุ่มควบคุมระดับน้ำตาล (Glycemic Control)', dates.length),
                          _buildDataRow('FBS (mg/dL)', 'fbs', labs, warnHigh: 126),
                          _buildDataRow('HbA1c (%)', 'hba1c', labs, warnHigh: 7.0),
                          _buildSectionRow('2. กลุ่มไขมันในเลือด (Lipid Profile)', dates.length),
                          _buildDataRow('Total Cholesterol (mg/dL)', 'cholesterol', labs, warnHigh: 200),
                          _buildDataRow('Triglycerides (mg/dL)', 'triglycerides', labs, warnHigh: 150),
                          _buildDataRow('HDL-C (mg/dL)', 'hdl', labs, warnLow: 40),
                          _buildDataRow('LDL-C (mg/dL)', 'ldl', labs, warnHigh: 100),
                          _buildSectionRow('3. การทำงานของไต & เกลือแร่ (Renal & Electrolytes)', dates.length),
                          _buildDataRow('BUN (mg/dL)', 'bun', labs, warnHigh: 20),
                          _buildDataRow('Creatinine (mg/dL)', 'creatinine', labs, warnHigh: 1.2),
                          _buildDataRow('eGFR (ml/min/1.73m²)', 'egfr', labs, warnLow: 60),
                          _buildDataRow('Sodium: Na+ (mEq/L)', 'sodium', labs, warnLow: 135, warnHigh: 145),
                          _buildDataRow('Potassium: K+ (mEq/L)', 'potassium', labs, warnLow: 3.5, warnHigh: 5.0),
                          _buildDataRow('Chloride: Cl- (mEq/L)', 'chloride', labs),
                          _buildDataRow('Bicarbonate: HCO3- (mEq/L)', 'bicarbonate', labs, warnLow: 22),
                          _buildSectionRow('4. การทำงานของตับ & ยูริก (Liver & Uric)', dates.length),
                          _buildDataRow('AST / SGOT (U/L)', 'ast', labs, warnHigh: 40),
                          _buildDataRow('ALT / SGPT (U/L)', 'alt', labs, warnHigh: 40),
                          _buildDataRow('ALP (U/L)', 'alp', labs, warnHigh: 120),
                          _buildDataRow('Uric Acid (mg/dL)', 'uric_acid', labs, warnHigh: 7.0),
                          _buildSectionRow('5. ตรวจปัสสาวะ & โปรตีนรั่ว (Urinalysis)', dates.length),
                          _buildDataRow('UACR (mg/g Cr)', 'urine_microalbumin', labs, warnHigh: 30),
                          _buildDataRow('Urine Protein', 'urine_protein', labs),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  DataRow _buildSectionRow(String title, int datesCount) {
    return DataRow(
      color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
      cells: [
        DataCell(
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0369A1), fontSize: 13),
          ),
        ),
        ...List.generate(datesCount, (_) => const DataCell(SizedBox.shrink())),
      ],
    );
  }

  DataRow _buildDataRow(
    String label,
    String fieldKey,
    List<Map<String, dynamic>> labs, {
    double? warnHigh,
    double? warnLow,
  }) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
          ),
        ),
        ...labs.map((lab) {
          final raw = lab[fieldKey];
          if (raw == null || raw.toString().trim().isEmpty) {
            return const DataCell(
              Center(
                child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            );
          }

          final numVal = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString());
          bool isAbnormal = false;
          if (numVal != null) {
            if (warnHigh != null && numVal > warnHigh) isAbnormal = true;
            if (warnLow != null && numVal < warnLow) isAbnormal = true;
          }

          return DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isAbnormal ? const Color(0xFFFEF2F2) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isAbnormal ? Border.all(color: const Color(0xFFFCA5A5)) : null,
              ),
              child: Text(
                raw.toString(),
                style: TextStyle(
                  fontWeight: isAbnormal ? FontWeight.bold : FontWeight.w500,
                  color: isAbnormal ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}