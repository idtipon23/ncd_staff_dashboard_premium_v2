// lib/features/communication/presentation/communication_center_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/clinical_theme.dart';
import '../data/communication_repository.dart';
import '../../overview/presentation/patient_detail_screen.dart';

final commSearchQueryProvider = StateProvider<String>((ref) => '');
final commLineFilterProvider = StateProvider<bool?>((ref) => null); // null: ทั้งหมด, true: มี LINE, false: ไม่มี LINE

class CommunicationCenterScreen extends ConsumerWidget {
  const CommunicationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(communicationLogsProvider);
    final searchQuery = ref.watch(commSearchQueryProvider).trim().toLowerCase();
    final lineFilter = ref.watch(commLineFilterProvider);

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: logsAsync.when(
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
        data: (allLogs) {
          final lineConnectedCount = allLogs.where((l) => l.hasLineConnected).length;
          final noLineCount = allLogs.length - lineConnectedCount;

          final filteredLogs = allLogs.where((log) {
            if (lineFilter != null && log.hasLineConnected != lineFilter) {
              return false;
            }
            if (searchQuery.isNotEmpty) {
              final matchName = log.patientName.toLowerCase().contains(searchQuery);
              final matchHn = log.hn?.toLowerCase().contains(searchQuery) ?? false;
              final matchNote = log.noteText.toLowerCase().contains(searchQuery);
              final matchStaff = log.staffName.toLowerCase().contains(searchQuery);
              if (!matchName && !matchHn && !matchNote && !matchStaff) return false;
            }
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, ref),
                const SizedBox(height: 20),

                _buildSummaryCards(ref, allLogs.length, lineConnectedCount, noLineCount, lineFilter),
                const SizedBox(height: 20),

                _buildFilterBar(ref, searchQuery, lineFilter),
                const SizedBox(height: 16),

                _buildLogsTable(context, ref, filteredLogs),
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
              'ศูนย์สื่อสารและแจ้งเตือนผู้ป่วย (Communication Center)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              'ประวัติการส่งคำแนะนำทางการแพทย์ บันทึกการโทรติดตาม และข้อความแจ้งเตือนผ่าน LINE Official',
              style: TextStyle(fontSize: 12.5, color: ClinicalColors.textMuted),
            ),
          ],
        ),
        IconButton(
          onPressed: () => ref.invalidate(communicationLogsProvider),
          icon: const Icon(Icons.refresh_rounded, color: ClinicalColors.textMuted),
          tooltip: 'รีเฟรชประวัติ',
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    WidgetRef ref,
    int totalCount,
    int lineCount,
    int noLineCount,
    bool? currentFilter,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final width = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _buildMetricTile(
                title: 'ประวัติการสื่อสารทั้งหมด',
                count: '$totalCount รายการ',
                icon: Icons.forum_rounded,
                color: ClinicalColors.totalBlue,
                bg: const Color(0xFFEFF6FF),
                isSelected: currentFilter == null,
                onTap: () => ref.read(commLineFilterProvider.notifier).state = null,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildMetricTile(
                title: 'ผู้ป่วยเชื่อมต่อ LINE แล้ว',
                count: '$lineCount รายการ',
                icon: Icons.mark_chat_read_rounded,
                color: const Color(0xFF06C755),
                bg: const Color(0xFFF0FDF4),
                isSelected: currentFilter == true,
                onTap: () => ref.read(commLineFilterProvider.notifier).state =
                    currentFilter == true ? null : true,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildMetricTile(
                title: 'ยังไม่เชื่อมต่อ LINE',
                count: '$noLineCount รายการ',
                icon: Icons.phonelink_erase_rounded,
                color: ClinicalColors.warningOrange,
                bg: const Color(0xFFFFFBEB),
                isSelected: currentFilter == false,
                onTap: () => ref.read(commLineFilterProvider.notifier).state =
                    currentFilter == false ? null : false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required Color bg,
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    Text(title,
                        style: const TextStyle(fontSize: 12, color: ClinicalColors.textPrimary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, String query, bool? lineFilter) {
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
              onChanged: (val) => ref.read(commSearchQueryProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText: 'ค้นหาด้วยชื่อผู้ป่วย, HN, ข้อความ, หรือผู้ส่ง...',
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
          if (lineFilter != null || query.isNotEmpty) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () {
                ref.read(commSearchQueryProvider.notifier).state = '';
                ref.read(commLineFilterProvider.notifier).state = null;
              },
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsTable(BuildContext context, WidgetRef ref, List<CommunicationLogModel> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: ClinicalColors.surfaceWhite,
          borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
          border: Border.all(color: ClinicalColors.borderLight),
        ),
        child: const Center(
          child: Text('ไม่พบบันทึกประวัติการสื่อสารตามเงื่อนไข', style: TextStyle(color: ClinicalColors.textMuted)),
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
          constraints: const BoxConstraints(minWidth: 880),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ClinicalColors.canvasBg),
            columnSpacing: 18,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('วัน-เวลา', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ผู้ป่วย / HN', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('สถานะ LINE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ข้อความที่สื่อสาร', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ผู้บันทึก', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('การจัดการ', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: logs.map((log) {
              final dateStr =
                  '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';

              return DataRow(
                cells: [
                  DataCell(Text(dateStr, style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted))),
                  DataCell(
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: log.patientId)),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.patientName,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: ClinicalColors.primaryEmerald)),
                          Text(log.hn != null ? 'HN: ${log.hn}' : '-',
                              style: const TextStyle(fontSize: 11, color: ClinicalColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    log.hasLineConnected
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('ผูก LINE แล้ว',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('ไม่มี LINE',
                                style: TextStyle(fontSize: 10.5, color: ClinicalColors.textMuted)),
                          ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        log.noteText,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(log.staffName,
                        style: const TextStyle(fontSize: 11.5, color: ClinicalColors.textPrimary)),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (log.phone != null && log.phone!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, size: 16, color: ClinicalColors.totalBlue),
                            tooltip: 'โทรศัพท์',
                            onPressed: () => launchUrl(Uri.parse('tel:${log.phone}')),
                          ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, size: 16, color: ClinicalColors.primaryEmerald),
                          tooltip: 'ส่งข้อความใหม่',
                          onPressed: () => _showSendMessageDialog(context, ref, log),
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

  void _showSendMessageDialog(BuildContext context, WidgetRef ref, CommunicationLogModel log) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ส่งคำแนะนำไปยัง: ${log.patientName}', style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!log.hasLineConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ผู้ป่วยยังไม่ได้ผูก LINE ระบบจะบันทึกลงเวชระเบียนภายในอย่างเดียว',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'พิมพ์ข้อความคำแนะนำหรือแจ้งเตือน...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClinicalColors.primaryEmerald),
            onPressed: () async {
              final msg = textController.text.trim();
              if (msg.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(communicationRepositoryProvider).sendDirectMessage(
                    patientId: log.patientId,
                    message: msg,
                    lineUserId: log.lineUserId,
                  );
              ref.invalidate(communicationLogsProvider);
            },
            child: const Text('ส่งข้อความ'),
          ),
        ],
      ),
    );
  }
}