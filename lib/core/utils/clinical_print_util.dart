import 'dart:html' as html;
import '../../features/overview/data/opd_visit_repository.dart';

class ClinicalPrintUtil {
  /// 1. พิมพ์ใบสรุปการตรวจรักษาผู้ป่วยนอก (OPD Clinical Summary)
  /// 1. พิมพ์ใบสรุปการตรวจรักษาผู้ป่วยนอก (OPD Clinical Summary)
  static void printOpdSummary({
    required String clinicName,
    required String patientName,
    required String hn,
    String? age,
    String? gender,
    String? underlyingDiseases,
    required OpdVisitModel visit,
    Map<String, dynamic>? latestLab, // 👈 เพิ่มพารามิเตอร์นี้
  }) {
    final dateStr = '${visit.visitDate.day}/${visit.visitDate.month}/${visit.visitDate.year + 543}';
    final timeStr = '${visit.visitDate.hour.toString().padLeft(2, '0')}:${visit.visitDate.minute.toString().padLeft(2, '0')} น.';

    // สร้างตารางแล็บถ้ามีข้อมูล
    String labHtmlSection = '';
    if (latestLab != null && latestLab.isNotEmpty) {
      labHtmlSection = '''
      <div class="section-title">ผลตรวจทางห้องปฏิบัติการล่าสุด (Laboratory Profile - วันที่ ${latestLab['lab_date'] ?? '-'})</div>
      <table class="pe-table">
        <tr>
          <td class="label">Glycemic</td>
          <td>FBS: ${latestLab['fbs'] ?? '-'} mg/dL, HbA1c: ${latestLab['hba1c'] ?? '-'} %</td>
          <td class="label">Lipid</td>
          <td>TC: ${latestLab['cholesterol'] ?? '-'}, TG: ${latestLab['triglycerides'] ?? '-'}, HDL: ${latestLab['hdl'] ?? '-'}, LDL: ${latestLab['ldl'] ?? '-'} mg/dL</td>
        </tr>
        <tr>
          <td class="label">Renal</td>
          <td>BUN: ${latestLab['bun'] ?? '-'}, Cr: ${latestLab['creatinine'] ?? '-'}, eGFR: ${latestLab['egfr'] ?? '-'} ml/min</td>
          <td class="label">Electrolytes</td>
          <td>Na: ${latestLab['sodium'] ?? '-'}, K: ${latestLab['potassium'] ?? '-'}, Cl: ${latestLab['chloride'] ?? '-'}, HCO3: ${latestLab['bicarbonate'] ?? '-'}</td>
        </tr>
        <tr>
          <td class="label">Liver</td>
          <td>AST: ${latestLab['ast'] ?? '-'}, ALT: ${latestLab['alt'] ?? '-'}, ALP: ${latestLab['alp'] ?? '-'} U/L</td>
          <td class="label">Urine/Other</td>
          <td>Uric: ${latestLab['uric_acid'] ?? '-'} mg/dL, UACR: ${latestLab['urine_microalbumin'] ?? '-'}, Protein: ${latestLab['urine_protein'] ?? '-'}</td>
        </tr>
      </table>
      ''';
    }

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>OPD Summary - $hn - $patientName</title>
  <style>
    @page { size: A4 portrait; margin: 15mm; }
    body { font-family: 'Sarabun', 'TH Sarabun New', Tahoma, sans-serif; font-size: 14px; color: #1e293b; line-height: 1.5; margin: 0; padding: 20px; }
    .header { text-align: center; border-bottom: 2px solid #0f172a; padding-bottom: 10px; margin-bottom: 16px; }
    .clinic-title { font-size: 20px; font-weight: bold; color: #0f172a; margin: 0; }
    .doc-title { font-size: 16px; font-weight: bold; color: #0284c7; margin-top: 4px; }
    .box { border: 1px solid #cbd5e1; border-radius: 6px; padding: 10px 14px; margin-bottom: 14px; background: #f8fafc; }
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
    .section-title { font-weight: bold; font-size: 14px; color: #0f172a; border-left: 4px solid #0284c7; padding-left: 8px; margin: 12px 0 6px 0; }
    .pe-table { width: 100%; border-collapse: collapse; margin-top: 6px; font-size: 13px; }
    .pe-table td { padding: 4px 8px; border: 1px solid #e2e8f0; }
    .pe-table td.label { font-weight: bold; width: 120px; background: #f1f5f9; }
    .rx-table { width: 100%; border-collapse: collapse; margin-top: 6px; font-size: 13px; }
    .rx-table th { background: #f1f5f9; border: 1px solid #cbd5e1; padding: 6px 8px; text-align: left; }
    .rx-table td { border: 1px solid #e2e8f0; padding: 6px 8px; }
    .footer { margin-top: 30px; display: flex; justify-content: flex-end; }
    .sign-box { text-align: center; width: 250px; }
    .sign-line { border-bottom: 1px dotted #475569; height: 40px; margin-bottom: 6px; }
    @media print {
      body { padding: 0; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="clinic-title">$clinicName</div>
    <div class="doc-title">ใบสรุปการตรวจรักษาผู้ป่วยนอก (OPD Clinical Summary)</div>
  </div>

  <div class="box grid-2">
    <div><strong>ชื่อ-สกุล:</strong> $patientName</div>
    <div><strong>เลขประจำตัวผู้ป่วย (HN):</strong> $hn</div>
    <div><strong>อายุ:</strong> ${age ?? '-'} ปี &nbsp;&nbsp; <strong>เพศ:</strong> ${gender ?? '-'}</div>
    <div><strong>วันที่ตรวจ:</strong> $dateStr เวลา $timeStr</div>
    <div style="grid-column: span 2;"><strong>โรคประจำตัว:</strong> ${underlyingDiseases ?? 'ไม่มี/ไม่ระบุ'}</div>
  </div>

  <div class="section-title">สัญญาณชีพแรกรับ (Vital Signs)</div>
  <div class="box grid-4">
    <div><strong>BP:</strong> ${visit.sbp != null && visit.dbp != null ? '${visit.sbp}/${visit.dbp} mmHg' : '-'}</div>
    <div><strong>ชีพจร:</strong> ${visit.pulse != null ? '${visit.pulse} bpm' : '-'}</div>
    <div><strong>อุณหภูมิ:</strong> ${visit.temperature != null ? '${visit.temperature} °C' : '-'}</div>
    <div><strong>หายใจ:</strong> ${visit.respiratoryRate != null ? '${visit.respiratoryRate} /min' : '-'}</div>
    <div><strong>น้ำหนัก:</strong> ${visit.weightKg != null ? '${visit.weightKg} kg' : '-'}</div>
    <div><strong>ส่วนสูง:</strong> ${visit.heightCm != null ? '${visit.heightCm} cm' : '-'}</div>
  </div>

  $labHtmlSection

  <div class="section-title">การซักประวัติ (History Taking)</div>
  <div style="margin-left: 10px; margin-bottom: 10px;">
    <div><strong>อาการสำคัญ (CC):</strong> ${visit.chiefComplaint}</div>
    ${visit.presentIllness != null && visit.presentIllness!.isNotEmpty ? '<div><strong>ประวัติปัจจุบัน (PI):</strong> ${visit.presentIllness}</div>' : ''}
    ${visit.medicationAllergy != null && visit.medicationAllergy!.isNotEmpty ? '<div style="color: #dc2626;"><strong>ประวัติแพ้ยา:</strong> ${visit.medicationAllergy}</div>' : ''}
  </div>

  <div class="section-title">การตรวจร่างกาย (Physical Examination)</div>
  <table class="pe-table">
    <tr><td class="label">General</td><td>${visit.peGeneral ?? 'Normal'}</td><td class="label">HEENT</td><td>${visit.peHeent ?? 'Normal'}</td></tr>
    <tr><td class="label">Heart</td><td>${visit.peHeart ?? 'Normal S1 S2, no murmur'}</td><td class="label">Lungs</td><td>${visit.peLungs ?? 'Clear both lungs'}</td></tr>
    <tr><td class="label">Abdomen</td><td>${visit.peAbdomen ?? 'Soft, not tender'}</td><td class="label">Extremities</td><td>${visit.peExtremities ?? 'No edema'}</td></tr>
  </table>

  <div class="section-title">การวินิจฉัยโรค (Diagnosis)</div>
  <div class="box" style="background: #eff6ff; border-color: #bfdbfe;">
    <span style="font-size: 15px; font-weight: bold; color: #1e3a8a;">${visit.diagnosisText}</span>
    ${visit.icd10Code != null && visit.icd10Code!.isNotEmpty ? ' <span style="color: #0284c7; font-weight: bold;">(ICD-10: ${visit.icd10Code})</span>' : ''}
  </div>

  <div class="section-title">แผนการรักษาและรายการยา (Plan & Orders)</div>
  ${visit.treatmentPlan != null && visit.treatmentPlan!.isNotEmpty ? '<div style="margin-left: 10px; margin-bottom: 8px;"><strong>คำแนะนำ:</strong> ${visit.treatmentPlan}</div>' : ''}

  ${visit.prescriptions.isNotEmpty ? '''
  <table class="rx-table">
    <thead><tr><th style="width: 40px;">ลำดับ</th><th>รายการยาและวิธีใช้</th></tr></thead>
    <tbody>
      ${visit.prescriptions.asMap().entries.map((e) => '<tr><td style="text-align: center;">${e.key + 1}</td><td>${e.value['item_name'] ?? e.value.toString()}</td></tr>').join('')}
    </tbody>
  </table>
  ''' : '<div style="margin-left: 10px; color: #64748b;">(ไม่มีรายการสั่งยาในครั้งนี้)</div>'}

  <div class="footer">
    <div class="sign-box">
      <div class="sign-line"></div>
      <div>( ${visit.doctorName} )</div>
      <div style="font-size: 12px; color: #64748b;">แพทย์ผู้ตรวจรักษา</div>
    </div>
  </div>

  <script>
    window.onload = function() { window.print(); }
  </script>
</body>
</html>
''';

    _openPrintWindow(htmlContent);
  }

  /// 2. พิมพ์ใบสั่งยาและจัดยา (Prescription Slip / Rx Order)
  static void printPrescriptionSlip({
    required String clinicName,
    required String patientName,
    required String hn,
    String? age,
    String? gender,
    required OpdVisitModel visit,
  }) {
    final dateStr = '${visit.visitDate.day}/${visit.visitDate.month}/${visit.visitDate.year + 543}';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Rx - $hn - $patientName</title>
  <style>
    @page { size: A5 landscape; margin: 10mm; }
    body { font-family: 'Sarabun', 'TH Sarabun New', Tahoma, sans-serif; font-size: 13px; color: #0f172a; margin: 0; padding: 10px; }
    .header { display: flex; justify-content: space-between; border-bottom: 2px solid #059669; padding-bottom: 8px; margin-bottom: 10px; }
    .clinic-title { font-size: 16px; font-weight: bold; color: #059669; }
    .doc-title { font-size: 14px; font-weight: bold; color: #334155; }
    .info-grid { display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 6px; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 6px; padding: 8px 12px; margin-bottom: 12px; }
    .rx-table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    .rx-table th { background: #f8fafc; border: 1px solid #cbd5e1; padding: 6px; text-align: left; font-size: 12px; }
    .rx-table td { border: 1px solid #e2e8f0; padding: 8px; font-size: 13px; }
    .footer { margin-top: 24px; display: flex; justify-content: space-between; align-items: flex-end; }
    .sign-box { text-align: center; width: 200px; }
    .sign-line { border-bottom: 1px dotted #64748b; height: 35px; margin-bottom: 4px; }
    @media print { body { padding: 0; } }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="clinic-title">$clinicName</div>
      <div style="font-size: 12px; color: #64748b;">ใบสั่งยาและคำสั่งแพทย์ (Prescription Slip)</div>
    </div>
    <div style="text-align: right;">
      <div class="doc-title">วันที่: $dateStr</div>
      <div style="font-size: 12px; color: #64748b;">Dx: ${visit.diagnosisText}</div>
    </div>
  </div>

  <div class="info-grid">
    <div><strong>ผู้ป่วย:</strong> $patientName</div>
    <div><strong>HN:</strong> $hn</div>
    <div><strong>อายุ/เพศ:</strong> ${age ?? '-'} ปี / ${gender ?? '-'}</div>
    ${visit.medicationAllergy != null && visit.medicationAllergy!.isNotEmpty ? '<div style="grid-column: span 3; color: #dc2626; font-weight: bold;">⚠️ ประวัติแพ้ยา: ${visit.medicationAllergy}</div>' : ''}
  </div>

  <table class="rx-table">
    <thead>
      <tr>
        <th style="width: 35px; text-align: center;">#</th>
        <th>รายการยาและขนาด (Item / Strength)</th>
        <th>วิธีใช้และคำแนะนำ (Sig / Direction)</th>
        <th style="width: 60px; text-align: center;">ตรวจสอบ</th>
      </tr>
    </thead>
    <tbody>
      ${visit.prescriptions.isNotEmpty ? visit.prescriptions.asMap().entries.map((e) {
            final text = e.value['item_name']?.toString() ?? e.value.toString();
            return '''
            <tr>
              <td style="text-align: center;">${e.key + 1}</td>
              <td style="font-weight: bold;">$text</td>
              <td>ตามคำสั่งแพทย์ระบุ</td>
              <td style="text-align: center;">[ &nbsp; ]</td>
            </tr>
            ''';
          }).join('') : '<tr><td colspan="4" style="text-align: center; color: #94a3b8; padding: 20px;">ไม่มีรายการยา</td></tr>'}
    </tbody>
  </table>

  <div class="footer">
    <div style="font-size: 11px; color: #64748b;">
      * เภสัชกร/ผู้จัดยา: กรุณาตรวจสอบชื่อผู้ป่วยและขนาดยาก่อนจ่ายยา
    </div>
    <div class="sign-box">
      <div class="sign-line"></div>
      <div>( ${visit.doctorName} )</div>
      <div style="font-size: 11px; color: #64748b;">แพทย์ผู้สั่งจ่ายยา</div>
    </div>
  </div>

  <script>
    window.onload = function() { window.print(); }
  </script>
</body>
</html>
''';

    _openPrintWindow(htmlContent);
  }

  /// สร้าง Blob URL จาก HTML Content แล้วสั่งเปิดพิมพ์ในหน้าต่างใหม่
  static void _openPrintWindow(String content) {
    final blob = html.Blob([content], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    html.window.open(url, '_blank');

    // คืน Memory ให้เบราว์เซอร์หลังจากเปิดหน้าพิมพ์แล้ว
    Future.delayed(const Duration(minutes: 3), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}