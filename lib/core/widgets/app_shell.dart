// lib/core/widgets/app_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/communication/presentation/communication_center_screen.dart';
import '../../features/overview/data/patient_triage_model.dart';
import '../../features/overview/data/triage_repository.dart'
    hide TriageCategory;
import '../../features/overview/presentation/overview_screen.dart';
import '../../features/overview/presentation/patient_detail_screen.dart';
import '../../features/triage/domain/triage_rules.dart';
import '../../features/analytics/presentation/population_analytics_screen.dart';
import '../../features/followup/presentation/follow_up_management_screen.dart';
import '../constants/clinical_theme.dart';
import '../utils/export_util.dart';
import '../../features/settings/data/clinic_settings_model.dart';
import '../../features/settings/presentation/clinic_settings_screen.dart';
import '../../features/cdss/presentation/cdss_data_entry_screen.dart';
import '../../features/patient_registry/presentation/widgets/patient_registration_dialog.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _menuItems = [
    (label: 'ภาพรวม (Command Center)', icon: Icons.dashboard_rounded),
    (label: 'คัดกรองด่วน (Urgent Triage)', icon: Icons.flash_on_rounded),
    (label: 'ทะเบียนผู้ป่วย (Registry)', icon: Icons.groups_rounded),
    (label: 'บันทึกข้อมูล CDSS', icon: Icons.assignment_rounded),
    (label: 'รายงานและสถิติ (Population)', icon: Icons.bar_chart_rounded),
    (label: 'จัดการยา-นัดหมาย', icon: Icons.event_note_rounded),
    (label: 'สื่อสารผู้ป่วย', icon: Icons.chat_bubble_rounded),
    (label: 'ตั้งค่าระบบ', icon: Icons.settings_rounded),
  ];

  final _searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectMenu(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0 || index == 2) {
      ref.read(selectedStatusFilterProvider.notifier).state = 'ALL';
    } else if (index == 1) {
      ref.read(selectedStatusFilterProvider.notifier).state = 'CRITICAL';
    }

    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).maybePop();
    }
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const OverviewScreen(); // 1. หน้าภาพรวม Command Center
      case 1:
        return const UrgentTriageView(); // 2. หน้าคัดกรองเคสด่วนโดยเฉพาะ
      case 2:
        return const PatientRegistryView(); // 3. หน้าทะเบียนรายชื่อผู้ป่วยโดยเฉพาะ
      case 3:
        return const CdssDataEntryScreen(); // บันทึกข้อมูลและประเมินผล CDSS
      case 4:
        return const PopulationAnalyticsScreen(); // 4. หน้าสถิติและประชากร
      case 5:
        return const FollowUpManagementScreen(); // 5. หน้าจัดการยาและนัดหมายติดตามอาการ
      case 6:
        return const CommunicationCenterScreen(); // 6. หน้าสื่อสารผู้ป่วย
      case 7:
        return const ClinicSettingsScreen(); // เมนูตั้งค่าระบบและกำหนดสิทธิ์
      default:
        return ClinicalWorkspacePlaceholder(
          featureName: _menuItems[_selectedIndex].label,
          icon: _menuItems[_selectedIndex].icon,
          onBackToOverview: () => _selectMenu(0),
        );
    }
  }

  Widget _buildSidebar() {
    return ColoredBox(
      color: ClinicalColors.sidebarGradientEnd,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ClinicalColors.sidebarGradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Color(0xFFDCFCE7)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.monitor_heart_rounded,
                            color: ClinicalColors.sidebarGradientStart,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'NCDs Care\nPlatform',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 2. 🟢 เพิ่มปุ่ม Quick Action "ลงทะเบียนผู้ป่วยใหม่" เด่นชัดใน Sidebar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (MediaQuery.sizeOf(context).width < 900) {
                          Navigator.of(context)
                              .maybePop(); // ปิด Drawer บนมือถือ
                        }
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => const PatientRegistrationDialog(),
                        );
                      },
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'ลงทะเบียนผู้ป่วยใหม่',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ClinicalColors.sidebarGradientStart,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  for (var index = 0; index < _menuItems.length; index++)
                    _buildMenuItem(index),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Text(
                      'NCDs Clinical Monitoring V3',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(int index) {
    final item = _menuItems[index];
    final selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _selectMenu(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.96)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.7))
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected
                        ? ClinicalColors.primaryEmerald
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  item.icon,
                  color: selected
                      ? ClinicalColors.sidebarGradientStart
                      : Colors.white.withValues(alpha: 0.62),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? ClinicalColors.sidebarGradientStart
                          : Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final activeRole = ref.watch(currentStaffRoleProvider);
    final facility = ref.watch(currentFacilityProvider);
    final patients =
        ref.watch(triageOverviewProvider).asData?.value ??
        const <PatientTriageModel>[];
    final criticalCount = patients.where((patient) {
      final category = TriageRules.evaluateTriage(
        systolic: patient.systolic ?? 0,
        diastolic: patient.diastolic ?? 0,
        triageStatus: patient.triageStatus,
        hasMeds: patient.hasMedication,
      );
      return category == TriageCategory.critical;
    }).length;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'เปิดเมนู',
              ),
            ),
          if (isMobile) const SizedBox(width: 4),
          if (!isMobile)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ศูนย์สั่งการคลินิก NCDs',
                  style: TextStyle(
                    color: ClinicalColors.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${facility.hospitalName} (${facility.hospitalId})',
                  style: const TextStyle(
                    color: ClinicalColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          if (!isMobile) const SizedBox(width: 24),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: ClinicalColors.canvasBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ClinicalColors.borderLight),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(searchQueryProvider.notifier).state = value,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อผู้ป่วย หรือ HN...',
                    hintStyle: TextStyle(
                      color: ClinicalColors.textMuted.withValues(alpha: 0.8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: ClinicalColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: 'ล้างการค้นหา',
                          ),
                    filled: false,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: ClinicalColors.canvasBg,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _selectMenu(1),
                  icon: const Icon(Icons.notifications_none_rounded, size: 21),
                  tooltip: 'ดูเคสวิกฤตด่วน',
                ),
              ),
              if (criticalCount > 0)
                Positioned(
                  right: 3,
                  top: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ClinicalColors.criticalRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: ClinicalColors.coloredGlow(
                        ClinicalColors.criticalRed,
                      ),
                    ),
                    child: Text(
                      '$criticalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  ClinicalColors.primaryEmerald,
                  ClinicalColors.sidebarGradientStart,
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(
                activeRole == StaffRole.physician
                    ? 'MD'
                    : (activeRole == StaffRole.director ? 'DIR' : 'NS'),
                style: const TextStyle(
                  color: ClinicalColors.primaryEmerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      drawer: isMobile ? Drawer(width: 280, child: _buildSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) SizedBox(width: 248, child: _buildSidebar()),
          Expanded(
            child: Column(
              children: [
                _buildHeader(isMobile),
                Expanded(child: _buildSelectedPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 1. หน้าคัดกรองด่วน (Urgent Triage Action Queue) - เฉพาะเคสวิกฤต/ความดันตก
// ==============================================================================
class UrgentTriageView extends ConsumerWidget {
  const UrgentTriageView({super.key});

  TriageCategory _getCategory(PatientTriageModel p) {
    final hasMeds = TriageRules.isPatientMedicated(
      triageStatus: p.triageStatus,
      hasMedication: p.hasMedication,
    );
    return TriageRules.evaluateTriage(
      systolic: p.systolic ?? 0,
      diastolic: p.diastolic ?? 0,
      triageStatus: p.triageStatus,
      hasMeds: hasMeds,
    );
  }

  Future<void> _callPatient(BuildContext context, String phone) async {
    final launched = await launchUrl(Uri.parse('tel:${phone.trim()}'));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดการโทรจากอุปกรณ์นี้ได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triageAsync = ref.watch(triageOverviewProvider);

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: triageAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: ClinicalColors.primaryEmerald,
          ),
        ),
        error: (err, _) => Center(
          child: Text(
            'เกิดข้อผิดพลาด: $err',
            style: const TextStyle(color: ClinicalColors.criticalRed),
          ),
        ),
        data: (allPatients) {
          final criticalCases = allPatients
              .where((p) => _getCategory(p) == TriageCategory.critical)
              .toList();
          final overTreatmentCases = allPatients
              .where((p) => _getCategory(p) == TriageCategory.overTreatment)
              .toList();
          final urgentList = [...criticalCases, ...overTreatmentCases];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คิวงานคัดกรองด่วน (Urgent Triage & Crisis Action Queue)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClinicalColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'รายการผู้ป่วยความดันวิกฤต (BP ≥ 180) และความดันตกจากการรักษา (Over-treatment)',
                          style: TextStyle(
                            fontSize: 13,
                            color: ClinicalColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ClinicalColors.primaryEmerald,
                      ),
                      onPressed: () => ref.refresh(triageOverviewProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('อัปเดตคิวงาน'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBadge(
                        'วิกฤต BP สูง (≥180/110)',
                        '${criticalCases.length} ราย',
                        ClinicalColors.criticalRed,
                        ClinicalColors.criticalBg,
                        Icons.crisis_alert_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricBadge(
                        'ความดันตก (Over-Tx)',
                        '${overTreatmentCases.length} ราย',
                        const Color(0xFF6366F1),
                        const Color(0xFFEEF2FF),
                        Icons.medication_liquid_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (urgentList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: ClinicalColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ClinicalColors.borderLight),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 48,
                          color: ClinicalColors.primaryEmerald,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'ไม่พบเคสวิกฤตหรือความดันตกที่ต้องดำเนินการด่วนในขณะนี้',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ผู้ป่วยในทะเบียนทุกคนอยู่ในเกณฑ์ควบคุมได้หรือได้รับการดูแลเรียบร้อยแล้ว',
                          style: TextStyle(
                            color: ClinicalColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...urgentList.map((patient) {
                    final category = _getCategory(patient);
                    final isCritical = category == TriageCategory.critical;
                    final cardColor = isCritical
                        ? ClinicalColors.criticalRed
                        : const Color(0xFF6366F1);
                    final initials = patient.fullName.trim().isEmpty
                        ? '?'
                        : patient.fullName
                              .trim()
                              .characters
                              .first
                              .toUpperCase();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClinicalColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cardColor.withValues(alpha: 0.25),
                        ),
                        boxShadow: ClinicalColors.softShadow,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: cardColor.withValues(alpha: 0.15),
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cardColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      patient.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCritical
                                            ? ClinicalColors.criticalBg
                                            : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isCritical
                                            ? '🚨 วิกฤต BP สูง'
                                            : '⚠️ ความดันตก (Over-Tx)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: cardColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'HN: ${patient.hn ?? "-"} | ความดันล่าสุด: ${patient.systolic ?? "-"}/${patient.diastolic ?? "-"} mmHg | ชีพจร: ${patient.pulse ?? "-"} bpm',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ClinicalColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'รับทราบเคสและเริ่มกระบวนการติดตามเรียบร้อยแล้ว',
                                      ),
                                      backgroundColor:
                                          ClinicalColors.primaryEmerald,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF3C7),
                                  foregroundColor: const Color(0xFF92400E),
                                ),
                                child: const Text(
                                  'รับเคส (Ack)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailScreen(
                                      patientId: patient.patientId,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.monitor_heart_outlined,
                                  size: 15,
                                ),
                                label: const Text('ดูชาร์ต'),
                              ),
                              FilledButton.icon(
                                onPressed:
                                    patient.phone == null ||
                                        patient.phone!.trim().isEmpty
                                    ? null
                                    : () =>
                                          _callPatient(context, patient.phone!),
                                style: FilledButton.styleFrom(
                                  backgroundColor: ClinicalColors.criticalRed,
                                ),
                                icon: const Icon(Icons.call_rounded, size: 15),
                                label: const Text('โทรด่วน'),
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
        },
      ),
    );
  }

  Widget _buildMetricBadge(
    String label,
    String value,
    Color color,
    Color bg,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 2. หน้าทะเบียนผู้ป่วย (Patient Registry) - ค้นหา คัดกรอง และดูตารางผู้ป่วยทั้งหมด
// ==============================================================================
class PatientRegistryView extends ConsumerWidget {
  const PatientRegistryView({super.key});

  TriageCategory _getCategory(PatientTriageModel p) {
    final hasMeds = TriageRules.isPatientMedicated(
      triageStatus: p.triageStatus,
      hasMedication: p.hasMedication,
    );
    return TriageRules.evaluateTriage(
      systolic: p.systolic ?? 0,
      diastolic: p.diastolic ?? 0,
      triageStatus: p.triageStatus,
      hasMeds: hasMeds,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triageAsync = ref.watch(triageOverviewProvider);
    final selectedFilter = ref.watch(selectedStatusFilterProvider);
    final searchQuery = ref.watch(searchQueryProvider).trim().toLowerCase();

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: triageAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: ClinicalColors.primaryEmerald,
          ),
        ),
        error: (err, _) => Center(
          child: Text(
            'เกิดข้อผิดพลาด: $err',
            style: const TextStyle(color: ClinicalColors.criticalRed),
          ),
        ),
        data: (allPatients) {
          final displayPatients = allPatients.where((p) {
            final matchesQuery =
                searchQuery.isEmpty ||
                p.fullName.toLowerCase().contains(searchQuery) ||
                (p.hn != null && p.hn!.toLowerCase().contains(searchQuery));

            if (!matchesQuery) return false;

            final category = _getCategory(p);
            switch (selectedFilter) {
              case 'CRITICAL':
                return category == TriageCategory.critical;
              case 'OVER_TREATMENT':
                return category == TriageCategory.overTreatment;
              case 'HYPOTENSION':
                return category == TriageCategory.hypotension;
              case 'WARNING':
                return category == TriageCategory.warning;
              case 'NORMAL':
                return category == TriageCategory.normal;
              case 'ALL':
              default:
                return true;
            }
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ทะเบียนรายชื่อผู้ป่วย (Patient Registry)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClinicalColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'รายชื่อผู้ป่วยทั้งหมดในความดูแล (${displayPatients.length} / ${allPatients.length} ราย)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ClinicalColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ClinicalColors.primaryEmerald,
                        side: const BorderSide(
                          color: ClinicalColors.primaryEmerald,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: displayPatients.isEmpty
                          ? null
                          : () => ExportUtil.exportPatientListToCsv(
                              displayPatients,
                            ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text(
                        'ส่งออก CSV',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      ref,
                      'ทั้งหมด (${allPatients.length})',
                      'ALL',
                      selectedFilter,
                    ),
                    _buildFilterChip(
                      ref,
                      'วิกฤต',
                      'CRITICAL',
                      selectedFilter,
                      activeColor: ClinicalColors.criticalRed,
                    ),
                    _buildFilterChip(
                      ref,
                      'ความดันตก (Over-Tx)',
                      'OVER_TREATMENT',
                      selectedFilter,
                      activeColor: const Color(0xFF6366F1),
                    ),
                    _buildFilterChip(
                      ref,
                      'ความดันต่ำทั่วไป',
                      'HYPOTENSION',
                      selectedFilter,
                      activeColor: const Color(0xFF0284C7),
                    ),
                    _buildFilterChip(
                      ref,
                      'เฝ้าระวัง',
                      'WARNING',
                      selectedFilter,
                      activeColor: ClinicalColors.warningOrange,
                    ),
                    _buildFilterChip(
                      ref,
                      'ปกติ',
                      'NORMAL',
                      selectedFilter,
                      activeColor: ClinicalColors.normalGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: ClinicalColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ClinicalColors.borderLight),
                  ),
                  child: displayPatients.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'ไม่พบข้อมูลผู้ป่วยที่ตรงกับเงื่อนไขการค้นหา',
                              style: TextStyle(color: ClinicalColors.textMuted),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 800),
                            child: DataTable(
                              columnSpacing: 24,
                              horizontalMargin: 20,
                              showCheckboxColumn: false,
                              headingRowColor: WidgetStateProperty.all(
                                ClinicalColors.canvasBg,
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'HN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ชื่อ - นามสกุล',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ความดันล่าสุด',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ชีพจร',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'น้ำตาล FBS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'สถานะคัดกรอง',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: displayPatients.map((p) {
                                final sbp = p.systolic ?? 0;
                                final dbp = p.diastolic ?? 0;
                                final category = _getCategory(p);

                                Color bpColor = ClinicalColors.textPrimary;
                                if (category == TriageCategory.critical) {
                                  bpColor = ClinicalColors.criticalRed;
                                } else if (category ==
                                    TriageCategory.overTreatment) {
                                  bpColor = const Color(0xFF6366F1);
                                } else if (category ==
                                    TriageCategory.hypotension) {
                                  bpColor = const Color(0xFF0284C7);
                                }

                                return DataRow(
                                  onSelectChanged: (_) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PatientDetailScreen(
                                          patientId: p.patientId,
                                        ),
                                      ),
                                    );
                                  },
                                  cells: [
                                    DataCell(Text(p.hn ?? '-')),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 180,
                                        ),
                                        child: Text(
                                          p.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        p.systolic != null
                                            ? '$sbp/$dbp mmHg'
                                            : '-',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: bpColor,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        p.pulse != null
                                            ? '${p.pulse} bpm'
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        p.fbs != null ? '${p.fbs} mg/dL' : '-',
                                      ),
                                    ),
                                    DataCell(_buildStatusBadge(p)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    WidgetRef ref,
    String label,
    String value,
    String currentSelected, {
    Color? activeColor,
  }) {
    final isSelected = currentSelected == value;
    final color = activeColor ?? ClinicalColors.primaryEmerald;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : ClinicalColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: ClinicalColors.surfaceWhite,
      showCheckmark: false,
      side: BorderSide(color: isSelected ? color : ClinicalColors.borderLight),
      onSelected: (_) =>
          ref.read(selectedStatusFilterProvider.notifier).state = value,
    );
  }

  Widget _buildStatusBadge(PatientTriageModel p) {
    final category = _getCategory(p);
    Color bg;
    Color text;
    String label;
    Border? border;

    switch (category) {
      case TriageCategory.critical:
        bg = ClinicalColors.criticalBg;
        text = ClinicalColors.criticalRed;
        label = '🚨 วิกฤต BP สูง';
        break;
      case TriageCategory.overTreatment:
        bg = const Color(0xFFEEF2FF);
        text = const Color(0xFF6366F1);
        label = '⚠️ ความดันตก (Over-Tx)';
        border = Border.all(color: const Color(0xFFC7D2FE));
        break;
      case TriageCategory.hypotension:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0284C7);
        label = '💧 ความดันต่ำ (Naïve)';
        border = Border.all(color: const Color(0xFFBAE6FD));
        break;
      case TriageCategory.warning:
        bg = ClinicalColors.warningBg;
        text = ClinicalColors.warningOrange;
        label = 'เฝ้าระวัง';
        break;
      case TriageCategory.normal:
        bg = ClinicalColors.normalBg;
        text = ClinicalColors.normalGreen;
        label = 'ปกติ';
        break;
      case TriageCategory.insufficientData:
        bg = ClinicalColors.warningBg;
        text = ClinicalColors.warningOrange;
        label = 'ข้อมูลไม่ครบ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ==============================================================================
// 3. การ์ดแสดงผลสำหรับเมนูที่กำลังขยายผลในขั้นต่อไป
// ==============================================================================
class ClinicalWorkspacePlaceholder extends StatelessWidget {
  final String featureName;
  final IconData icon;
  final VoidCallback onBackToOverview;

  const ClinicalWorkspacePlaceholder({
    required this.featureName,
    required this.icon,
    required this.onBackToOverview,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ClinicalColors.surfaceWhite,
          borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
          border: Border.all(color: ClinicalColors.borderLight),
          boxShadow: ClinicalColors.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClinicalColors.primaryEmerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ClinicalColors.primaryEmerald, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              featureName,
              style: const TextStyle(
                color: ClinicalColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'โมดูลนี้พร้อมเชื่อมโยงเข้ากับระบบบันทึกและระบบฐานข้อมูล รพ.สต. ในขั้นตอนต่อไป',
              style: TextStyle(
                color: ClinicalColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ClinicalColors.primaryEmerald,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: onBackToOverview,
              icon: const Icon(Icons.dashboard_rounded, size: 16),
              label: const Text('กลับสู่หน้าภาพรวม (Overview)'),
            ),
          ],
        ),
      ),
    );
  }
}
