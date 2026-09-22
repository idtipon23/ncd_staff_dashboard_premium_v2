// lib/features/settings/data/clinic_settings_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// บทบาทบุคลากรทางการแพทย์ (Staff Roles)
enum StaffRole {
  nurse(
    roleName: 'พยาบาลวิชาชีพ / เวชปฏิบัติ',
    roleCode: 'NURSE',
    description: 'ดูแลการคัดกรองด่วน, ติดตามคิวนัดหมาย, ส่งคำแนะนำและสื่อสารผ่าน LINE',
  ),
  physician(
    roleName: 'แพทย์ผู้รักษา (Physician / MD)',
    roleCode: 'PHYSICIAN',
    description: 'วินิจฉัยและสั่งการรักษา, ปรับเปลี่ยนขนาดยา CDSS, บันทึกการ Override สูตรยา',
  ),
  director(
    roleName: 'ผู้บริหารคลินิก / หัวหน้าหน่วยบริการ',
    roleCode: 'DIRECTOR',
    description: 'กำกับดูแลตัวชี้วัดคุณภาพระดับประชากร, ส่งออกรายงานสถิติคลินิก, กำหนดเกณฑ์ระบบ',
  );

  final String roleName;
  final String roleCode;
  final String description;

  const StaffRole({
    required this.roleName,
    required this.roleCode,
    required this.description,
  });
}
// ข้อมูลสถานพยาบาลและหน่วยบริการ (Multi-tenant Facility Info)
class ClinicFacilityInfo {
  final String hospitalId;
  final String hospitalName;
  final String province;
  final String district;
  final String healthRegion;

  const ClinicFacilityInfo({
    this.hospitalId = 'MAIN_CLINIC',
    this.hospitalName = 'ศูนย์บริการสาธารณสุขและคลินิก NCDs คุณภาพ',
    this.province = 'ชลบุรี',
    this.district = 'ศรีราชา',
    this.healthRegion = 'เขตสุขภาพที่ 6',
  });
}

final currentFacilityProvider = StateProvider<ClinicFacilityInfo>((ref) {
  return const ClinicFacilityInfo();
});

/// ค่าเกณฑ์การเฝ้าระวังทางคลินิก (Clinical Threshold Settings)
class ClinicThresholdConfig {
  final int crisisSystolic;
  final int crisisDiastolic;
  final int lowSystolicThreshold;
  final int lowDiastolicThreshold;
  final int lostToFollowUpDays;
  final double targetBpControlRate;

  const ClinicThresholdConfig({
    this.crisisSystolic = 180,
    this.crisisDiastolic = 110,
    this.lowSystolicThreshold = 100,
    this.lowDiastolicThreshold = 60,
    this.lostToFollowUpDays = 30,
    this.targetBpControlRate = 60.0,
  });

  ClinicThresholdConfig copyWith({
    int? crisisSystolic,
    int? crisisDiastolic,
    int? lowSystolicThreshold,
    int? lowDiastolicThreshold,
    int? lostToFollowUpDays,
    double? targetBpControlRate,
  }) {
    return ClinicThresholdConfig(
      crisisSystolic: crisisSystolic ?? this.crisisSystolic,
      crisisDiastolic: crisisDiastolic ?? this.crisisDiastolic,
      lowSystolicThreshold: lowSystolicThreshold ?? this.lowSystolicThreshold,
      lowDiastolicThreshold: lowDiastolicThreshold ?? this.lowDiastolicThreshold,
      lostToFollowUpDays: lostToFollowUpDays ?? this.lostToFollowUpDays,
      targetBpControlRate: targetBpControlRate ?? this.targetBpControlRate,
    );
  }
}

/// Provider สำหรับจัดการบทบาทบุคลากรปัจจุบัน (รองรับการสลับมุมมองทดสอบการใช้งาน)
final currentStaffRoleProvider = StateProvider<StaffRole>((ref) => StaffRole.nurse);

/// Provider สำหรับจัดการค่าเกณฑ์การเฝ้าระวังระดับคลินิก
final clinicThresholdConfigProvider = StateProvider<ClinicThresholdConfig>((ref) {
  return const ClinicThresholdConfig();
});