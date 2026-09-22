// lib/features/followup/presentation/follow_up_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/clinical_theme.dart';
import '../data/appointment_model.dart';
import '../data/appointment_repository.dart';
import '../../overview/presentation/patient_detail_screen.dart';

final selectedApptCategoryFilterProvider = StateProvider<AppointmentStatusCategory?>((ref) => null);
final apptSearchQueryProvider = StateProvider<String>((ref) => '');

class FollowUpManagementScreen extends ConsumerWidget {
  const FollowUpManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(appointmentsListProvider);
    final currentCategory = ref.watch(selectedApptCategoryFilterProvider);
    final searchQuery = ref.watch(apptSearchQueryProvider).trim().toLowerCase();

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: apptsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลนัดหมาย: $err',
                style: const TextStyle(color: ClinicalColors.criticalRed)),
          ),
        ),
        data: (allAppts) {
          final dueToday = allAppts.where((a) => a.category == AppointmentStatusCategory.dueToday).toList();
          final upcoming = allAppts.where((a) => a.category == AppointmentStatusCategory.upcoming).toList();
          final overdue = allAppts.where((a) => a.category == AppointmentStatusCategory.overdue).toList();
          final completed = allAppts.where((a) => a.category == AppointmentStatusCategory.completed).toList();

          // Filter by category and search
          final filteredList = allAppts.where((a) {
            if (currentCategory != null && a.category != currentCategory) {
              return false;
            }
            if (searchQuery.isNotEmpty) {
              final matchName = a.patientName.toLowerCase().contains(searchQuery);
              final matchHn = a.hn?.toLowerCase().contains(searchQuery) ?? false;
              final matchClinic = a.clinicName.toLowerCase().contains(searchQuery);
              if (!matchName && !matchHn && !matchClinic) return false;
            }
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context, ref),
                const SizedBox(height: 20),

                // KPI Metrics Strip (4 Status Categories)
                _buildMetricStrip(ref, currentCategory, dueToday.length, upcoming.length, overdue.length, completed.length),
                const SizedBox(height: 20),

                // Search & Filter
                _buildFilterBar(context, ref, currentCategory),
                const SizedBox(height: 16),

                // Appointment Queue Table
                _buildAppointmentTable(context, ref, filteredList),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ระบบจัดการยาและนัดหมายติดตามอาการ (Medication & Follow-up Engine)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              'ติดตามคิวนัดหมายประจำวัน เฝ้าระวังผู้ป่วยขาดนัด และบริหารจัดการความต่อเนื่องการรักษา',
              style: TextStyle(fontSize: 12.5, color: ClinicalColors.textMuted),
            ),
          ],
        ),
        IconButton(
          onPressed: () => ref.refresh(appointmentsListProvider),
          icon: const Icon(Icons.refresh_rounded, color: ClinicalColors.textMuted),
          tooltip: 'รีเฟรชข้อมูล',
        ),
      ],
    );
  }

  Widget _buildMetricStrip(
    WidgetRef ref,
    AppointmentStatusCategory? selected,
    int dueTodayCount,
    int upcomingCount,
    int overdueCount,
    int completedCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final itemWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                title: 'นัดหมายวันนี้ (Due Today)',
                count: dueTodayCount,
                color: ClinicalColors.totalBlue,
                bg: const Color(0xFFEFF6FF),
                icon: Icons.today_rounded,
                isSelected: selected == AppointmentStatusCategory.dueToday,
                onTap: () {
                  ref.read(selectedApptCategoryFilterProvider.notifier).state =
                      selected == AppointmentStatusCategory.dueToday ? null : AppointmentStatusCategory.dueToday;
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                title: 'นัดหมายล่วงหน้า (Upcoming)',
                count: upcomingCount,
                color: ClinicalColors.primaryEmerald,
                bg: const Color(0xFFECFDF5),
                icon: Icons.event_available_rounded,
                isSelected: selected == AppointmentStatusCategory.upcoming,
                onTap: () {
                  ref.read(selectedApptCategoryFilterProvider.notifier).state =
                      selected == AppointmentStatusCategory.upcoming ? null : AppointmentStatusCategory.upcoming;
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                title: 'เลยกำหนดนัด (Overdue)',
                count: overdueCount,
                color: ClinicalColors.criticalRed,
                bg: const Color(0xFFFEF2F2),
                icon: Icons.alarm_off_rounded,
                isSelected: selected == AppointmentStatusCategory.overdue,
                onTap: () {
                  ref.read(selectedApptCategoryFilterProvider.notifier).state =
                      selected == AppointmentStatusCategory.overdue ? null : AppointmentStatusCategory.overdue;
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricTile(
                title: 'มาตามนัดแล้ว (Completed)',
                count: completedCount,
                color: const Color(0xFF10B981),
                bg: const Color(0xFFF0FDF4),
                icon: Icons.task_alt_rounded,
                isSelected: selected == AppointmentStatusCategory.completed,
                onTap: () {
                  ref.read(selectedApptCategoryFilterProvider.notifier).state =
                      selected == AppointmentStatusCategory.completed ? null : AppointmentStatusCategory.completed;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required int count,
    required Color color,
    required Color bg,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? bg : ClinicalColors.surfaceWhite,
            borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
            border: Border.all(
              color: isSelected ? color : ClinicalColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
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
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      child: const Text('กำลังกรอง', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('$count ราย', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ClinicalColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, AppointmentStatusCategory? currentCategory) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) => ref.read(apptSearchQueryProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText: 'ค้นหาด้วยชื่อผู้ป่วย, HN, คลินิก...',
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: ClinicalColors.textMuted),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: ClinicalColors.borderLight),
                ),
              ),
            ),
          ),
          if (currentCategory != null) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => ref.read(selectedApptCategoryFilterProvider.notifier).state = null,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointmentTable(BuildContext context, WidgetRef ref, List<AppointmentItemModel> appointments) {
    if (appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: ClinicalColors.surfaceWhite,
          borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
          border: Border.all(color: ClinicalColors.borderLight),
        ),
        child: const Center(
          child: Text('ไม่พบรายการนัดหมายตามเงื่อนไขที่เลือก', style: TextStyle(color: ClinicalColors.textMuted)),
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
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('วัน-เวลานัด', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ผู้ป่วย / HN', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('คลินิก / วัตถุประสงค์', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('งดอาหาร', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('การจัดการ', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: appointments.map((appt) {
              final dateStr = '${appt.appointmentDate.day}/${appt.appointmentDate.month}/${appt.appointmentDate.year}';
              final badge = _buildStatusBadge(appt.category);

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        Text('${appt.appointmentTime} น.', style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                      ],
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: appt.patientId)),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appt.patientName, style: const TextStyle(fontWeight: FontWeight.w600, color: ClinicalColors.primaryEmerald)),
                          Text(appt.hn != null ? 'HN: ${appt.hn}' : '-', style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appt.clinicName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(appt.reason, style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  DataCell(
                    appt.needFasting
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                            child: const Text('งดน้ำ/อาหาร', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                          )
                        : const Text('-', style: TextStyle(color: ClinicalColors.textMuted)),
                  ),
                  DataCell(badge),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (appt.phone != null && appt.phone!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, size: 16, color: ClinicalColors.totalBlue),
                            tooltip: 'โทรหาผู้ป่วย',
                            onPressed: () => launchUrl(Uri.parse('tel:${appt.phone}')),
                          ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          tooltip: 'ปรับสถานะ',
                          onPressed: () => _showAppointmentActionModal(context, ref, appt),
                        ),
                      ],
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

  Widget _buildStatusBadge(AppointmentStatusCategory category) {
    Color color;
    Color bg;
    String label;

    switch (category) {
      case AppointmentStatusCategory.dueToday:
        color = ClinicalColors.totalBlue;
        bg = const Color(0xFFEFF6FF);
        label = 'นัดวันนี้';
        break;
      case AppointmentStatusCategory.upcoming:
        color = ClinicalColors.primaryEmerald;
        bg = const Color(0xFFECFDF5);
        label = 'กำลังมาถึง';
        break;
      case AppointmentStatusCategory.overdue:
        color = ClinicalColors.criticalRed;
        bg = const Color(0xFFFEF2F2);
        label = 'เลยกำหนดนัด';
        break;
      case AppointmentStatusCategory.completed:
        color = const Color(0xFF10B981);
        bg = const Color(0xFFF0FDF4);
        label = 'ตรวจแล้ว';
        break;
      case AppointmentStatusCategory.missed:
        color = ClinicalColors.textMuted;
        bg = const Color(0xFFF1F5F9);
        label = 'ขาดนัด';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _showAppointmentActionModal(BuildContext context, WidgetRef ref, AppointmentItemModel appt) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('จัดการนัดหมาย: ${appt.patientName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: ClinicalColors.normalGreen),
              title: const Text('บันทึกมาตามนัดแล้ว (Mark as Completed)'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(appointmentRepositoryProvider).updateAppointmentStatus(
                      appointmentId: appt.id,
                      status: 'completed',
                      patientId: appt.patientId,
                    );
                ref.invalidate(appointmentsListProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_off_outlined, color: ClinicalColors.criticalRed),
              title: const Text('บันทึกขาดนัด (Mark as Missed)'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(appointmentRepositoryProvider).updateAppointmentStatus(
                      appointmentId: appt.id,
                      status: 'missed',
                      patientId: appt.patientId,
                    );
                ref.invalidate(appointmentsListProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined, color: ClinicalColors.totalBlue),
              title: const Text('เลื่อนวันนัดหมาย (Reschedule)'),
              onTap: () {
                Navigator.pop(ctx);
                _showRescheduleDialog(context, ref, appt);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRescheduleDialog(BuildContext context, WidgetRef ref, AppointmentItemModel appt) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: appt.appointmentDate.isAfter(DateTime.now()) ? appt.appointmentDate : DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && context.mounted) {
      final reasonController = TextEditingController(text: 'เลื่อนนัดตามความประสงค์ของผู้ป่วย');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยืนยันการเลื่อนวันนัดหมาย', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'เหตุผลการเลื่อนนัด'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ClinicalColors.primaryEmerald),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(appointmentRepositoryProvider).rescheduleAppointment(
                      appointmentId: appt.id,
                      newDate: pickedDate,
                      newTime: appt.appointmentTime,
                      patientId: appt.patientId,
                      reason: reasonController.text,
                    );
                ref.invalidate(appointmentsListProvider);
              },
              child: const Text('บันทึกวันนัดใหม่'),
            ),
          ],
        ),
      );
    }
  }
}