// lib/features/settings/presentation/clinic_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/clinical_theme.dart';
import '../data/clinic_settings_model.dart';
import '../../overview/data/triage_repository.dart';
import '../../overview/presentation/patient_detail_screen.dart';
import '../../analytics/domain/data_quality_rules.dart';

class ClinicSettingsScreen extends ConsumerStatefulWidget {
  const ClinicSettingsScreen({super.key});

  @override
  ConsumerState<ClinicSettingsScreen> createState() => _ClinicSettingsScreenState();
}

class _ClinicSettingsScreenState extends ConsumerState<ClinicSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(currentStaffRoleProvider);
    final config = ref.watch(clinicThresholdConfigProvider);
    final triageAsync = ref.watch(triageOverviewProvider);
    final user = Supabase.instance.client.auth.currentUser;

    final staffEmail = user?.email ?? 'staff@ncds-clinic.moph.go.th';
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        'พยาบาลวิชาชีพเวชปฏิบัติ';

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ตั้งค่าระบบและกำกับดูแลข้อมูล (Settings & Governance)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'จัดการสิทธิ์บุคลากร (RBAC), กำหนดเกณฑ์เฝ้าระวังคลินิก และตรวจสอบความสมบูรณ์ของข้อมูลเวชระเบียน (Protocol 18)',
                        style: TextStyle(fontSize: 12.5, color: ClinicalColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // แถบสลับแท็บ
                  Container(
                    decoration: BoxDecoration(
                      color: ClinicalColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ClinicalColors.borderLight),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: ClinicalColors.primaryEmerald,
                      unselectedLabelColor: ClinicalColors.textMuted,
                      indicatorColor: ClinicalColors.primaryEmerald,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.admin_panel_settings_rounded, size: 18),
                          text: 'กำหนดสิทธิ์และเกณฑ์คลินิก (RBAC & Safety Thresholds)',
                        ),
                        Tab(
                          icon: Icon(Icons.verified_user_rounded, size: 18),
                          text: 'ศูนย์ตรวจสอบคุณภาพข้อมูลเวชระเบียน (Data Quality Center)',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // แท็บที่ 1: RBAC & Safety Thresholds
            _buildSettingsTab(context, ref, staffName, staffEmail, currentRole, config),

            // แท็บที่ 2: Data Quality Center
            _buildDataQualityTab(context, ref, triageAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    WidgetRef ref,
    String staffName,
    String staffEmail,
    StaffRole currentRole,
    ClinicThresholdConfig config,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStaffProfileCard(context, staffName, staffEmail, currentRole),
          const SizedBox(height: 16),
          _buildFacilityInfoCard(context, ref), // 👈 การ์ดแสดงข้อมูล Multi-tenant
          const SizedBox(height: 16),
          _buildRbacRoleSwitcherCard(context, ref, currentRole),
          const SizedBox(height: 16),
          _buildClinicalThresholdCard(context, ref, config, currentRole),
          const SizedBox(height: 16),
          _buildSystemInfoCard(),
        ],
      ),
    );
  }
  Widget _buildFacilityInfoCard(BuildContext context, WidgetRef ref) {
    final facility = ref.watch(currentFacilityProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClinicalColors.totalBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: ClinicalColors.totalBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(facility.hospitalName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                      child: Text('Tenant: ${facility.hospitalId}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ClinicalColors.totalBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('พื้นที่บริการ: อ.${facility.district} จ.${facility.province} | ${facility.healthRegion}', style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
                const SizedBox(height: 2),
                const Text('สถานะความปลอดภัย: บังคับใช้นโยบาย Supabase Multi-tenant RLS Isolation (Protocol 20)', style: TextStyle(fontSize: 11.5, color: ClinicalColors.primaryEmerald, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataQualityTab(BuildContext context, WidgetRef ref, AsyncValue<List<dynamic>> triageAsync) {
    return triageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald)),
      error: (err, _) => Center(child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล: $err', style: const TextStyle(color: ClinicalColors.criticalRed))),
      data: (patients) {
        final audit = DataQualityRules.auditDataQuality(patients.cast());

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Metric Strip คุณภาพข้อมูล
              _buildDataQualityMetricStrip(audit),
              const SizedBox(height: 20),

              // ตารางรายชื่อผู้ป่วยที่มีปัญหาข้อมูล
              _buildDataQualityIssuesTable(context, audit.issueItems),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataQualityMetricStrip(DataQualitySummary audit) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 750;
      final itemWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: itemWidth,
            child: _buildMetricTile(
              'ดัชนีความสมบูรณ์ของข้อมูล',
              '${audit.dataCompletenessRate.toStringAsFixed(1)}%',
              '${audit.totalPatientsAudited - audit.totalIssuesFound}/${audit.totalPatientsAudited} ราย สมบูรณ์ 100%',
              ClinicalColors.normalGreen,
              const Color(0xFFF0FDF4),
              Icons.task_alt_rounded,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _buildMetricTile(
              'ไม่มีเลขประจำตัว (HN)',
              '${audit.missingHnCount} ราย',
              'ต้องระบุ HN เพื่อส่งผลตรวจเข้า HIS',
              ClinicalColors.criticalRed,
              const Color(0xFFFEF2F2),
              Icons.badge_outlined,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _buildMetricTile(
              'สัญญาณชีพผิดปกติรุนแรง',
              '${audit.invalidVitalsCount} ราย',
              'ค่าความดัน/ชีพจรผิดปกติสรีรวิทยา',
              const Color(0xFFD97706),
              const Color(0xFFFFFBEB),
              Icons.warning_amber_rounded,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _buildMetricTile(
              'ไม่มีเบอร์โทรติดต่อ',
              '${audit.missingPhoneCount} ราย',
              'เสี่ยงต่อการขาดการติดต่อ (Lost to F/U)',
              ClinicalColors.totalBlue,
              const Color(0xFFEFF6FF),
              Icons.phone_disabled_rounded,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDataQualityIssuesTable(BuildContext context, List<PatientDataQualityIssue> issues) {
    if (issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: ClinicalColors.surfaceWhite,
          borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
          border: Border.all(color: ClinicalColors.borderLight),
        ),
        child: const Column(
          children: [
            Icon(Icons.verified_rounded, size: 48, color: ClinicalColors.primaryEmerald),
            SizedBox(height: 12),
            Text('เวชระเบียนทั้งหมดมีความสมบูรณ์ถูกต้องตามมาตรฐานคลินิก (100% Quality Passed)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            SizedBox(height: 4),
            Text('ไม่พบข้อมูลขาดตกบกพร่องหรือค่าสัญญาณชีพที่ผิดปกติทางสรีรวิทยา',
                style: TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rule_folder_rounded, color: ClinicalColors.criticalRed, size: 20),
                    const SizedBox(width: 8),
                    Text('รายการเวชระเบียนที่ต้องตรวจสอบและแก้ไข (${issues.length} ราย)',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('คลิกที่ปุ่มตรวจสอบเพื่อเปิด Clinical Workspace',
                    style: TextStyle(fontSize: 11.5, color: ClinicalColors.textMuted.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const Divider(height: 1, color: ClinicalColors.borderLight),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(ClinicalColors.canvasBg),
                columnSpacing: 18,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('ระดับปัญหา', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ชื่อ - นามสกุล', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('HN ปัจจุบัน', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ปัญหาที่ตรวจพบในเวชระเบียน', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('จัดการข้อมูล', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: issues.map((item) {
                  final isCritical = item.severity == DataQualitySeverity.critical;
                  final badgeColor = isCritical ? ClinicalColors.criticalRed : const Color(0xFFD97706);
                  final badgeBg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);

                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(item.severity.code,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
                        ),
                      ),
                      DataCell(
                        Text(item.patient.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      DataCell(
                        Text(item.patient.hn ?? 'ไม่มีเลข HN',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.patient.hn == null ? ClinicalColors.criticalRed : ClinicalColors.textPrimary,
                              fontWeight: item.patient.hn == null ? FontWeight.bold : FontWeight.normal,
                            )),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: item.issues
                                .map((msg) => Text('• $msg',
                                    style: const TextStyle(fontSize: 11.5, color: ClinicalColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis))
                                .toList(),
                          ),
                        ),
                      ),
                      DataCell(
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: ClinicalColors.canvasBg,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PatientDetailScreen(patientId: item.patient.patientId),
                              ),
                            );
                          },
                          child: const Text('ตรวจสอบเวชระเบียน', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, String subtitle, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildStaffProfileCard(BuildContext context, String name, String email, StaffRole role) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: ClinicalColors.primaryEmerald.withValues(alpha: 0.12),
            child: const Icon(Icons.person_rounded, color: ClinicalColors.primaryEmerald, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ClinicalColors.primaryEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role.roleCode,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClinicalColors.primaryEmerald),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('อีเมลบุคลากร: $email', style: const TextStyle(fontSize: 12.5, color: ClinicalColors.textMuted)),
                const SizedBox(height: 2),
                const Text('หน่วยงาน: ศูนย์สั่งการและติดตามคลินิกโรคไม่ติดต่อเรื้อรัง (NCDs Command Center)',
                    style: TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRbacRoleSwitcherCard(BuildContext context, WidgetRef ref, StaffRole currentRole) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: ClinicalColors.totalBlue, size: 20),
              SizedBox(width: 8),
              Text('กำหนดสิทธิ์และมุมมองตามบทบาท (Role-Based Access Control)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'เลือกสลับบทบาทเพื่อตรวจสอบมุมมองการทำงานและขอบเขตการปฏิบัติงานของบุคลากรแต่ละตำแหน่ง',
            style: TextStyle(fontSize: 12, color: ClinicalColors.textMuted),
          ),
          const SizedBox(height: 16),
          ...StaffRole.values.map((role) {
            final isSelected = currentRole == role;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : ClinicalColors.canvasBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? ClinicalColors.totalBlue : ClinicalColors.borderLight,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                leading: Radio<StaffRole>(
                  value: role,
                  groupValue: currentRole,
                  activeColor: ClinicalColors.totalBlue,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(currentStaffRoleProvider.notifier).state = val;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('สลับมุมมองสิทธิ์เป็น: ${role.roleName}'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: ClinicalColors.primaryEmerald,
                        ),
                      );
                    }
                  },
                ),
                title: Text(role.roleName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13.5)),
                subtitle: Text(role.description, style: const TextStyle(fontSize: 11.5, color: ClinicalColors.textMuted)),
                trailing: isSelected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: ClinicalColors.totalBlue, borderRadius: BorderRadius.circular(6)),
                        child: const Text('บทบาทปัจจุบัน', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    : null,
                onTap: () {
                  ref.read(currentStaffRoleProvider.notifier).state = role;
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClinicalThresholdCard(
    BuildContext context,
    WidgetRef ref,
    ClinicThresholdConfig config,
    StaffRole currentRole,
  ) {
    final isDirector = currentRole == StaffRole.director;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
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
                  Icon(Icons.tune_rounded, color: ClinicalColors.primaryEmerald, size: 20),
                  SizedBox(width: 8),
                  Text('เกณฑ์เฝ้าระวังทางคลินิก (Clinical Safety Thresholds)',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                ],
              ),
              if (!isDirector)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                  child: const Text('เฉพาะผู้บริหารคลินิกที่แก้ไขได้ (Read-only)',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'กำหนดพารามิเตอร์ตรวจจับความดันวิกฤต, ภาวะความดันตกจากการรักษา และเกณฑ์วัดผล Lost to Follow-up',
            style: TextStyle(fontSize: 12, color: ClinicalColors.textMuted),
          ),
          const SizedBox(height: 16),
          _buildThresholdRow(
            title: 'เกณฑ์ความดันวิกฤต (Crisis BP Threshold)',
            value: 'SYS ≥ ${config.crisisSystolic} หรือ DIA ≥ ${config.crisisDiastolic} mmHg',
            hint: 'มาตรฐาน: 180/110 mmHg เข้าสู่คิวงานเร่งด่วนทันที',
            icon: Icons.crisis_alert_rounded,
            color: ClinicalColors.criticalRed,
          ),
          const Divider(height: 20, color: ClinicalColors.canvasBg),
          _buildThresholdRow(
            title: 'เกณฑ์ความดันต่ำเฝ้าระวัง (Over-treatment Low BP)',
            value: 'SYS < ${config.lowSystolicThreshold} หรือ DIA < ${config.lowDiastolicThreshold} mmHg',
            hint: 'ตรวจจับร่วมกับประวัติการได้รับยาความดัน (p.hasMedication)',
            icon: Icons.medication_liquid_rounded,
            color: const Color(0xFF6366F1),
          ),
          const Divider(height: 20, color: ClinicalColors.canvasBg),
          _buildThresholdRow(
            title: 'เกณฑ์ขาดการติดต่อ (Lost to Follow-up Horizon)',
            value: 'ไม่บันทึกความดันเกิน ${config.lostToFollowUpDays} วัน',
            hint: 'คำนวณจาก p.lastBpDate เทียบกับวันปัจจุบัน',
            icon: Icons.person_off_rounded,
            color: ClinicalColors.lostToFollowUpOrange,
          ),
          const Divider(height: 20, color: ClinicalColors.canvasBg),
          _buildThresholdRow(
            title: 'เป้าหมายอัตราควบคุมความดันคลินิก (BP Control Target Rate)',
            value: '≥ ${config.targetBpControlRate.toStringAsFixed(0)}% ของผู้ป่วยทั้งหมด',
            hint: 'ตัวชี้วัดประสิทธิภาพคลินิก NCD คุณภาพ',
            icon: Icons.check_circle_rounded,
            color: ClinicalColors.normalGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdRow({
    required String title,
    required String value,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(hint, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
            ],
          ),
        ),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: ClinicalColors.textMuted),
              SizedBox(width: 8),
              Text('NCDs Clinical Command Center Web App (PWA)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary)),
            ],
          ),
          Text('Protocol Version: TH-HT-2024.1 | Build: 2026.09-Final',
              style: TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
        ],
      ),
    );
  }
}