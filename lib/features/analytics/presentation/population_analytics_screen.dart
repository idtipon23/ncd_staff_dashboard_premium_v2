// lib/features/analytics/presentation/population_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../overview/data/triage_repository.dart';
import '../../overview/data/patient_triage_model.dart';
import '../../overview/presentation/patient_detail_screen.dart';
import '../domain/population_kpi_rules.dart';
import '../../cdss/data/cdss_audit_repository.dart';
import '../../../core/constants/clinical_theme.dart';
import '../../../core/utils/export_util.dart';

class PopulationAnalyticsScreen extends ConsumerStatefulWidget {
  const PopulationAnalyticsScreen({super.key});

  @override
  ConsumerState<PopulationAnalyticsScreen> createState() => _PopulationAnalyticsScreenState();
}

class _PopulationAnalyticsScreenState extends ConsumerState<PopulationAnalyticsScreen> with SingleTickerProviderStateMixin {
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
    final triageAsync = ref.watch(triageOverviewProvider);
    final qualityKpi = ref.watch(populationQualityKpiProvider);
    final aggregateBpAsync = ref.watch(aggregateBpTrendProvider);
    final cdssAuditAsync = ref.watch(cdssAuditSummaryProvider);
    final currentTimeframe = ref.watch(selectedTimeframeProvider);

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: triageAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $err',
                style: const TextStyle(color: ClinicalColors.criticalRed)),
          ),
        ),
        data: (patients) => NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ส่วนหัวและปุ่ม Export
                    _buildHeaderSection(context, patients, qualityKpi),
                    const SizedBox(height: 16),

                    // ตัวเลือกช่วงเวลา Dynamic Timeframe (Protocol ข้อ 17)
                    _buildTimeframeSelector(ref, currentTimeframe),
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
                            icon: Icon(Icons.analytics_rounded, size: 18),
                            text: 'ตัวชี้วัดคุณภาพคลินิกและประชากร (Quality KPIs)',
                          ),
                          Tab(
                            icon: Icon(Icons.fact_check_rounded, size: 18),
                            text: 'การตรวจสอบการตัดสินใจ CDSS (CDSS Audit & Governance)',
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
              // แท็บ 1: ตัวชี้วัดคุณภาพคลินิก & กราฟแนวโน้มความดัน
              _buildQualityKpiTab(context, patients, qualityKpi, aggregateBpAsync),

              // แท็บ 2: CDSS Governance & Audit Dashboard
              _buildCdssAuditTab(context, ref, cdssAuditAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector(WidgetRef ref, AnalyticsTimeframe currentTimeframe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, size: 18, color: ClinicalColors.totalBlue),
          const SizedBox(width: 10),
          const Text('ช่วงเวลาประเมินผล:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AnalyticsTimeframe.values.map((timeframe) {
                  final isSelected = timeframe == currentTimeframe;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(timeframe.label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: ClinicalColors.totalBlue,
                      backgroundColor: ClinicalColors.canvasBg,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : ClinicalColors.textPrimary),
                      showCheckmark: false,
                      onSelected: (_) {
                        ref.read(selectedTimeframeProvider.notifier).state = timeframe;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityKpiTab(
    BuildContext context,
    List<PatientTriageModel> patients,
    PopulationKpiSummary qualityKpi,
    AsyncValue<List<DailyBpAverage>> aggregateBpAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQualityBenchmarks(qualityKpi),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildTrendChartCard(aggregateBpAsync)),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: _buildInteractiveCohortCard(context, qualityKpi, patients)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTrendChartCard(aggregateBpAsync),
                    const SizedBox(height: 20),
                    _buildInteractiveCohortCard(context, qualityKpi, patients),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          _buildDiseaseBreakdownCard(patients),
        ],
      ),
    );
  }

  Widget _buildCdssAuditTab(BuildContext context, WidgetRef ref, AsyncValue<CdssAuditSummary> auditAsync) {
    return auditAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald)),
      error: (err, _) => Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล CDSS: $err', style: const TextStyle(color: ClinicalColors.criticalRed))),
      data: (summary) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Strip
              LayoutBuilder(builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final itemWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricTile(
                        'การประเมิน CDSS ทั้งหมด',
                        '${summary.totalEvaluations} ครั้ง',
                        'บันทึกการตัดสินใจในระบบ',
                        ClinicalColors.totalBlue,
                        const Color(0xFFEFF6FF),
                        Icons.fact_check_rounded,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricTile(
                        'อัตรายอมรับคำแนะนำ (Accept)',
                        '${summary.acceptanceRate.toStringAsFixed(1)}%',
                        '${summary.acceptedCount} ครั้ง ที่ใช้แผนยาตามเกณฑ์',
                        ClinicalColors.normalGreen,
                        const Color(0xFFF0FDF4),
                        Icons.check_circle_rounded,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricTile(
                        'อัตราปรับเปลี่ยนยา (Override)',
                        '${summary.overrideRate.toStringAsFixed(1)}%',
                        '${summary.overriddenCount} ครั้ง ที่แพทย์ปรับสูตรเฉพาะราย',
                        const Color(0xFFD97706),
                        const Color(0xFFFFFBEB),
                        Icons.edit_note_rounded,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricTile(
                        'ปฏิเสธคำแนะนำ (Dismiss)',
                        '${summary.dismissedCount} ครั้ง',
                        'ผู้ป่วยมีข้อจำกัดเฉพาะบุคคล',
                        ClinicalColors.textMuted,
                        const Color(0xFFF1F5F9),
                        Icons.cancel_rounded,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),

              // ตารางประวัติการตัดสินใจ CDSS
              _buildCdssEventsTable(context, summary.events),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCdssEventsTable(BuildContext context, List<CdssAuditEventModel> events) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: ClinicalColors.surfaceWhite,
          borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
          border: Border.all(color: ClinicalColors.borderLight),
        ),
        child: const Center(
          child: Text('ไม่พบบันทึกการประเมิน CDSS ในช่วงเวลาที่เลือก', style: TextStyle(color: ClinicalColors.textMuted)),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ClinicalColors.canvasBg),
            columnSpacing: 18,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('วัน-เวลา', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ผู้ป่วย / HN', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ผลการตัดสินใจ', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('แนวทางที่แนะนำ', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ผู้สั่งการ', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: events.map((e) {
              final dateStr = '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year} ${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';

              Color statusColor = ClinicalColors.normalGreen;
              Color statusBg = const Color(0xFFF0FDF4);
              String statusLabel = 'ยอมรับตามเกณฑ์ (Accepted)';
              if (e.isOverride) {
                statusColor = const Color(0xFFD97706);
                statusBg = const Color(0xFFFFFBEB);
                statusLabel = 'ปรับเปลี่ยนสูตร (Override)';
              } else if (e.staffAction == 'DISMISSED') {
                statusColor = ClinicalColors.textMuted;
                statusBg = const Color(0xFFF1F5F9);
                statusLabel = 'ปฏิเสธ (Dismissed)';
              }

              return DataRow(
                cells: [
                  DataCell(Text(dateStr, style: const TextStyle(fontSize: 11.5, color: ClinicalColors.textMuted))),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.patientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                        Text(e.hn != null ? 'HN: ${e.hn}' : '-', style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(e.recommendation, style: const TextStyle(fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(Text(e.staffName, style: const TextStyle(fontSize: 11.5))),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 16, color: ClinicalColors.totalBlue),
                      tooltip: 'ดูประวัติเวชระเบียน',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: e.patientId)),
                        );
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, List<PatientTriageModel> patients, PopulationKpiSummary qualityKpi) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รายงานและสถิติประชากร (Population Health Analytics)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                ),
                SizedBox(height: 4),
                Text(
                  'วิเคราะห์ผลสัมฤทธิ์การดูแลรักษา เจาะลึกกลุ่มโรค และตัวชี้วัดคุณภาพคลินิก NCDs',
                  style: TextStyle(fontSize: 12.5, color: ClinicalColors.textMuted),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClinicalColors.totalBlue,
                  side: const BorderSide(color: ClinicalColors.totalBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
                onPressed: patients.isEmpty ? null : () => ExportUtil.exportPatientListToCsv(patients),
                icon: const Icon(Icons.table_rows_rounded, size: 15),
                label: Text(isNarrow ? 'รายชื่อ' : 'ส่งออกรายชื่อผู้ป่วย (CSV)', style: const TextStyle(fontSize: 12)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicalColors.primaryEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
                onPressed: patients.isEmpty
                    ? null
                    : () => ExportUtil.exportClinicalPerformanceReport(
                          kpi: qualityKpi,
                          patients: patients,
                        ),
                icon: const Icon(Icons.analytics_rounded, size: 15),
                label: Text(isNarrow ? 'รายงาน KPI' : 'รายงานสถิติคลินิก (KPIs)', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildQualityBenchmarks(PopulationKpiSummary kpi) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final itemWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                'อัตราคุมความดันสำเร็จ (BP Control)',
                '${kpi.bpControlRate.toStringAsFixed(1)}%',
                'เป้าหมาย: ≥ 60% (${kpi.controlledBpCount}/${kpi.totalPatients})',
                ClinicalColors.normalGreen,
                const Color(0xFFF0FDF4),
                Icons.check_circle_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                'อัตราความดันวิกฤต (Crisis Exposure)',
                '${kpi.criticalBpRate.toStringAsFixed(1)}%',
                'เกณฑ์เฝ้าระวัง: < 5% (${kpi.criticalBpCount} ราย)',
                ClinicalColors.criticalRed,
                const Color(0xFFFEF2F2),
                Icons.crisis_alert_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                'อัตราความดันตก (Over-Tx)',
                '${kpi.overTreatmentRate.toStringAsFixed(1)}%',
                'ความดันตกขณะได้ยา (${kpi.overTreatmentCount} ราย)',
                const Color(0xFF6366F1),
                const Color(0xFFEEF2FF),
                Icons.medication_liquid_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                'อัตราขาดการติดต่อ (Lost-to-F/U)',
                '${kpi.lostToFollowUpRate.toStringAsFixed(1)}%',
                'ไม่บันทึกความดัน > 30 วัน (${kpi.lostToFollowUpCount} ราย)',
                ClinicalColors.lostToFollowUpOrange,
                const Color(0xFFFFF7ED),
                Icons.person_off_rounded,
              ),
            ),
          ],
        );
      },
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
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard(AsyncValue<List<DailyBpAverage>> trendAsync) {
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
              Icon(Icons.show_chart_rounded, color: ClinicalColors.primaryEmerald, size: 20),
              SizedBox(width: 8),
              Text('แนวโน้มความดันโลหิตเฉลี่ยตามช่วงเวลาที่เลือก', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          trendAsync.when(
            loading: () => const SizedBox(height: 215, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, _) => const SizedBox(height: 215, child: Center(child: Text('ยังไม่มีข้อมูลแนวโน้มความดัน', style: TextStyle(color: ClinicalColors.textMuted)))),
            data: (allDays) {
              if (allDays.isEmpty) {
                return const SizedBox(height: 215, child: Center(child: Text('ยังไม่มีข้อมูลแนวโน้มความดัน', style: TextStyle(color: ClinicalColors.textMuted))));
              }

              final days = allDays.length <= 14 ? allDays : allDays.sublist(allDays.length - 14);
              final maxValue = days.fold<double>(0, (max, day) => max > day.systolic ? max : day.systolic);
              final minValue = days.fold<double>(300, (min, day) => min < day.diastolic ? min : day.diastolic);
              final minY = (minValue - 10).clamp(0, 300).toDouble();
              final maxY = (maxValue + 10).clamp(1, 300).toDouble();

              return SizedBox(
                height: 215,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                            return Text('${days[idx].date.day}/${days[idx].date.month}', style: const TextStyle(fontSize: 10, color: ClinicalColors.textMuted));
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].systolic)],
                        isCurved: true,
                        color: ClinicalColors.criticalRed,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                      ),
                      LineChartBarData(
                        spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].diastolic)],
                        isCurved: true,
                        color: ClinicalColors.totalBlue,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCohortCard(
    BuildContext context,
    PopulationKpiSummary kpi,
    List<PatientTriageModel> allPatients,
  ) {
    final total = allPatients.length;
    final cohortItems = [
      (
        type: ClinicalCohortType.htOnly,
        label: 'ความดันโลหิตสูงอย่างเดียว (HT Only)',
        count: kpi.htOnlyCount,
        color: ClinicalColors.primaryEmerald,
        icon: Icons.favorite_rounded,
      ),
      (
        type: ClinicalCohortType.dmOnly,
        label: 'เบาหวานอย่างเดียว (DM Only)',
        count: kpi.dmOnlyCount,
        color: const Color(0xFFD97706),
        icon: Icons.bloodtype_rounded,
      ),
      (
        type: ClinicalCohortType.htWithDm,
        label: 'โรคร่วม (HT + DM)',
        count: kpi.htWithDmCount,
        color: const Color(0xFF7C3AED),
        icon: Icons.layers_rounded,
      ),
      (
        type: ClinicalCohortType.highCvRisk,
        label: 'กลุ่มเสี่ยงหลอดเลือดสูง (High CVD Risk)',
        count: kpi.highCvRiskCount,
        color: ClinicalColors.criticalRed,
        icon: Icons.warning_amber_rounded,
      ),
    ];

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
                  Icon(Icons.pie_chart_rounded, color: ClinicalColors.primaryEmerald, size: 20),
                  SizedBox(width: 8),
                  Text('การกระจายตัวกลุ่มประชากร (Cohorts)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ClinicalColors.primaryEmerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 12, color: ClinicalColors.primaryEmerald),
                    SizedBox(width: 4),
                    Text('คลิกเพื่อดูรายชื่อ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClinicalColors.primaryEmerald)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...cohortItems.map((item) {
            final percent = total > 0 ? (item.count / total * 100).toStringAsFixed(1) : '0.0';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final filtered = PopulationKpiRules.filterPatientsByCohort(allPatients, item.type);
                    _showCohortDrillDownSheet(context, item.label, filtered, item.color);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(item.icon, size: 15, color: item.color),
                            const SizedBox(width: 6),
                            Expanded(child: Text(item.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                            Text('${item.count} ราย ($percent%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.color)),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ClinicalColors.textMuted.withValues(alpha: 0.6)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? item.count / total : 0,
                            backgroundColor: ClinicalColors.canvasBg,
                            valueColor: AlwaysStoppedAnimation<Color>(item.color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCohortDrillDownSheet(BuildContext context, String cohortTitle, List<PatientTriageModel> patients, Color themeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: ClinicalColors.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ClinicalColors.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(cohortTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('พบผู้ป่วยในกลุ่มนี้ทั้งหมด ${patients.length} ราย (คลิกเพื่อเปิด Clinical Workspace)', style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: ClinicalColors.borderLight),
              Expanded(
                child: patients.isEmpty
                    ? const Center(child: Text('ไม่พบรายชื่อผู้ป่วยในกลุ่มนี้', style: TextStyle(color: ClinicalColors.textMuted)))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: patients.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: ClinicalColors.canvasBg),
                        itemBuilder: (context, index) {
                          final p = patients[index];
                          final sbp = p.systolic ?? 0;
                          final dbp = p.diastolic ?? 0;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            title: Row(
                              children: [
                                Text(p.fullName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                if (p.hn != null && p.hn!.isNotEmpty)
                                  Text('HN: ${p.hn}', style: const TextStyle(fontSize: 11.5, color: ClinicalColors.textMuted)),
                              ],
                            ),
                            subtitle: Text(
                              sbp > 0 ? 'BP: $sbp/$dbp mmHg | โรค: ${p.underlyingDiseases ?? "-"}' : 'ยังไม่มีค่า BP',
                              style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: ClinicalColors.textMuted),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: p.patientId)),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiseaseBreakdownCard(List<PatientTriageModel> patients) {
    final counts = <String, int>{};
    for (final patient in patients) {
      final raw = patient.underlyingDiseases?.trim();
      if (raw == null || raw.isEmpty) continue;
      for (final disease in raw.split(RegExp(r'[,;/|]'))) {
        final name = disease.trim();
        if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    final topEntries = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(6).toList();

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
              Icon(Icons.bar_chart_rounded, color: ClinicalColors.primaryEmerald, size: 20),
              SizedBox(width: 8),
              Text('โรคประจำตัวที่พบบ่อยที่สุดในกลุ่มติดตาม (Top Diseases)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (topEntries.isEmpty)
            const Center(child: Text('ไม่มีข้อมูลโรคประจำตัว', style: TextStyle(color: ClinicalColors.textMuted)))
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: topEntries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: ClinicalColors.canvasBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ClinicalColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ClinicalColors.primaryEmerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${e.value} ราย', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClinicalColors.primaryEmerald)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}