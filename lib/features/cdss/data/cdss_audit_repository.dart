// lib/features/cdss/data/cdss_audit_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AnalyticsTimeframe {
  today(label: 'วันนี้', days: 1),
  sevenDays(label: '7 วัน', days: 7),
  thirtyDays(label: '30 วัน', days: 30),
  threeMonths(label: '3 เดือน', days: 90),
  sixMonths(label: '6 เดือน', days: 180),
  oneYear(label: '1 ปี', days: 365);

  final String label;
  final int days;
  const AnalyticsTimeframe({required this.label, required this.days});
}

final selectedTimeframeProvider = StateProvider<AnalyticsTimeframe>((ref) => AnalyticsTimeframe.thirtyDays);

class CdssAuditEventModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? hn;
  final String staffName;
  final String severity;
  final String ruleId;
  final String ruleVersion;
  final String recommendation;
  final String staffAction; // 'ACCEPTED', 'OVERRIDDEN', 'DISMISSED'
  final DateTime createdAt;

  CdssAuditEventModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.hn,
    required this.staffName,
    required this.severity,
    required this.ruleId,
    required this.ruleVersion,
    required this.recommendation,
    required this.staffAction,
    required this.createdAt,
  });

  factory CdssAuditEventModel.fromMap(Map<String, dynamic> map) {
    final patient = map['patients'] as Map<String, dynamic>?;
    final firstName = patient?['first_name'] ?? '';
    final lastName = patient?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    return CdssAuditEventModel(
      id: map['id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      patientName: fullName.isEmpty ? 'ไม่ระบุชื่อ' : fullName,
      hn: patient?['hn'],
      staffName: map['staff_name'] ?? 'บุคลากรคลินิก',
      severity: map['severity'] ?? 'ROUTINE',
      ruleId: map['rule_id'] ?? 'TH-HT-2024',
      ruleVersion: map['rule_version'] ?? 'TH-HT-2024.1',
      recommendation: map['recommendation'] ?? '',
      staffAction: map['staff_action'] ?? 'ACCEPTED',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isOverride => staffAction == 'OVERRIDDEN';
  bool get isAccepted => staffAction == 'ACCEPTED';
}

class CdssAuditSummary {
  final int totalEvaluations;
  final int acceptedCount;
  final int overriddenCount;
  final int dismissedCount;
  final double acceptanceRate;
  final double overrideRate;
  final List<CdssAuditEventModel> events;

  CdssAuditSummary({
    required this.totalEvaluations,
    required this.acceptedCount,
    required this.overriddenCount,
    required this.dismissedCount,
    required this.acceptanceRate,
    required this.overrideRate,
    required this.events,
  });
}

final cdssAuditSummaryProvider = FutureProvider.autoDispose<CdssAuditSummary>((ref) async {
  final timeframe = ref.watch(selectedTimeframeProvider);
  final client = Supabase.instance.client;

  final cutoffDate = DateTime.now().subtract(Duration(days: timeframe.days));

  final res = await client
      .from('cdss_events')
      .select('''
        id,
        patient_id,
        staff_name,
        severity,
        rule_id,
        rule_version,
        recommendation,
        staff_action,
        created_at,
        patients!inner (
          first_name,
          last_name,
          hn
        )
      ''')
      .gte('created_at', cutoffDate.toIso8601String())
      .order('created_at', ascending: false)
      .limit(200);

  final list = (res as List<dynamic>).map((e) => CdssAuditEventModel.fromMap(e as Map<String, dynamic>)).toList();

  final total = list.length;
  final accepted = list.where((e) => e.isAccepted).length;
  final overridden = list.where((e) => e.isOverride).length;
  final dismissed = list.where((e) => e.staffAction == 'DISMISSED').length;

  return CdssAuditSummary(
    totalEvaluations: total,
    acceptedCount: accepted,
    overriddenCount: overridden,
    dismissedCount: dismissed,
    acceptanceRate: total > 0 ? (accepted / total) * 100.0 : 0.0,
    overrideRate: total > 0 ? (overridden / total) * 100.0 : 0.0,
    events: list,
  );
});