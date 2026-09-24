import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'patient_detail_model.dart';
import 'patient_triage_model.dart';
import '../../triage/domain/care_gap_rules.dart';
import '../../analytics/domain/population_kpi_rules.dart';


/// สถานะการคัดกรองผู้ป่วย
enum TriageCategory { critical, overTreatment, hypotension, warning, normal }

/// ฟังก์ชันตรวจสอบว่าคนไข้ได้รับยา/มีประวัติการรักษาด้วยยาหรือไม่
bool checkPatientHasMedication(PatientTriageModel p) {
  return p.hasMedication;
}

/// ฟังก์ชันประเมินสถานะ Triage กลางที่ใช้ร่วมกันทั้งหน้าจอและ Provider
TriageCategory evaluatePatientTriage(PatientTriageModel p) {
  final sbp = p.systolic ?? 0;
  final dbp = p.diastolic ?? 0;
  final bool hasMeds = checkPatientHasMedication(p);

  // 1. เคสวิกฤตความดันโลหิตสูง Hypertensive Crisis (SBP >= 180 หรือ DBP >= 110)
  if (sbp >= 180 || dbp >= 110) {
    return TriageCategory.critical;
  }

  // 2. ตรวจจับภาวะความดันต่ำผิดปกติ (SBP < 100 หรือ DBP < 60) รวมถึงเคส SBP < 70
  if ((sbp > 0 && sbp < 100) || (dbp > 0 && dbp < 60)) {
    // ⚠️ ต้องมีการ Treat (ได้รับยา) มาก่อนเท่านั้น ถึงจะเป็น Over-treatment
    if (hasMeds) {
      return TriageCategory.overTreatment; // สีม่วง
    } else {
      return TriageCategory.hypotension;   // สีฟ้า (ความดันต่ำตามธรรมชาติ / ไม่เคยได้ยา)
    }
  }

  // 3. เฝ้าระวังความดันสูง (Stage 1-2): SBP >= 140 หรือ DBP >= 90
  if (sbp >= 140 || dbp >= 90) {
    return TriageCategory.warning;
  }

  // 4. ควบคุมได้ตามเกณฑ์
  return TriageCategory.normal;
}

// 1. ช่องค้นหา (HN หรือ ชื่อ-สกุล)
final searchQueryProvider = StateProvider<String>((ref) => '');

// 2. ตัวกรองสถานะ Triage ('ALL', 'CRITICAL', 'OVER_TREATMENT', 'HYPOTENSION', 'WARNING', 'NORMAL')
final selectedStatusFilterProvider = StateProvider<String>((ref) => 'ALL');

// 3. Provider ที่คำนวณและกรองข้อมูลผู้ป่วยตาม Search & Filter อัตโนมัติ
final filteredPatientListProvider = Provider.autoDispose<List<PatientTriageModel>>((ref) {
  final triageAsync = ref.watch(triageOverviewProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(selectedStatusFilterProvider);

  return triageAsync.maybeWhen(
    data: (patients) {
      return patients.where((p) {
        final matchesQuery = query.isEmpty ||
            p.fullName.toLowerCase().contains(query) ||
            (p.hn != null && p.hn!.toLowerCase().contains(query));

        if (!matchesQuery) return false;
        if (statusFilter == 'ALL') return true;

        final category = evaluatePatientTriage(p);
        switch (statusFilter) {
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
          default:
            return p.triageStatus == statusFilter;
        }
      }).toList();
    },
    orElse: () => [],
  );
});

// Provider คำนวณ Clinical Quality KPIs อัตโนมัติจากทะเบียนคนไข้ทั้งหมด
final populationQualityKpiProvider = Provider.autoDispose<PopulationKpiSummary>((ref) {
  final triageAsync = ref.watch(triageOverviewProvider);
  final patients = triageAsync.asData?.value ?? const [];
  return PopulationKpiRules.computeQualityKpis(patients);
});

final patientCareGapsProvider = Provider.autoDispose.family<List<CareGapItem>, PatientDetailData>((ref, detailData) {
  return CareGapRules.evaluateCareGaps(
    patient: detailData.patient,
    vitals: detailData.vitalSigns,
    latestLab: detailData.latestLab,
    appointments: detailData.appointments,
  );
});

final triageRepositoryProvider = Provider<TriageRepository>((ref) {
  return TriageRepository(Supabase.instance.client);
});

final triageOverviewProvider = FutureProvider.autoDispose<List<PatientTriageModel>>((ref) async {
  final repo = ref.watch(triageRepositoryProvider);
  return repo.fetchTriageOverview();
});

final recentActivityProvider = FutureProvider.autoDispose<List<ActivityLogEntry>>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('staff_notes')
        .select('note_text, staff_name, created_at')
        .order('created_at', ascending: false)
        .limit(8);

    return (res as List).map((item) {
      final staff = item['staff_name'] ?? 'เจ้าหน้าที่';
      final note = item['note_text'] ?? '';

      return ActivityLogEntry(
        title: 'บันทึกคำสั่งการทางคลินิก',
        description: '$note ($staff)',
        createdAt: DateTime.tryParse(item['created_at']?.toString() ?? ''),
      );
    }).toList();
  } catch (e) {
    debugPrint('⚠️ Query recent activity from staff_notes failed: $e');
    return const [];
  }
});

final aggregateBpTrendProvider = FutureProvider.autoDispose<List<DailyBpAverage>>((ref) async {
  final repo = ref.watch(triageRepositoryProvider);
  return repo.fetchAggregateBpTrend();
});

class ActivityLogEntry {
  final String title;
  final String? description;
  final DateTime? createdAt;

  const ActivityLogEntry({
    required this.title,
    this.description,
    this.createdAt,
  });

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) {
    return ActivityLogEntry(
      title: (map['title'] ?? map['activity_type'] ?? 'กิจกรรมล่าสุด').toString(),
      description: map['description']?.toString() ?? map['details']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}

class DailyBpAverage {
  final DateTime date;
  final double systolic;
  final double diastolic;

  const DailyBpAverage({
    required this.date,
    required this.systolic,
    required this.diastolic,
  });
}

final patientDetailProvider = FutureProvider.family.autoDispose<PatientDetailData, String>((ref, patientId) async {
  final repo = ref.watch(triageRepositoryProvider);
  return repo.fetchPatientDetail(patientId);
});

class TriageRepository {
  final SupabaseClient _client;
  TriageRepository(this._client);

  Future<List<PatientTriageModel>> fetchTriageOverview() async {
    // 1. ดึงข้อมูลภาพรวมจาก View
    final response = await _client
        .from('triage_overview_view')
        .select('*')
        .order('triage_status', ascending: true);

    final rawList = response as List;

    // 2. ดึงข้อมูลประวัติการใช้ยา เพื่อคัดกรองกลุ่ม Medicated ได้แม่นยำ
    final Set<String> medicatedPatientIds = {};

    try {
      final medRes = await _client.from('medication_logs').select('patient_id');
      for (final m in (medRes as List)) {
        final pid = m['patient_id']?.toString();
        if (pid != null && pid.isNotEmpty) {
          medicatedPatientIds.add(pid);
        }
      }
    } catch (_) {
      // ข้ามหากไม่มีตาราง
    }

    try {
      final patRes = await _client.from('patients').select('id, current_med_classes');
      for (final p in (patRes as List)) {
        final pid = p['id']?.toString();
        final meds = p['current_med_classes'];
        if (pid != null && meds is List && meds.isNotEmpty) {
          medicatedPatientIds.add(pid);
        }
      }
    } catch (_) {
      // ข้ามหากไม่มีคอลัมน์
    }

    // 3. แปลงเป็น PatientTriageModel พร้อมผูกสถานะการใช้ยา
    final List<PatientTriageModel> patients = [];
    for (final row in rawList) {
      final map = Map<String, dynamic>.from(row);
      final pid = (map['patient_id'] ?? map['id'])?.toString() ?? '';

      final bool hasMed = map['has_medication'] == true || medicatedPatientIds.contains(pid);
      map['has_medication'] = hasMed;

      final model = PatientTriageModel.fromMap(map);
      patients.add(model);
    }

    return patients;
  }

  Future<List<ActivityLogEntry>> fetchRecentActivity() async {
    try {
      final response = await _client
          .from('activity_log')
          .select('*')
          .order('created_at', ascending: false)
          .limit(8);

      return (response as List)
          .map((row) => ActivityLogEntry.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      // activity_log is optional until the Supabase table is provisioned.
      return [];
    }
  }
  /// ดึงและจัดกลุ่มยาปัจจุบันของผู้ป่วยสำหรับส่งเข้า CDSS Engine
  Future<List<String>> fetchPatientMedicationClasses(String patientId) async {
    try {
      final medRes = await _client
          .from('medication_logs')
          .select('medication_name')
          .eq('patient_id', patientId);

      final List<dynamic> medLogs = medRes as List<dynamic>;
      final Set<String> detectedClasses = {};

      for (final m in medLogs) {
        final name = (m['medication_name'] ?? '').toString().toLowerCase();
        if (name.contains('dipine') || name.contains('norvasc') || name.contains('amlodipine') || name.contains('manidipine')) {
          detectedClasses.add('CCB');
        } else if (name.contains('pril') || name.contains('enalapril') || name.contains('lisinopril')) {
          detectedClasses.add('ACEI');
        } else if (name.contains('sartan') || name.contains('losartan') || name.contains('valsartan') || name.contains('candesartan')) {
          detectedClasses.add('ARB');
        } else if (name.contains('hctz') || name.contains('thiazide') || name.contains('indapamide') || name.contains('chlorthalidone')) {
          detectedClasses.add('Thiazide-Diuretic');
        } else if (name.contains('furosemide') || name.contains('lasix')) {
          detectedClasses.add('Loop-Diuretic');
        } else if (name.contains('spironolactone') || name.contains('aldactone')) {
          detectedClasses.add('Spironolactone');
        } else if (name.contains('lol') || name.contains('atenolol') || name.contains('metoprolol') || name.contains('carvedilol') || name.contains('bisoprolol')) {
          detectedClasses.add('Beta-blocker');
        } else if (name.contains('zosin') || name.contains('doxazosin')) {
          detectedClasses.add('Alpha-blocker');
        } else if (name.isNotEmpty) {
          detectedClasses.add(m['medication_name'].toString());
        }
      }
      return detectedClasses.toList();
    } catch (e) {
      debugPrint('⚠️ Fetch medication classes error: $e');
      return [];
    }
  }

  /// ดึงค่า Creatinine ครั้งก่อนหน้าเพื่อประเมินเกณฑ์ความปลอดภัย Creatinine Rise > 30%
  Future<double> fetchBaselineCreatinine(String patientId) async {
    try {
      final pastLabs = await _client
          .from('lab_results')
          .select('creatinine')
          .eq('patient_id', patientId)
          .order('lab_date', ascending: false)
          .limit(2);

      final list = pastLabs as List<dynamic>;
      if (list.length > 1) {
        return (list[1]['creatinine'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('⚠️ Fetch baseline creatinine error: $e');
      return 0.0;
    }
  }

  Future<List<DailyBpAverage>> fetchAggregateBpTrend() async {
    try {
      final response = await _client
          .from('vital_signs')
          .select('recorded_at, systolic, diastolic')
          .order('recorded_at', ascending: true);

        debugPrint('Aggregate BP trend visible vital_signs rows: ${(response as List).length}');
      final dailyValues = <DateTime, List<double>>{};
        for (final row in response) {
        final map = Map<String, dynamic>.from(row);
        final recordedAt = DateTime.tryParse(map['recorded_at']?.toString() ?? '');
        final systolic = double.tryParse(map['systolic']?.toString() ?? '');
        final diastolic = double.tryParse(map['diastolic']?.toString() ?? '');
        if (recordedAt == null || systolic == null || diastolic == null) continue;

        final date = DateTime(recordedAt.year, recordedAt.month, recordedAt.day);
        dailyValues.putIfAbsent(date, () => []).addAll([systolic, diastolic]);
      }

      return dailyValues.entries.map((entry) {
        final values = entry.value;
        final systolicValues = [for (var i = 0; i < values.length; i += 2) values[i]];
        final diastolicValues = [for (var i = 1; i < values.length; i += 2) values[i]];
        return DailyBpAverage(
          date: entry.key,
          systolic: systolicValues.reduce((a, b) => a + b) / systolicValues.length,
          diastolic: diastolicValues.reduce((a, b) => a + b) / diastolicValues.length,
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Query aggregate BP trend from vital_signs failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Aggregate trend is optional and must not prevent the overview from loading.
      return [];
    }
  }

  Future<PatientDetailData> fetchPatientDetail(String patientId) async {
    // 1. ดึงข้อมูลคนไข้
    final patientRes = await _client
        .from('patients')
        .select('*')
        .eq('id', patientId)
        .maybeSingle();

    // 2. ดึงประวัติสัญญาณชีพย้อนหลัง
    final vitalsRes = await _client
        .from('vital_signs')
        .select('*')
        .eq('patient_id', patientId)
        .order('recorded_at', ascending: false)
        .limit(10);

    // 3. ดึงผลแล็บล่าสุด
    final labRes = await _client
        .from('lab_results')
        .select('*')
        .eq('patient_id', patientId)
        .order('lab_date', ascending: false)
        .limit(1);

    // 4. ดึงบันทึกมื้ออาหารล่าสุด
    final foodRes = await _client
        .from('food_logs')
        .select('*')
        .eq('patient_id', patientId)
        .order('recorded_at', ascending: false)
        .limit(5);

    // 5. ดึงบันทึกของเจ้าหน้าที่
    final notesRes = await _client
        .from('staff_notes')
        .select('*')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    final appointmentsRes = await _client
        .from('appointments')
        .select('*')
        .eq('patient_id', patientId)
        .order('appointment_date', ascending: false);

    return PatientDetailData(
      patient: patientRes != null ? Map<String, dynamic>.from(patientRes) : {},
      vitalSigns: List<Map<String, dynamic>>.from(vitalsRes),
      latestLab: labRes.isNotEmpty ? Map<String, dynamic>.from(labRes.first) : null,
      recentFoods: List<Map<String, dynamic>>.from(foodRes),
      staffNotes: List<Map<String, dynamic>>.from(notesRes),
      appointments: List<Map<String, dynamic>>.from(appointmentsRes),
    );
  }

  Future<void> saveStaffNote(String patientId, String noteText, String staffName) async {
    await sendClinicalAction(
      patientId: patientId,
      noteText: noteText,
      staffName: staffName,
      sendToLine: false,
    );
  }

  Future<void> sendClinicalAction({
    required String patientId,
    required String noteText,
    required String staffName,
    required bool sendToLine,
    String? lineUserId,
  }) async {
    final res = await _client.functions.invoke('line-notifier', body: {
      'action': 'send_custom_message',
      'patient_id': patientId,
      'staff_name': staffName,
      'text': noteText,
      'send_to_line': sendToLine,
      'to': lineUserId,
    });

    if (res.status != 200) {
      throw Exception('ไม่สามารถส่งคำแนะนำได้ (HTTP ${res.status}): ${res.data}');
    }
  }

  RealtimeChannel listenToCriticalVitals({
    required Function(Map<String, dynamic> newVital) onCriticalEvent,
  }) {
    return _client.channel('public:vital_signs_alerts')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'vital_signs',
        callback: (payload) {
          final newRecord = payload.newRecord;
          final sys = (newRecord['systolic'] as num?)?.toInt() ?? 0;
          final dia = (newRecord['diastolic'] as num?)?.toInt() ?? 0;

          // แจ้งเตือนทั้งความดันวิกฤตสูง (>= 180/110) และความดันตกวิกฤต (< 90)
          if (sys >= 180 || dia >= 110 || (sys > 0 && sys < 90)) {
            onCriticalEvent(newRecord);
          }
        },
      ).subscribe();
  }

  Future<void> scheduleFollowUp({
    required String patientId,
    required DateTime followUpDate,
    required String reason,
    required String doctorOrClinic,
    bool needFasting = false,
  }) async {
    final dateStr = followUpDate.toIso8601String().split('T').first;

    await _client.from('appointments').insert({
      'patient_id': patientId,
      'appointment_date': dateStr,
      'appointment_time': '09:00',
      'clinic_name': doctorOrClinic,
      'reason': reason,
      'need_fasting': needFasting,
      'status': 'scheduled',
    });

    final noteContent = '[นัดหมาย F/U] วันที่ $dateStr ($reason) คลินิก: $doctorOrClinic${needFasting ? " (งดน้ำ-อาหาร)" : ""}';

    await _client.functions.invoke('line-notifier', body: {
      'action': 'send_custom_message',
      'patient_id': patientId,
      'staff_name': 'พยาบาลเวชปฏิบัติ',
      'text': noteContent,
      'send_to_line': false,
    });
  }
}
// เพิ่มเติมใน triage_repository.dart

/// โมเดลข้อมูล Alert ทางคลินิก
class ClinicalAlertItem {
  final String id;
  final String patientId;
  final String alertType;
  final String severity;
  final String triggerReason;
  final String status; // 'NEW', 'ACKNOWLEDGED', 'IN_PROGRESS', 'RESOLVED'
  final String? staffName;
  final DateTime createdAt;

  ClinicalAlertItem({
    required this.id,
    required this.patientId,
    required this.alertType,
    required this.severity,
    required this.triggerReason,
    required this.status,
    this.staffName,
    required this.createdAt,
  });

  factory ClinicalAlertItem.fromMap(Map<String, dynamic> map) {
    return ClinicalAlertItem(
      id: map['id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      alertType: map['alert_type'] ?? 'CRITICAL_BP',
      severity: map['severity'] ?? 'CRITICAL',
      triggerReason: map['trigger_reason'] ?? '',
      status: map['status'] ?? 'NEW',
      staffName: map['staff_name'],
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// Provider สำหรับดึง Active Alerts ที่ยังไม่ Resolved
final activeAlertsProvider = FutureProvider.autoDispose<List<ClinicalAlertItem>>((ref) async {
  final repo = ref.watch(triageRepositoryProvider);
  return repo.fetchActiveAlerts();
});


// Provider ดึงรายการยาปัจจุบันของผู้ป่วย
// ใน lib/features/overview/data/triage_repository.dart

final patientMedicationsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  try {
    // ใช้นามคอลัมน์ recorded_at ตามโครงสร้างจริงของ medication_logs
    final res = await Supabase.instance.client
        .from('medication_logs')
        .select()
        .eq('patient_id', patientId)
        .order('recorded_at', ascending: false);

    return List<Map<String, dynamic>>.from(res as List);
  } catch (e) {
    debugPrint('⚠️ Query with recorded_at failed, retrying without order: $e');
    // Fallback ปลอดภัย กรณีไม่มีการระบุคอลัมน์เวลา
    final res = await Supabase.instance.client
        .from('medication_logs')
        .select()
        .eq('patient_id', patientId);

    return List<Map<String, dynamic>>.from(res as List);
  }
});

extension TriageCdssAuditExtension on TriageRepository {
  /// บันทึกการประเมินและการตัดสินใจของเจ้าหน้าที่ต่อระบบ CDSS (CDSS Audit Trail)
  Future<void> logCdssEvent({
    required String patientId,
    required String ruleId,
    String ruleVersion = 'TH-HT-2024.1',
    String? severity,
    required Map<String, dynamic> inputSnapshot,
    required Map<String, dynamic> recommendation,
    required String staffAction, // 'ACCEPTED', 'OVERRIDDEN', 'DISMISSED'
    String? overrideReason,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final staffName = (user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            user?.email ??
            'เจ้าหน้าที่เวชปฏิบัติ')
        .toString();

    await Supabase.instance.client.from('cdss_events').insert({
      'patient_id': patientId,
      'staff_id': user?.id,
      'staff_name': staffName,
      'rule_id': ruleId,
      'rule_version': ruleVersion,
      'severity': severity ?? 'INFO',
      'input_snapshot': inputSnapshot,
      'recommendation': recommendation,
      'staff_action': staffAction,
      'override_reason': overrideReason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
// เพิ่มเมธอดเหล่านี้ลงในคลาส TriageRepository:
extension TriageAlertLifecycle on TriageRepository {
  /// ดึง Alert ที่ยังค้างอยู่และต้องดำเนินการ
  Future<List<ClinicalAlertItem>> fetchActiveAlerts() async {
    final response = await Supabase.instance.client
        .from('clinical_alerts')
        .select()
        .neq('status', 'RESOLVED')
        .order('created_at', ascending: false)
        .limit(20);

    return (response as List<dynamic>)
        .map((item) => ClinicalAlertItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// เจ้าหน้าที่กดรับทราบเคส (Acknowledge)
  Future<void> acknowledgeAlert(String alertId) async {
    final user = Supabase.instance.client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'พยาบาลเวชปฏิบัติ';

    await Supabase.instance.client.from('clinical_alerts').update({
      'status': 'ACKNOWLEDGED',
      'staff_id': user?.id,
      'staff_name': staffName,
      'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', alertId);
  }

  /// ปิดเคส Alert เมื่อดำเนินการเสร็จสิ้น (Resolve)
  Future<void> resolveAlert(String alertId, {String? resolution}) async {
    await Supabase.instance.client.from('clinical_alerts').update({
      'status': 'RESOLVED',
      'resolution': resolution ?? 'ได้รับการดูแลและประเมินซ้ำเรียบร้อยแล้ว',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', alertId);
  }
}
// เพิ่มเติมใน triage_repository.dart

enum TimelineEventType { vital, alert, staffAction, appointment }

/// โมเดลเหตุการณ์ทางคลินิกสำหรับ Clinical Timeline
class ClinicalTimelineEvent {
  final String id;
  final DateTime timestamp;
  final TimelineEventType eventType;
  final String title;
  final String description;
  final String severity; // 'CRITICAL', 'HIGH', 'WARNING', 'NORMAL', 'INFO'
  final String? actor; // e.g., 'พยาบาลเวชปฏิบัติ', 'คนไข้บันทึกผ่าน PWA'

  ClinicalTimelineEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.title,
    required this.description,
    required this.severity,
    this.actor,
  });
}

// Provider สำหรับดึง Timeline ของผู้ป่วยรายบุคคล
final patientTimelineProvider = FutureProvider.autoDispose.family<List<ClinicalTimelineEvent>, String>((ref, patientId) async {
  final repo = ref.watch(triageRepositoryProvider);
  return repo.fetchPatientTimeline(patientId);
});

extension TriageTimelineExtension on TriageRepository {
  /// รวบรวมเหตุการณ์ทางคลินิกจากหลายแหล่งข้อมูลมาสร้างเป็น Timeline เดียวกัน
  Future<List<ClinicalTimelineEvent>> fetchPatientTimeline(String patientId) async {
    final List<ClinicalTimelineEvent> events = [];

    try {
      // 1. ดึงสัญญาณชีพ (Vital Signs)
      final vitalsRes = await Supabase.instance.client
          .from('vital_signs')
          .select('id, systolic, diastolic, pulse, urgency_level, recorded_at, spoken_feedback')
          .eq('patient_id', patientId)
          .order('recorded_at', ascending: false)
          .limit(15);

      for (final v in vitalsRes as List) {
        final date = DateTime.tryParse(v['recorded_at'] ?? '') ?? DateTime.now();
        final sys = v['systolic'] ?? 0;
        final dia = v['diastolic'] ?? 0;
        final isCrisis = sys >= 180 || dia >= 110;
        final isLow = (sys > 0 && sys < 100) || (dia > 0 && dia < 60);

        String severity = 'NORMAL';
        if (isCrisis) {
          severity = 'CRITICAL';
        } else if (isLow) {
          severity = 'WARNING';
        }

        events.add(ClinicalTimelineEvent(
          id: 'vital_${v['id']}',
          timestamp: date,
          eventType: TimelineEventType.vital,
          title: 'บันทึกความดันโลหิต: $sys/$dia mmHg (ชีพจร ${v['pulse'] ?? '-'} bpm)',
          description: v['spoken_feedback'] ?? (isCrisis ? '🚨 ตรวจพบภาวะความดันวิกฤต' : 'สัญญาณชีพทั่วไป'),
          severity: severity,
          actor: 'บันทึกผ่าน Patient PWA',
        ));
      }

      // 2. ดึงประวัติคำสั่งการ/ส่งข้อความของเจ้าหน้าที่ (Staff Notes)
      final notesRes = await Supabase.instance.client
          .from('staff_notes')
          .select('id, note_text, staff_name, created_at')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(10);

      for (final n in notesRes as List) {
        final date = DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now();

        events.add(ClinicalTimelineEvent(
          id: 'note_${n['id']}',
          timestamp: date,
          eventType: TimelineEventType.staffAction,
          title: 'บันทึกคำสั่งการทางคลินิก (Clinical Note)',
          description: n['note_text'] ?? '',
          severity: 'INFO',
          actor: n['staff_name'] ?? 'เจ้าหน้าที่เวชปฏิบัติ',
        ));
      }

      // 3. ดึงประวัติการนัดหมาย (Appointments)
      final apptRes = await Supabase.instance.client
          .from('appointments')
          .select('id, appointment_date, reason, clinic_name, status, created_at')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(5);

      for (final a in apptRes as List) {
        final date = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final apptDate = a['appointment_date']?.toString().split('T').first ?? '-';

        events.add(ClinicalTimelineEvent(
          id: 'appt_${a['id']}',
          timestamp: date,
          eventType: TimelineEventType.appointment,
          title: 'สร้างนัดหมายติดตามอาการ (วันนัด: $apptDate)',
          description: 'คลินิก: ${a['clinic_name'] ?? 'NCDs'} | เหตุผล: ${a['reason'] ?? 'ตรวจติดตามความดัน'}',
          severity: 'NORMAL',
          actor: 'ระบบนัดหมายคลินิก',
        ));
      }

      // 4. เรียงลำดับเหตุการณ์ตามวันและเวลาล่าสุดขึ้นก่อน
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error compiling clinical timeline: $e');
    }

    return events;
  }
}
