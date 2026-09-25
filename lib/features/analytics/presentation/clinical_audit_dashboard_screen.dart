import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/clinical_theme.dart';
import '../../overview/presentation/patient_detail_screen.dart';
import '../data/clinical_audit_repository.dart';

class ClinicalAuditDashboardScreen extends ConsumerWidget {
  const ClinicalAuditDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dqSummaryAsync = ref.watch(dataQualitySummaryProvider);
    final cdssAuditAsync = ref.watch(cdssAuditSummaryProvider);
    final issuesListAsync = ref.watch(dataQualityIssuesProvider);

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ศูนย์ตรวจสอบคุณภาพเวชระเบียน & CDSS Audit',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'กำกับดูแลความสมบูรณ์ของเวชระเบียน และความสอดคล้องตาม Thai HT Guidelines 2024',
                      style: TextStyle(fontSize: 13, color: ClinicalColors.textMuted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(dataQualitySummaryProvider);
                    ref.invalidate(cdssAuditSummaryProvider);
                    ref.invalidate(dataQualityIssuesProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('รีเฟรชข้อมูล'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClinicalColors.surfaceWhite,
                    foregroundColor: ClinicalColors.textPrimary,
                    elevation: 0,
                    side: const BorderSide(color: ClinicalColors.borderLight),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // แถวที่ 1: KPI Cards สรุปข้อมูลตกหล่น & CDSS Compliance
            dqSummaryAsync.when(
              loading: () => const LinearProgressIndicator(color: ClinicalColors.primaryEmerald),
              error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
              data: (dq) => cdssAuditAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (cdss) => LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildKpiCard(
                          title: 'อัตราทำตามแนวทาง (CDSS)',
                          value: '${cdss.adherenceRate}%',
                          subtitle: 'ปฏิบัติตาม ${cdss.guidelineAdherent} จาก ${cdss.totalEvents} ครั้ง',
                          color: const Color(0xFF059669),
                          icon: Icons.verified_rounded,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth,
                        ),
                        _buildKpiCard(
                          title: 'ขาดวัด BP (>30 วัน)',
                          value: '${dq.missingBp30d} คน',
                          subtitle: 'จากคนไข้ทั้งหมด ${dq.totalPatients} คน',
                          color: const Color(0xFFD97706),
                          icon: Icons.access_time_rounded,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth,
                        ),
                        _buildKpiCard(
                          title: 'ขาดผลแล็บประจำปี',
                          value: '${dq.missingAnnualLab} คน',
                          subtitle: 'ไม่มีผลตรวจไต/เบาหวานรอบ 1 ปี',
                          color: const Color(0xFF0284C7),
                          icon: Icons.biotech_rounded,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth,
                        ),
                        _buildKpiCard(
                          title: 'กลุ่มเสี่ยงสูงตกหล่น นัด F/U',
                          value: '${dq.highRiskNoFu} คน',
                          subtitle: 'SBP >= 160 ที่ยังไม่มีใบนัด',
                          color: const Color(0xFFDC2626),
                          icon: Icons.warning_amber_rounded,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),

            // แถวที่ 2: ตารางรายการเคสที่ต้องดำเนินการ (Actionable Quality Issues)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ClinicalColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClinicalColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'รายชื่อผู้ป่วยที่ข้อมูลเวชระเบียนต้องได้รับการติดตาม (Actionable Quality Tasks)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Priority Action Required',
                            style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  issuesListAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
                      ),
                    ),
                    error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
                    data: (issues) {
                      if (issues.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              '🎉 ไม่พบข้อมูลเวชระเบียนตกหล่น การบันทึกเวชระเบียนมีคุณภาพสมบูรณ์ 100%',
                              style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: issues.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: ClinicalColors.borderLight),
                        itemBuilder: (context, index) {
                          final item = issues[index];
                          final isMissingBp = item.issueType == 'MISSING_BP';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            leading: CircleAvatar(
                              backgroundColor: isMissingBp
                                  ? const Color(0xFFD97706).withValues(alpha: 0.12)
                                  : const Color(0xFF0284C7).withValues(alpha: 0.12),
                              child: Icon(
                                isMissingBp ? Icons.monitor_heart_outlined : Icons.biotech_outlined,
                                color: isMissingBp ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(item.patientName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                Text('(HN: ${item.hn})',
                                    style: const TextStyle(color: ClinicalColors.textMuted, fontSize: 12)),
                                const SizedBox(width: 8),
                                if (item.age != null)
                                  Text('อายุ ${item.age} ปี',
                                      style: const TextStyle(color: ClinicalColors.textMuted, fontSize: 12)),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'ข้อสังเกต: ${item.issueDetail}',
                                style: TextStyle(
                                  color: isMissingBp ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ClinicalColors.canvasBg,
                                foregroundColor: ClinicalColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(color: ClinicalColors.borderLight),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailScreen(patientId: item.patientId),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: const Text('เปิดเวชระเบียน', style: TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}