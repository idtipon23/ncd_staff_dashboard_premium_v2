// lib/features/overview/presentation/overview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/clinical_theme.dart';
import '../../../core/utils/sound_util.dart';
import '../data/patient_triage_model.dart';
import '../data/triage_repository.dart' hide TriageCategory;
import 'patient_detail_screen.dart';
import '../../../core/utils/export_util.dart';
import '../../../services/ht_cdss_engine.dart';
import '../../triage/domain/triage_rules.dart' as triage_rules;
// เพิ่ม Import ด้านบนของ overview_screen.dart
import '../../analytics/domain/population_kpi_rules.dart';

// 1. เพิ่ม Enum ควบคุมโหมดมุมมอง
enum OverviewViewMode { dashboard, urgentTriage, patientRegistry }

class OverviewScreen extends ConsumerStatefulWidget {
  final OverviewViewMode viewMode;

  const OverviewScreen({super.key, this.viewMode = OverviewViewMode.dashboard});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  RealtimeChannel? _realtimeChannel;
  final _overviewSearchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtimeSubscription();
    });
  }

  void _initRealtimeSubscription() {
    final repo = ref.read(triageRepositoryProvider);
    _realtimeChannel = repo.listenToCriticalVitals(
      onCriticalEvent: (vital) {
        SoundUtil.playUrgentBeep();
        ref.invalidate(triageOverviewProvider);

        if (mounted) {
          final sys = vital['systolic'];
          final dia = vital['diastolic'];
          final isLow = (sys != null && (sys as num) < 90);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isLow
                        ? Icons.medication_liquid_rounded
                        : Icons.warning_amber_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isLow
                          ? 'แจ้งเตือนด่วน: พบผู้ป่วยความดันตก ($sys/$dia mmHg) บันทึกเข้ามาใหม่!'
                          : 'แจ้งเตือนด่วน: พบผู้ป่วยความดันวิกฤต ($sys/$dia mmHg) ถูกบันทึกเข้ามาใหม่!',
                    ),
                  ),
                ],
              ),
              backgroundColor: isLow
                  ? const Color(0xFF6366F1)
                  : ClinicalColors.criticalRed,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _overviewSearchFocusNode.dispose();
    super.dispose();
  }

  /// ประเมิน Triage ผ่านกฎกลางของ Domain Layer
  triage_rules.TriageCategory _getCategory(PatientTriageModel p) {
    return triage_rules.TriageRules.evaluateTriage(
      systolic: p.systolic ?? 0,
      diastolic: p.diastolic ?? 0,
      triageStatus: p.triageStatus,
      hasMeds: p.hasMedication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final triageAsync = ref.watch(triageOverviewProvider);
    final activityAsync = ref.watch(recentActivityProvider);
    final aggregateBpAsync = ref.watch(aggregateBpTrendProvider);
    final selectedFilter = ref.watch(selectedStatusFilterProvider);
    final searchQuery = ref.watch(searchQueryProvider).trim().toLowerCase();

    // ปรับเปลี่ยนชื่อแถบด้านบน (AppBar Title) ให้ตรงตามเมนูที่กำลังเปิด
    String pageTitle;
    IconData pageIcon;
    Color iconColor;

    switch (widget.viewMode) {
      case OverviewViewMode.dashboard:
        pageTitle = 'NCDs Clinical Command Center — ภาพรวมศูนย์สั่งการ';
        pageIcon = Icons.monitor_heart;
        iconColor = ClinicalColors.primaryEmerald;
        break;
      case OverviewViewMode.urgentTriage:
        pageTitle = 'Urgent Action Queue — คัดกรองด่วนผู้ป่วยวิกฤต';
        pageIcon = Icons.warning_amber_rounded;
        iconColor = ClinicalColors.criticalRed;
        break;
      case OverviewViewMode.patientRegistry:
        pageTitle = 'Patient Registry — ทะเบียนและประวัติผู้ป่วยทั้งหมด';
        pageIcon = Icons.groups_rounded;
        iconColor = ClinicalColors.primaryEmerald;
        break;
    }

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      appBar: AppBar(
        backgroundColor: ClinicalColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: ClinicalColors.borderLight),
        ),
        title: Row(
          children: [
            Icon(pageIcon, color: iconColor, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pageTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ClinicalColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(triageOverviewProvider),
            icon: const Icon(Icons.refresh, color: ClinicalColors.textMuted),
            tooltip: 'รีเฟรชข้อมูล',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: triageAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: ClinicalColors.primaryEmerald,
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'เกิดข้อผิดพลาดในการโหลดข้อมูล: $err',
              style: const TextStyle(color: ClinicalColors.criticalRed),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allPatients) {
          final qualityKpi = ref.watch(populationQualityKpiProvider);
          final criticalCases = allPatients
              .where(
                (p) => _getCategory(p) == triage_rules.TriageCategory.critical,
              )
              .toList();
          final overTreatmentCases = allPatients
              .where(
                (p) =>
                    _getCategory(p) ==
                    triage_rules.TriageCategory.overTreatment,
              )
              .toList();
          final warningCases = allPatients
              .where(
                (p) => _getCategory(p) == triage_rules.TriageCategory.warning,
              )
              .toList();
          final normalCases = allPatients
              .where(
                (p) => _getCategory(p) == triage_rules.TriageCategory.normal,
              )
              .toList();
          final insufficientDataCases = allPatients
              .where(
                (p) =>
                    _getCategory(p) ==
                    triage_rules.TriageCategory.insufficientData,
              )
              .toList();
          final lostToFollowUpCases = allPatients
              .where(
                (p) => triage_rules.TriageRules.isLostToFollowUp(p.lastBpDate),
              )
              .length;

          final displayPatients = allPatients.where((p) {
            final matchesQuery =
                searchQuery.isEmpty ||
                p.fullName.toLowerCase().contains(searchQuery) ||
                (p.hn != null && p.hn!.toLowerCase().contains(searchQuery));

            if (!matchesQuery) return false;

            final category = _getCategory(p);
            switch (selectedFilter) {
              case 'CRITICAL':
                return category == triage_rules.TriageCategory.critical;
              case 'OVER_TREATMENT':
                return category == triage_rules.TriageCategory.overTreatment;
              case 'HYPOTENSION':
                return category == triage_rules.TriageCategory.hypotension;
              case 'WARNING':
                return category == triage_rules.TriageCategory.warning;
              case 'NORMAL':
                return category == triage_rules.TriageCategory.normal;
              case 'ALL':
              default:
                return true;
            }
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------------
                // 1. เมนู "ภาพรวม" -> แสดงเฉพาะ KPI + กราฟ 7 วัน + PieChart + เตือนเคสด่วน
                // -------------------------------------------------------------
                if (widget.viewMode == OverviewViewMode.dashboard) ...[
                  _buildKpiMetrics(
                    context,
                    allPatients.length,
                    criticalCases.length,
                    overTreatmentCases.length,
                    warningCases.length,
                    normalCases.length,
                    insufficientDataCases.length,
                    lostToFollowUpCases,
                  ),
                  const SizedBox(height: 24),
                  _buildClinicalQualityKpis(qualityKpi),
                  const SizedBox(height: 24),
                  _buildDashboardSummary(
                    context,
                    normal: normalCases.length,
                    warning: warningCases.length,
                    critical: criticalCases.length,
                    lowBloodPressure:
                        overTreatmentCases.length +
                        allPatients
                            .where(
                              (p) =>
                                  _getCategory(p) ==
                                  triage_rules.TriageCategory.hypotension,
                            )
                            .length,
                    lostToFollowUp: lostToFollowUpCases,
                  ),
                  const SizedBox(height: 24),
                  _buildSupplementalInsights(
                    allPatients,
                    activityAsync,
                    aggregateBpAsync,
                  ),
                  // แสดงกล่องเตือนสีแดงด้านล่างถ้ามีเคสวิกฤต เพื่อไม่ให้ตกหล่น
                  if (criticalCases.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildUrgentQueue(criticalCases),
                  ],
                ],

                // -------------------------------------------------------------
                // 2. เมนู "คัดกรองด่วน" -> แสดงคิวงานวิกฤต + ตารางเคสด่วน (ตัดกราฟสรุปออก)
                // -------------------------------------------------------------
                if (widget.viewMode == OverviewViewMode.urgentTriage) ...[
                  if (criticalCases.isNotEmpty) ...[
                    _buildUrgentQueue(criticalCases),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClinicalColors.normalBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ClinicalColors.normalGreen.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: ClinicalColors.normalGreen,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'ยอดเยี่ยม! ไม่พบผู้ป่วยที่มีภาวะวิกฤต (BP >= 180 mmHg) ในระบบขณะนี้',
                            style: TextStyle(
                              color: ClinicalColors.normalGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildSearchAndFilterControls(context, selectedFilter),
                  const SizedBox(height: 16),
                  _buildPatientTable(displayPatients),
                ],

                // -------------------------------------------------------------
                // 3. เมนู "ทะเบียนผู้ป่วย" -> แสดงเฉพาะค้นหา + ตัวกรอง + ตารางทั้งหมด + CSV
                // -------------------------------------------------------------
                if (widget.viewMode == OverviewViewMode.patientRegistry) ...[
                  _buildSearchAndFilterControls(context, selectedFilter),
                  const SizedBox(height: 16),
                  _buildPatientTable(displayPatients),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  

  Widget _buildKpiMetrics(
    BuildContext context,
    int total,
    int critical,
    int overTreatment,
    int warning,
    int normal,
    int insufficientData,
    int lostToFollowUp,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final isTablet =
            constraints.maxWidth >= 700 && constraints.maxWidth < 1150;
        final columns = isMobile
            ? 2
            : isTablet
            ? 3
            : 4;

        final cardWidth =
            (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'ผู้ป่วยทั้งหมด',
                '$total',
                Icons.people_outline,
                ClinicalColors.totalBlue,
                ClinicalColors.totalBlueBg,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'เคสวิกฤต (BP >= 180)',
                '$critical',
                Icons.crisis_alert_rounded,
                ClinicalColors.criticalRed,
                ClinicalColors.criticalBg,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'ความดันตก (Over-Tx)',
                '$overTreatment',
                Icons.medication_liquid_rounded,
                ClinicalColors.overTreatmentPurple,
                ClinicalColors.overTreatmentBg,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'เฝ้าระวัง (Stage 1-2)',
                '$warning',
                Icons.trending_up_rounded,
                ClinicalColors.warningOrange,
                ClinicalColors.warningBg,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'ควบคุมได้ตามเกณฑ์',
                '$normal',
                Icons.check_circle_outline,
                ClinicalColors.normalGreen,
                ClinicalColors.normalBg,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'ข้อมูลสัญญาณชีพไม่ครบ',
                '$insufficientData',
                Icons.help_outline_rounded,
                ClinicalColors.warningOrange,
                ClinicalColors.warningBg,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                'ขาดติดต่อ (> 30 วัน)',
                '$lostToFollowUp',
                Icons.person_off_rounded,
                ClinicalColors.lostToFollowUpOrange,
                ClinicalColors.lostToFollowUpBg,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: ClinicalColors.iconBadgeGradient(color),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ClinicalColors.textPrimary,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: ClinicalColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentQueue(List<PatientTriageModel> criticalCases) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.criticalBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ClinicalColors.criticalRed.withValues(alpha: 0.15),
        ),
        boxShadow: ClinicalColors.coloredGlow(ClinicalColors.criticalRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emergency_rounded,
                color: ClinicalColors.criticalRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'รายการที่ต้องดำเนินการด่วน (Urgent Triage Action Queue)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ClinicalColors.criticalRed,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${criticalCases.length} รายการ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ClinicalColors.criticalRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...criticalCases.map((patient) => _buildUrgentPatientRow(patient)),
        ],
      ),
    );
  }

  // ปรับปรุงฟังก์ชัน _buildUrgentPatientRow ใน overview_screen.dart

  Widget _buildUrgentPatientRow(PatientTriageModel patient) {
    final initials = patient.fullName.trim().isEmpty
        ? '?'
        : patient.fullName.trim().characters.first.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final patientInfo = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ClinicalColors.criticalRed.withValues(alpha: 0.85),
                      ClinicalColors.criticalRed,
                    ],
                  ),
                  boxShadow: ClinicalColors.coloredGlow(
                    ClinicalColors.criticalRed,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'HN: ${patient.hn ?? "-"} | SBP ≥ 180 mmHg',
                      style: const TextStyle(
                        color: ClinicalColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildUrgentBpBadge(patient),
            ],
          );

          // 🌟 Actions แถบจัดการ Alert Lifecycle
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              // ปุ่มกดรับทราบเคส (Acknowledge)
              FilledButton.tonalIcon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'รับทราบเคสวิกฤตและเริ่มกระบวนการติดตามเรียบร้อยแล้ว',
                      ),
                      backgroundColor: ClinicalColors.primaryEmerald,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF3C7),
                  foregroundColor: const Color(0xFF92400E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.assignment_ind_rounded, size: 15),
                label: const Text(
                  'รับเคส (Ack)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PatientDetailScreen(patientId: patient.patientId),
                  ),
                ),
                icon: const Icon(Icons.monitor_heart_outlined, size: 15),
                label: const Text(
                  'เปิด Clinical View',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              FilledButton.icon(
                onPressed:
                    patient.phone == null || patient.phone!.trim().isEmpty
                    ? null
                    : () => _callPatient(patient.phone!),
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicalColors.criticalRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ClinicalColors.borderLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.call_rounded, size: 15),
                label: const Text('โทรด่วน', style: TextStyle(fontSize: 12)),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [patientInfo, const SizedBox(height: 12), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: patientInfo),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildUrgentBpBadge(PatientTriageModel patient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ClinicalColors.criticalBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'BP ${patient.systolic ?? "-"}/${patient.diastolic ?? "-"}',
        style: const TextStyle(
          color: ClinicalColors.criticalRed,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _callPatient(String phone) async {
    final launched = await launchUrl(Uri.parse('tel:${phone.trim()}'));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดการโทรจากอุปกรณ์นี้ได้')),
      );
    }
  }

  Widget _buildSearchAndFilterControls(
    BuildContext context,
    String currentFilter,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          final searchField = TextField(
            focusNode: _overviewSearchFocusNode,
            onChanged: (val) =>
                ref.read(searchQueryProvider.notifier).state = val,
            decoration: const InputDecoration(
              hintText: 'ค้นหาด้วยชื่อผู้ป่วย หรือ HN...',
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: ClinicalColors.textMuted,
              ),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: ClinicalColors.borderLight),
              ),
            ),
          );

          final filterChips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('ทั้งหมด', 'ALL', currentFilter),
              _buildFilterChip(
                'วิกฤต',
                'CRITICAL',
                currentFilter,
                activeColor: ClinicalColors.criticalRed,
              ),
              _buildFilterChip(
                'ความดันตก (Over-Tx)',
                'OVER_TREATMENT',
                currentFilter,
                activeColor: const Color(0xFF6366F1),
              ),
              _buildFilterChip(
                'ความดันต่ำทั่วไป',
                'HYPOTENSION',
                currentFilter,
                activeColor: const Color(0xFF0284C7),
              ),
              _buildFilterChip(
                'เฝ้าระวัง',
                'WARNING',
                currentFilter,
                activeColor: ClinicalColors.warningOrange,
              ),
              _buildFilterChip(
                'ปกติ',
                'NORMAL',
                currentFilter,
                activeColor: ClinicalColors.normalGreen,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [searchField, const SizedBox(height: 12), filterChips],
            );
          } else {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 16),
                filterChips,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDashboardSummary(
    BuildContext context, {
    required int normal,
    required int warning,
    required int critical,
    required int lowBloodPressure,
    required int lostToFollowUp,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;
        final quickActions = _buildQuickActions();
        final situationSummary = _buildSituationSummary(
          normal: normal,
          warning: warning,
          critical: critical,
          lowBloodPressure: lowBloodPressure,
          lostToFollowUp: lostToFollowUp,
        );

        if (isNarrow) {
          return Column(
            children: [
              quickActions,
              const SizedBox(height: 16),
              situationSummary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: quickActions),
            const SizedBox(width: 16),
            Expanded(child: situationSummary),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        label: 'ค้นหาผู้ป่วย',
        icon: Icons.person_search_rounded,
        color: ClinicalColors.primaryEmerald,
        onTap: () => _overviewSearchFocusNode.requestFocus(),
      ),
      (
        label: 'คัดกรองด่วน',
        icon: Icons.flash_on_rounded,
        color: ClinicalColors.criticalRed,
        onTap: () =>
            ref.read(selectedStatusFilterProvider.notifier).state = 'CRITICAL',
      ),
      (
        label: 'เคส Over-Tx',
        icon: Icons.medication_liquid_rounded,
        color: ClinicalColors.overTreatmentPurple,
        onTap: () => ref.read(selectedStatusFilterProvider.notifier).state =
            'OVER_TREATMENT',
      ),
      (
        label: 'ขาดการติดต่อ',
        icon: Icons.person_off_rounded,
        color: ClinicalColors.lostToFollowUpOrange,
        onTap: () {
          // รีเฟรชและเตรียมกรองในขั้นตอนถัดไป
          ref.invalidate(triageOverviewProvider);
        },
      ),
    ];

    return _buildSummaryPanel(
      title: 'ทางลัดศูนย์สั่งการ (Command Shortcuts)',
      icon: Icons.bolt_rounded,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.3,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return OutlinedButton.icon(
            onPressed: action.onTap,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: action.color,
              side: BorderSide(color: action.color.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: Icon(action.icon, size: 19),
            label: Text(
              action.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSituationSummary({
    required int normal,
    required int warning,
    required int critical,
    required int lowBloodPressure,
    required int lostToFollowUp,
  }) {
    final sections = [
      (label: 'ปกติ', value: normal, color: ClinicalColors.normalGreen),
      (label: 'เฝ้าระวัง', value: warning, color: ClinicalColors.warningOrange),
      (label: 'วิกฤต', value: critical, color: ClinicalColors.criticalRed),
      (
        label: 'ความดันต่ำ',
        value: lowBloodPressure,
        color: ClinicalColors.overTreatmentPurple,
      ),
      (
        label: 'ขาดติดต่อ',
        value: lostToFollowUp,
        color: ClinicalColors.lostToFollowUpOrange,
      ),
    ];
    final total = sections.fold<int>(0, (sum, section) => sum + section.value);

    return _buildSummaryPanel(
      title: 'สรุปสถานการณ์วันนี้',
      icon: Icons.donut_large_rounded,
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: total == 0
                ? const Center(
                    child: Text(
                      'ยังไม่มีข้อมูล',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ClinicalColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: sections
                          .where((section) => section.value > 0)
                          .map(
                            (section) => PieChartSectionData(
                              value: section.value.toDouble(),
                              color: section.color,
                              radius: 25,
                              showTitle: false,
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.map((section) {
                final percentage = total == 0
                    ? 0
                    : (section.value / total * 100).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: section.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          section.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ClinicalColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ClinicalColors.primaryEmerald, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSupplementalInsights(
    List<PatientTriageModel> patients,
    AsyncValue<List<ActivityLogEntry>> activityAsync,
    AsyncValue<List<DailyBpAverage>> aggregateBpAsync,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;
        final trend = _buildAggregateBpTrend(aggregateBpAsync);
        final disease = _buildDiseaseStatistics(patients);
        final activity = _buildActivityFeed(activityAsync);
        final cdss = _buildCdssSummary(patients);

        if (isNarrow) {
          return Column(
            children: [
              trend,
              const SizedBox(height: 16),
              disease,
              const SizedBox(height: 16),
              activity,
              const SizedBox(height: 16),
              cdss,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: trend),
                const SizedBox(width: 16),
                Expanded(child: disease),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: activity),
                const SizedBox(width: 16),
                Expanded(child: cdss),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAggregateBpTrend(AsyncValue<List<DailyBpAverage>> trendAsync) {
    return _buildSummaryPanel(
      title: 'แนวโน้มความดันเฉลี่ย 7 วัน',
      icon: Icons.show_chart_rounded,
      child: trendAsync.when(
        loading: () => const SizedBox(
          height: 190,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => _buildEmptyInsight('ยังไม่มีข้อมูลแนวโน้มความดัน'),
        data: (allDays) {
          final days = allDays.length <= 7
              ? allDays
              : allDays.sublist(allDays.length - 7);
          if (days.isEmpty)
            return _buildEmptyInsight('ยังไม่มีข้อมูลแนวโน้มความดัน');

          final maxValue = days.fold<double>(
            0,
            (max, day) => max > day.systolic ? max : day.systolic,
          );
          final minValue = days.fold<double>(
            300,
            (min, day) => min < day.diastolic ? min : day.diastolic,
          );
          final minY = (minValue - 10).clamp(0, 300).toDouble();
          final maxY = (maxValue + 10).clamp(1, 300).toDouble();

          return SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length)
                          return const SizedBox.shrink();
                        return Text(
                          '${days[index].date.day}/${days[index].date.month}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ClinicalColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _buildTrendLine(
                    days.map((day) => day.systolic).toList(),
                    ClinicalColors.criticalRed,
                  ),
                  _buildTrendLine(
                    days.map((day) => day.diastolic).toList(),
                    ClinicalColors.totalBlue,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  LineChartBarData _buildTrendLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
    );
  }

  Widget _buildDiseaseStatistics(List<PatientTriageModel> patients) {
    final counts = <String, int>{};
    for (final patient in patients) {
      final rawDiseases = patient.underlyingDiseases?.trim();
      if (rawDiseases == null || rawDiseases.isEmpty) continue;
      for (final disease in rawDiseases.split(RegExp(r'[,;/|]'))) {
        final name = disease.trim();
        if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.take(5).toList();

    return _buildSummaryPanel(
      title: 'สถิติกลุ่มโรควันนี้',
      icon: Icons.bar_chart_rounded,
      child: topEntries.isEmpty
          ? _buildEmptyInsight('ยังไม่มีข้อมูลกลุ่มโรค')
          : SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: (topEntries.first.value + 1).toDouble(),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= topEntries.length)
                            return const SizedBox.shrink();
                          final label = topEntries[index].key;
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              label.length > 10
                                  ? '${label.substring(0, 10)}...'
                                  : label,
                              style: const TextStyle(
                                fontSize: 9,
                                color: ClinicalColors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < topEntries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: topEntries[i].value.toDouble(),
                            color: ClinicalColors.primaryEmerald,
                            width: 22,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActivityFeed(AsyncValue<List<ActivityLogEntry>> activityAsync) {
    return _buildSummaryPanel(
      title: 'กิจกรรมล่าสุด',
      icon: Icons.history_rounded,
      child: activityAsync.when(
        loading: () => const SizedBox(
          height: 130,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => _buildEmptyInsight('ยังไม่มีกิจกรรมล่าสุด'),
        data: (entries) => entries.isEmpty
            ? _buildEmptyInsight('ยังไม่มีกิจกรรมล่าสุด')
            : Column(
                children: entries.take(5).map((entry) {
                  final date = entry.createdAt;
                  final dateLabel = date == null
                      ? ''
                      : '${date.day}/${date.month}';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: ClinicalColors.normalBg,
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: ClinicalColors.primaryEmerald,
                      ),
                    ),
                    title: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: entry.description == null
                        ? null
                        : Text(
                            entry.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ClinicalColors.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildCdssSummary(List<PatientTriageModel> patients) {
    if (patients.isEmpty) {
      return _buildSummaryPanel(
        title: 'คำแนะนำจากระบบ CDSS',
        icon: Icons.medical_services_outlined,
        child: _buildEmptyInsight('ยังไม่มีข้อมูลสำหรับประเมิน'),
      );
    }

    // เลือกลำดับเคสที่ต้องการการตัดสินใจด่วนที่สุดขึ้นมาแสดง (Critical หรือ Over-treatment ก่อน)
    final urgentPatient = patients.firstWhere(
      (item) =>
          _getCategory(item) == triage_rules.TriageCategory.critical ||
          _getCategory(item) == triage_rules.TriageCategory.overTreatment,
      orElse: () => patients.first,
    );

    final diseases = (urgentPatient.underlyingDiseases ?? '').toLowerCase();
    final result = HtCdssEngine.evaluate(
      HtPatientData(
        age: urgentPatient.age ?? 0,
        sex: urgentPatient.gender ?? 'ไม่ระบุ',
        officeSbp: urgentPatient.systolic ?? 0,
        officeDbp: urgentPatient.diastolic ?? 0,
        heartRate: urgentPatient.pulse ?? 0,
        hasCvd: diseases.contains('cvd') || diseases.contains('หัวใจ'),
        hasDm: diseases.contains('dm') || diseases.contains('เบาหวาน'),
        cvRiskScore: 0,
        hasHmod: false,
        egfr: urgentPatient.egfr ?? 0,
        potassium: 0,
        isFrail: false,
        hasHighNocturnalBp: false,
        medCount: 0,
        currentMedClasses: const [],
      ),
    );
    final summary = result.safetyAlerts.isNotEmpty
        ? result.safetyAlerts.first
        : result.diagnosisEvaluation;

    return _buildSummaryPanel(
      title: 'คำแนะนำจากระบบ CDSS',
      icon: Icons.medical_services_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: ClinicalColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เคสเฝ้าระวัง: ${urgentPatient.fullName} (BP: ${urgentPatient.systolic ?? "-"}/${urgentPatient.diastolic ?? "-"})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: ClinicalColors.primaryEmerald,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInsight(String message) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: ClinicalColors.textMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFilterChip(
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
      backgroundColor: ClinicalColors.canvasBg,
      showCheckmark: false,
      side: BorderSide(color: isSelected ? color : ClinicalColors.borderLight),
      onSelected: (_) =>
          ref.read(selectedStatusFilterProvider.notifier).state = value,
    );
  }

  Widget _buildPatientTable(List<PatientTriageModel> patients) {
    return Container(
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'รายชื่อผู้ป่วยในการติดตาม (Patient Registry)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ClinicalColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${patients.length} รายการ)',
                        style: const TextStyle(
                          color: ClinicalColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: patients.isEmpty
                      ? null
                      : () => ExportUtil.exportPatientListToCsv(patients),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text(
                    'ส่งออก CSV',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (patients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'ไม่พบข้อมูลผู้ป่วยที่ตรงกับเงื่อนไขการค้นหา',
                  style: TextStyle(color: ClinicalColors.textMuted),
                ),
              ),
            )
          else
            SingleChildScrollView(
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ชื่อ - นามสกุล',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ความดันล่าสุด',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ชีพจร',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'น้ำตาล FBS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'สถานะคัดกรอง',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: patients.map((p) {
                    final sbp = p.systolic ?? 0;
                    final dbp = p.diastolic ?? 0;
                    final category = _getCategory(p);

                    Color bpColor = ClinicalColors.textPrimary;
                    if (category == triage_rules.TriageCategory.critical) {
                      bpColor = ClinicalColors.criticalRed;
                    } else if (category ==
                        triage_rules.TriageCategory.overTreatment) {
                      bpColor = const Color(0xFF6366F1);
                    } else if (category ==
                        triage_rules.TriageCategory.hypotension) {
                      bpColor = const Color(0xFF0284C7);
                    }

                    return DataRow(
                      onSelectChanged: (_) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PatientDetailScreen(patientId: p.patientId),
                          ),
                        );
                      },
                      cells: [
                        DataCell(Text(p.hn ?? '-')),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
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
                            p.systolic != null ? '$sbp/$dbp mmHg' : '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: bpColor,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(p.pulse != null ? '${p.pulse} bpm' : '-'),
                        ),
                        DataCell(Text(p.fbs != null ? '${p.fbs} mg/dL' : '-')),
                        DataCell(_buildStatusBadge(p)),
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

  Widget _buildStatusBadge(PatientTriageModel p) {
    final category = _getCategory(p);
    Color bg = ClinicalColors.normalBg;
    Color text = ClinicalColors.normalGreen;
    String label = 'ปกติ';
    Border? border;

    switch (category) {
      case triage_rules.TriageCategory.critical:
        bg = ClinicalColors.criticalBg;
        text = ClinicalColors.criticalRed;
        label = '🚨 วิกฤต BP สูง';
        break;
      case triage_rules.TriageCategory.overTreatment:
        bg = const Color(0xFFEEF2FF);
        text = const Color(0xFF6366F1);
        label = '⚠️ ความดันตก (Over-Tx)';
        border = Border.all(color: const Color(0xFFC7D2FE));
        break;
      case triage_rules.TriageCategory.hypotension:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0284C7);
        label = '💧 ความดันต่ำ (Naïve)';
        border = Border.all(color: const Color(0xFFBAE6FD));
        break;
      case triage_rules.TriageCategory.warning:
        bg = ClinicalColors.warningBg;
        text = ClinicalColors.warningOrange;
        label = 'เฝ้าระวัง';
        break;
      case triage_rules.TriageCategory.normal:
        bg = ClinicalColors.normalBg;
        text = ClinicalColors.normalGreen;
        label = 'ปกติ';
        break;
      case triage_rules.TriageCategory.insufficientData:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'ข้อมูลไม่เพียงพอ';
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

  /// วิดเจ็ตแสดงตัวชี้วัดคุณภาพคลินิก (Clinical Quality KPIs)
  Widget _buildClinicalQualityKpis(PopulationKpiSummary kpi) {
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
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: ClinicalColors.primaryEmerald,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ตัวชี้วัดคุณภาพการดูแลรักษา NCDs (Quality Benchmark & Care Metrics)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: ClinicalColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ClinicalColors.canvasBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ทะเบียนรวม ${kpi.totalPatients} ราย',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ClinicalColors.deepCocoa,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final itemWidth = isNarrow
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildQualityRateCard(
                      'อัตราคุมความดันสำเร็จ (BP Control)',
                      '${kpi.bpControlRate.toStringAsFixed(1)}%',
                      'เป้าหมาย ≥ 60%',
                      ClinicalColors.normalGreen,
                      const Color(0xFFF0FDF4),
                      Icons.check_circle_outline_rounded,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQualityRateCard(
                      'อัตราความดันวิกฤต (Crisis Exposure)',
                      '${kpi.criticalBpRate.toStringAsFixed(1)}%',
                      'เป้าหมาย < 5%',
                      ClinicalColors.criticalRed,
                      const Color(0xFFFEF2F2),
                      Icons.crisis_alert_rounded,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQualityRateCard(
                      'อัตราความดันตก (Over-Tx)',
                      '${kpi.overTreatmentRate.toStringAsFixed(1)}%',
                      'เฝ้าระวังยาเกินขนาด',
                      const Color(0xFF6366F1),
                      const Color(0xFFEEF2FF),
                      Icons.medication_liquid_rounded,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQualityRateCard(
                      'อัตราขาดการติดต่อ (Lost-to-F/U)',
                      '${kpi.lostToFollowUpRate.toStringAsFixed(1)}%',
                      'ไม่บันทึก > 30 วัน',
                      ClinicalColors.lostToFollowUpOrange,
                      const Color(0xFFFFF7ED),
                      Icons.person_off_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildCohortSummaryStrip(kpi),
        ],
      ),
    );
  }

  Widget _buildQualityRateCard(
    String title,
    String rateText,
    String benchmark,
    Color color,
    Color bg,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rateText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            benchmark,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCohortSummaryStrip(PopulationKpiSummary kpi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ClinicalColors.canvasBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 16,
                color: ClinicalColors.textMuted,
              ),
              SizedBox(width: 6),
              Text(
                'กลุ่มประชากรในการดูแล (Cohorts):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ClinicalColors.textPrimary,
                ),
              ),
            ],
          ),
          _buildCohortBadge(
            'ความดันอย่างเดียว (HT)',
            '${kpi.htOnlyCount} ราย',
            ClinicalColors.primaryEmerald,
          ),
          _buildCohortBadge(
            'เบาหวานอย่างเดียว (DM)',
            '${kpi.dmOnlyCount} ราย',
            const Color(0xFFD97706),
          ),
          _buildCohortBadge(
            'โรคร่วม (HT + DM)',
            '${kpi.htWithDmCount} ราย',
            const Color(0xFF7C3AED),
          ),
          _buildCohortBadge(
            'เสี่ยงหลอดเลือดสูง (High CVD)',
            '${kpi.highCvRiskCount} ราย',
            ClinicalColors.criticalRed,
          ),
        ],
      ),
    );
  }

  Widget _buildCohortBadge(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11.5,
            color: ClinicalColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
