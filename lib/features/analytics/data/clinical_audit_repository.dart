import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataQualitySummary {
  final int totalPatients;
  final int missingBp30d;
  final int missingAnnualLab;
  final int highRiskNoFu;

  DataQualitySummary({
    required this.totalPatients,
    required this.missingBp30d,
    required this.missingAnnualLab,
    required this.highRiskNoFu,
  });

  factory DataQualitySummary.fromMap(Map<String, dynamic> map) {
    return DataQualitySummary(
      totalPatients: (map['total_patients'] as num?)?.toInt() ?? 0,
      missingBp30d: (map['missing_bp_30d'] as num?)?.toInt() ?? 0,
      missingAnnualLab: (map['missing_annual_lab'] as num?)?.toInt() ?? 0,
      highRiskNoFu: (map['high_risk_no_fu'] as num?)?.toInt() ?? 0,
    );
  }
}

class DataQualityIssue {
  final String patientId;
  final String hn;
  final String patientName;
  final int? age;
  final String issueType;
  final String issueDetail;
  final DateTime? lastActionDate;

  DataQualityIssue({
    required this.patientId,
    required this.hn,
    required this.patientName,
    this.age,
    required this.issueType,
    required this.issueDetail,
    this.lastActionDate,
  });

  factory DataQualityIssue.fromMap(Map<String, dynamic> map) {
    return DataQualityIssue(
      patientId: map['patient_id']?.toString() ?? '',
      hn: map['hn']?.toString() ?? '-',
      patientName: map['patient_name']?.toString() ?? 'ผู้ป่วย',
      age: (map['age'] as num?)?.toInt(),
      issueType: map['issue_type']?.toString() ?? '',
      issueDetail: map['issue_detail']?.toString() ?? '',
      lastActionDate: DateTime.tryParse(map['last_action_date']?.toString() ?? ''),
    );
  }
}

class CdssAuditSummary {
  final int totalEvents;
  final int guidelineAdherent;
  final int overrideCount;
  final double adherenceRate;

  CdssAuditSummary({
    required this.totalEvents,
    required this.guidelineAdherent,
    required this.overrideCount,
    required this.adherenceRate,
  });

  factory CdssAuditSummary.fromMap(Map<String, dynamic> map) {
    return CdssAuditSummary(
      totalEvents: (map['total_cdss_events'] as num?)?.toInt() ?? 0,
      guidelineAdherent: (map['guideline_adherent'] as num?)?.toInt() ?? 0,
      overrideCount: (map['override_count'] as num?)?.toInt() ?? 0,
      adherenceRate: (map['adherence_rate'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

final clinicalAuditRepositoryProvider = Provider<ClinicalAuditRepository>((ref) {
  return ClinicalAuditRepository(Supabase.instance.client);
});

final dataQualitySummaryProvider = FutureProvider.autoDispose<DataQualitySummary>((ref) async {
  return ref.watch(clinicalAuditRepositoryProvider).fetchDataQualitySummary();
});

final dataQualityIssuesProvider = FutureProvider.autoDispose<List<DataQualityIssue>>((ref) async {
  return ref.watch(clinicalAuditRepositoryProvider).fetchDataQualityIssues();
});

final cdssAuditSummaryProvider = FutureProvider.autoDispose<CdssAuditSummary>((ref) async {
  return ref.watch(clinicalAuditRepositoryProvider).fetchCdssAuditSummary();
});

class ClinicalAuditRepository {
  final SupabaseClient _client;
  ClinicalAuditRepository(this._client);

  Future<DataQualitySummary> fetchDataQualitySummary() async {
    try {
      final res = await _client.rpc('get_data_quality_summary');
      return DataQualitySummary.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('⚠️ Fetch data quality summary error: $e');
      return DataQualitySummary(totalPatients: 0, missingBp30d: 0, missingAnnualLab: 0, highRiskNoFu: 0);
    }
  }

  Future<List<DataQualityIssue>> fetchDataQualityIssues() async {
    try {
      final res = await _client.rpc('get_data_quality_issues');
      return (res as List<dynamic>)
          .map((item) => DataQualityIssue.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Fetch data quality issues error: $e');
      return [];
    }
  }

  Future<CdssAuditSummary> fetchCdssAuditSummary() async {
    try {
      final res = await _client.rpc('get_cdss_audit_summary');
      return CdssAuditSummary.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('⚠️ Fetch CDSS audit summary error: $e');
      return CdssAuditSummary(totalEvents: 0, guidelineAdherent: 0, overrideCount: 0, adherenceRate: 100.0);
    }
  }
}