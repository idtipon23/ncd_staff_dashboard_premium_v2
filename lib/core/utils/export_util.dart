// lib/core/utils/export_util.dart

import 'package:csv/csv.dart';

import '../../features/overview/data/patient_triage_model.dart';
import '../../features/analytics/domain/population_kpi_rules.dart';
import 'web_file_utils.dart';

class ExportUtil {
  /// ดาวน์โหลด CSV ผ่านเบราว์เซอร์บน Web และไม่ทำอะไรบน VM/test runtime
  static Future<void> _downloadCsvFile(String csvContent, String fileName) async {
    const bom = '\uFEFF';
    final fullCsv = csvContent.startsWith(bom) ? csvContent : bom + csvContent;
    await WebFileUtils.downloadCsv(fullCsv, fileName);
  }

  /// 1. ส่งออกรายชื่อผู้ป่วยในระบบ (Patient Registry)
  static void exportPatientListToCsv(List<PatientTriageModel> patients) {
    final List<List<dynamic>> rows = [
      [
        'HN',
        'ชื่อ - นามสกุล',
        'เพศ',
        'อายุ',
        'ความดันตัวบน (SYS)',
        'ความดันตัวล่าง (DIA)',
        'ชีพจร',
        'น้ำตาล FBS',
        'HbA1c',
        'eGFR',
        'ระดับการคัดกรอง (Triage)',
        'เบอร์โทรศัพท์',
        'ประวัติได้รับยา',
        'โรคประจำตัว',
        'วันที่บันทึกล่าสุด',
      ]
    ];

    for (final p in patients) {
      rows.add([
        p.hn ?? '-',
        p.fullName,
        p.gender ?? '-',
        p.age ?? '-',
        p.systolic ?? '-',
        p.diastolic ?? '-',
        p.pulse ?? '-',
        p.fbs ?? '-',
        p.hba1c ?? '-',
        p.egfr ?? '-',
        p.triageStatus,
        p.phone ?? '-',
        p.hasMedication ? 'มี' : 'ไม่มี',
        p.underlyingDiseases ?? '-',
        p.lastBpDate?.toIso8601String().split('T').first ?? '-',
      ]);
    }

    final csvData = const CsvEncoder().convert(rows);
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'NCDs_Patient_Report_$dateStr.csv';

    _downloadCsvFile(csvData, fileName);
  }

  /// 2. ส่งออกรายงานสรุปภาพรวมสถิติคลินิก (Phase 4.2: Clinical Performance Report)
  static void exportClinicalPerformanceReport({
    required PopulationKpiSummary kpi,
    required List<PatientTriageModel> patients,
    String clinicName = 'NCDs Clinical Command Center',
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    buffer.writeln('รายงานภาพรวมสถิติและประสิทธิภาพการดูแลรักษาคลินิกโรคไม่ติดต่อเรื้อรัง (NCDs Performance Report)');
    buffer.writeln('หน่วยบริการ,$clinicName');
    buffer.writeln('วันที่ออกรายงาน,$dateStr');
    buffer.writeln('จำนวนผู้ป่วยในการติดตามทั้งหมด,${kpi.totalPatients},ราย');
    buffer.writeln('');

    buffer.writeln('--- ตัวชี้วัดคุณภาพการดูแลรักษา (Clinical Quality KPIs) ---');
    buffer.writeln('ตัวชี้วัด,เป้าหมายทางคลินิก,จำนวน (ราย),อัตราส่วน (%)');
    buffer.writeln('อัตราควบคุมความดันโลหิตได้ตามเป้าหมาย (BP Control Rate),≥ 60%,${kpi.controlledBpCount},${kpi.bpControlRate.toStringAsFixed(1)}%');
    buffer.writeln('อัตราความดันวิกฤต (Crisis Exposure Rate),< 5%,${kpi.criticalBpCount},${kpi.criticalBpRate.toStringAsFixed(1)}%');
    buffer.writeln('อัตราความดันต่ำจากการรักษา (Over-treatment Rate),เฝ้าระวัง,${kpi.overTreatmentCount},${kpi.overTreatmentRate.toStringAsFixed(1)}%');
    buffer.writeln('อัตราขาดการติดต่อเกิน 30 วัน (Lost-to-Follow-up Rate),< 10%,${kpi.lostToFollowUpCount},${kpi.lostToFollowUpRate.toStringAsFixed(1)}%');
    buffer.writeln('');

    buffer.writeln('--- สัดส่วนกลุ่มประชากรผู้ป่วย (Cohort Segmentation) ---');
    buffer.writeln('กลุ่มประชากร,จำนวน (ราย),สัดส่วน (%)');
    final total = kpi.totalPatients > 0 ? kpi.totalPatients : 1;
    buffer.writeln('ความดันโลหิตสูงอย่างเดียว (HT Only),${kpi.htOnlyCount},${(kpi.htOnlyCount / total * 100).toStringAsFixed(1)}%');
    buffer.writeln('เบาหวานอย่างเดียว (DM Only),${kpi.dmOnlyCount},${(kpi.dmOnlyCount / total * 100).toStringAsFixed(1)}%');
    buffer.writeln('โรคร่วม (HT + DM),${kpi.htWithDmCount},${(kpi.htWithDmCount / total * 100).toStringAsFixed(1)}%');
    buffer.writeln('กลุ่มเสี่ยงหลอดเลือดหัวใจ-สมองสูง (High CVD Risk),${kpi.highCvRiskCount},${(kpi.highCvRiskCount / total * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    buffer.writeln('--- สรุปรายชื่อผู้ป่วยในกลุ่มเสี่ยงสูงและเฝ้าระวัง (Priority Registry) ---');
    buffer.writeln('HN,ชื่อ-นามสกุล,อายุ,ความดันล่าสุด,ชีพจร,กลุ่มอาการ Triage,ประวัติรับยา,โรคประจำตัว');

    for (final p in patients) {
      final sbp = p.systolic ?? 0;
      final dbp = p.diastolic ?? 0;
      final isHighPriority = sbp >= 140 || dbp >= 90 || sbp < 100 || p.triageStatus != 'NORMAL';
      if (isHighPriority) {
        final hn = '"${p.hn ?? '-'}"';
        final name = '"${p.fullName}"';
        final age = p.age?.toString() ?? '-';
        final bp = '"$sbp/$dbp mmHg"';
        final pulse = p.pulse?.toString() ?? '-';
        final status = '"${p.triageStatus}"';
        final med = p.hasMedication ? 'มี' : 'ไม่มี';
        final diseases = '"${p.underlyingDiseases?.replaceAll('"', '""') ?? '-'}"';
        buffer.writeln('$hn,$name,$age,$bp,$pulse,$status,$med,$diseases');
      }
    }

    final timestamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
    _downloadCsvFile(buffer.toString(), 'ncds_clinical_performance_report_$timestamp.csv');
  }
}