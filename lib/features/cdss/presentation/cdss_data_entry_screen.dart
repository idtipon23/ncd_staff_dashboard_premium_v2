// lib/features/cdss/presentation/cdss_data_entry_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/clinical_theme.dart';
import '../../../services/ht_cdss_engine.dart';
import '../../overview/data/patient_triage_model.dart';
import '../../overview/data/triage_repository.dart' hide TriageCategory;
import '../../overview/presentation/patient_detail_screen.dart';

class CdssDataEntryScreen extends ConsumerStatefulWidget {
  const CdssDataEntryScreen({super.key});

  @override
  ConsumerState<CdssDataEntryScreen> createState() => _CdssDataEntryScreenState();
}

class _CdssDataEntryScreenState extends ConsumerState<CdssDataEntryScreen> {
  PatientTriageModel? _selectedPatient;

  final _sbpController = TextEditingController();
  final _dbpController = TextEditingController();
  final _pulseController = TextEditingController();
  final _egfrController = TextEditingController();
  final _potassiumController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _uricAcidController = TextEditingController();
  final _creatinineController = TextEditingController();
  final _fbsController = TextEditingController();

  bool _hasCvd = false;
  bool _hasDm = false;
  bool _hasHmod = false;
  bool _hasAcuteTod = false;
  bool _isFrail = false;
  bool _hasHighNocturnalBp = false;
  bool _isMaxToleratedDose = false;

  final Set<String> _selectedMedClasses = {};
  ClinicalRecommendationResult? _cdssResult;
  bool _isSaving = false;

  static const _availableMeds = [
    'CCB',
    'ACEI',
    'ARB',
    'Thiazide-Diuretic',
    'Loop-Diuretic',
    'Spironolactone',
    'Beta-blocker',
    'Alpha-blocker',
  ];

  @override
  void dispose() {
    _sbpController.dispose();
    _dbpController.dispose();
    _pulseController.dispose();
    _egfrController.dispose();
    _potassiumController.dispose();
    _sodiumController.dispose();
    _uricAcidController.dispose();
    _creatinineController.dispose();
    _fbsController.dispose();
    super.dispose();
  }

  void _onPatientSelected(PatientTriageModel? patient) {
    if (patient == null) return;
    setState(() {
      _selectedPatient = patient;
      _sbpController.text = patient.systolic?.toString() ?? '';
      _dbpController.text = patient.diastolic?.toString() ?? '';
      _pulseController.text = patient.pulse?.toString() ?? '';
      _egfrController.text = patient.egfr?.toString() ?? '';
      _potassiumController.clear();
      _sodiumController.clear();
      _uricAcidController.clear();
      _creatinineController.clear();
      _fbsController.text = patient.fbs?.toString() ?? '';

      final diseases = patient.underlyingDiseases?.toLowerCase() ?? '';
      _hasCvd = diseases.contains('cvd') || diseases.contains('stroke') || diseases.contains('หัวใจ');
      _hasDm = diseases.contains('dm') || diseases.contains('diabetes') || diseases.contains('เบาหวาน') || (patient.fbs ?? 0) >= 126;
      _hasAcuteTod = false;

      _selectedMedClasses.clear();
      if (patient.hasMedication) {
        _selectedMedClasses.add('CCB');
      }
      _cdssResult = null;
    });
  }

  void _evaluateCdss() {
    final sbp = int.tryParse(_sbpController.text.trim()) ?? 0;
    final dbp = int.tryParse(_dbpController.text.trim()) ?? 0;
    final pulse = int.tryParse(_pulseController.text.trim()) ?? 0;
    final double? egfr = double.tryParse(_egfrController.text.trim());
    final double? potassium = double.tryParse(_potassiumController.text.trim());
    final double? sodium = double.tryParse(_sodiumController.text.trim());
    final double? uricAcid = double.tryParse(_uricAcidController.text.trim());
    final double? creatinine = double.tryParse(_creatinineController.text.trim());
    final hasSevereBp = sbp >= 180 || dbp >= 110;

    if (sbp <= 0 || dbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุค่าความดันโลหิต SYS และ DIA ให้ถูกต้อง'),
          backgroundColor: ClinicalColors.criticalRed,
        ),
      );
      return;
    }

    final age = _selectedPatient?.age ?? 55;
    double calculatedCvRisk = 4.0;
    if (_hasCvd) {
      calculatedCvRisk = 25.0;
    } else {
      if (age >= 60) calculatedCvRisk += 6.0;
      if (_hasDm) calculatedCvRisk += 5.0;
      if (sbp >= 160) {
        calculatedCvRisk += 6.0;
      } else if (sbp >= 140) {
        calculatedCvRisk += 3.0;
      }
    }

    final inputData = HtPatientData(
      age: age,
      sex: _selectedPatient?.gender ?? 'ชาย',
      officeSbp: sbp,
      officeDbp: dbp,
      heartRate: pulse,
      hasCvd: _hasCvd,
      hasDm: _hasDm,
      cvRiskScore: calculatedCvRisk,
      hasHmod: _hasHmod,
      egfr: egfr,
      potassium: potassium,
      serumSodium: sodium,
      serumUricAcid: uricAcid,
      currentCreatinine: creatinine,
      isFrail: _isFrail,
      hasHighNocturnalBp: _hasHighNocturnalBp,
      medCount: _selectedMedClasses.length,
      currentMedClasses: _selectedMedClasses.toList(),
      isMaxToleratedDose: _isMaxToleratedDose,
      hasAcuteTargetOrganDamage: _hasAcuteTod && hasSevereBp,
      historyHighBp: true,
      visitCount: 2,
    );

    setState(() {
      if (!hasSevereBp) _hasAcuteTod = false;
      _cdssResult = HtCdssEngine.evaluate(inputData);
    });
  }

  Future<void> _saveAssessment() async {
    if (_selectedPatient == null || _cdssResult == null) return;
    setState(() => _isSaving = true);

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final staffName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'พยาบาลวิชาชีพเวชปฏิบัติ';

    final sbp = int.tryParse(_sbpController.text.trim()) ?? 0;
    final dbp = int.tryParse(_dbpController.text.trim()) ?? 0;
    final pulse = int.tryParse(_pulseController.text.trim()) ?? 0;

    try {
      // 1. บันทึกสัญญาณชีพใหม่
      await client.from('vital_signs').insert({
        'patient_id': _selectedPatient!.patientId,
        'systolic': sbp,
        'diastolic': dbp,
        'pulse': pulse,
        'recorded_at': DateTime.now().toIso8601String(),
      });

      // 2. บันทึก CDSS Audit Event
      final inputSnapshot = {
        'sbp': sbp,
        'dbp': dbp,
        'pulse': pulse,
        'egfr': _egfrController.text.trim(),
        'potassium': _potassiumController.text.trim(),
        'sodium': _sodiumController.text.trim(),
        'uricAcid': _uricAcidController.text.trim(),
        'creatinine': _creatinineController.text.trim(),
        'hasAcuteTargetOrganDamage': _hasAcuteTod && (sbp >= 180 || dbp >= 110),
        'medClasses': _selectedMedClasses.toList(),
        'hasCvd': _hasCvd,
        'hasDm': _hasDm,
      };

      await client.from('cdss_events').insert({
        'patient_id': _selectedPatient!.patientId,
        'staff_id': user?.id,
        'staff_name': staffName,
        'rule_id': 'TH-HT-2024-SCREENING',
        'rule_version': 'TH-HT-2024.1',
        'severity': sbp >= 180 || dbp >= 110 ? 'CRITICAL' : 'ROUTINE',
        'input_snapshot': jsonEncode(inputSnapshot),
        'recommendation': _cdssResult!.medicationChoices.join('; '),
        'staff_action': 'ACCEPTED',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. บันทึกโน้ตติดตามอาการ
      await client.from('staff_notes').insert({
        'patient_id': _selectedPatient!.patientId,
        'staff_name': staffName,
        'note_text': 'บันทึกประเมิน CDSS: BP $sbp/$dbp mmHg, เป้าหมาย: ${_cdssResult!.bpTargetOffice}',
      });

      ref.invalidate(triageOverviewProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกสัญญาณชีพและการประเมิน CDSS สำเร็จ'),
            backgroundColor: ClinicalColors.primaryEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึก: $e'),
            backgroundColor: ClinicalColors.criticalRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final triageAsync = ref.watch(triageOverviewProvider);

    return Scaffold(
      backgroundColor: ClinicalColors.canvasBg,
      body: triageAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ClinicalColors.primaryEmerald),
        ),
        error: (err, _) => Center(
          child: Text('เกิดข้อผิดพลาด: $err', style: const TextStyle(color: ClinicalColors.criticalRed)),
        ),
        data: (patients) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เวิร์กสเปซบันทึกและประเมินผล CDSS (Clinical Decision Support Workspace)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'คัดกรองสัญญาณชีพรอบใหม่ ประมวลผลแนวทางรักษาตาม Thai HT Guidelines 2024 และบันทึก Audit Trail',
                      style: TextStyle(fontSize: 12.5, color: ClinicalColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Step 1: ค้นหาและเลือกผู้ป่วย
                _buildPatientSelectorCard(patients),
                const SizedBox(height: 20),

                if (_selectedPatient != null) ...[
                  // Step 2: กรอกข้อมูลทางคลินิกและเลือกกลุ่มยา
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 900;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildVitalsAndLabCard()),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: _buildClinicalFlagsAndMedsCard()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildVitalsAndLabCard(),
                            const SizedBox(height: 20),
                            _buildClinicalFlagsAndMedsCard(),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // ปุ่มประมวลผล CDSS
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ClinicalColors.primaryEmerald,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _evaluateCdss,
                    icon: const Icon(Icons.analytics_rounded, size: 18),
                    label: const Text('ประมวลผลคำแนะนำ CDSS (Evaluate Protocol)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),

                  // Step 3: แสดงผลลัพธ์คำแนะนำ CDSS
                  if (_cdssResult != null) _buildCdssResultCard(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientSelectorCard(List<PatientTriageModel> patients) {
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
              Icon(Icons.person_search_rounded, color: ClinicalColors.totalBlue, size: 20),
              SizedBox(width: 8),
              Text('1. เลือกผู้ป่วยสำหรับคัดกรอง / ประเมิน (Select Patient)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Autocomplete<PatientTriageModel>(
            displayStringForOption: (p) => '${p.fullName} (${p.hn ?? 'ไม่มี HN'})',
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return patients.take(8);
              }
              final q = textEditingValue.text.toLowerCase();
              return patients.where((p) => p.fullName.toLowerCase().contains(q) || (p.hn?.toLowerCase().contains(q) ?? false));
            },
            onSelected: _onPatientSelected,
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ค้นหาชื่อ-นามสกุล หรือ HN ผู้ป่วย...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              );
            },
          ),
          if (_selectedPatient != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: ClinicalColors.normalGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ผู้ป่วย: ${_selectedPatient!.fullName} | HN: ${_selectedPatient!.hn ?? "-"} | อายุ: ${_selectedPatient!.age ?? "-"} ปี | โรค: ${_selectedPatient!.underlyingDiseases ?? "-"}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: _selectedPatient!.patientId)),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('ดูประวัติเดิม', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsAndLabCard() {
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
              Icon(Icons.monitor_heart_rounded, color: ClinicalColors.criticalRed, size: 20),
              SizedBox(width: 8),
              Text('2. ข้อมูลสัญญาณชีพและผลแล็บ (Vitals & Labs)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sbpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ความดันตัวบน (SYS)', hintText: 'mmHg', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _dbpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ความดันตัวล่าง (DIA)', hintText: 'mmHg', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _pulseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ชีพจร (Pulse)', hintText: 'bpm', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _egfrController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'eGFR', hintText: 'ml/min', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _potassiumController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'โพแทสเซียม (K+)', hintText: 'mEq/L', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _fbsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'น้ำตาล FBS', hintText: 'mg/dL', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _sodiumController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'โซเดียม (Na+)', hintText: 'mEq/L', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _uricAcidController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'กรดยูริก', hintText: 'mg/dL', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _creatinineController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Creatinine', hintText: 'mg/dL', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalFlagsAndMedsCard() {
    final sbp = int.tryParse(_sbpController.text.trim()) ?? 0;
    final dbp = int.tryParse(_dbpController.text.trim()) ?? 0;
    final hasSevereBp = sbp >= 180 || dbp >= 110;

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
              Icon(Icons.medication_rounded, color: ClinicalColors.primaryEmerald, size: 20),
              SizedBox(width: 8),
              Text('3. กลุ่มยาปัจจุบันและประวัติโรค (Current Regimen)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableMeds.map((med) {
              final selected = _selectedMedClasses.contains(med);
              return FilterChip(
                label: Text(med, style: TextStyle(fontSize: 11.5, color: selected ? Colors.white : ClinicalColors.textPrimary)),
                selected: selected,
                selectedColor: ClinicalColors.primaryEmerald,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedMedClasses.add(med);
                    } else {
                      _selectedMedClasses.remove(med);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const Divider(height: 20, color: ClinicalColors.canvasBg),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildCheckbox('ประวัติ CVD / Stroke', _hasCvd, (v) => setState(() => _hasCvd = v ?? false)),
              _buildCheckbox('เบาหวาน (DM)', _hasDm, (v) => setState(() => _hasDm = v ?? false)),
              _buildCheckbox('ภาวะอวัยวะเป้าหมายทำลาย (HMOD)', _hasHmod, (v) => setState(() => _hasHmod = v ?? false)),
              if (hasSevereBp)
                _buildCheckbox('สงสัยอวัยวะเป้าหมายถูกทำลายเฉียบพลัน (Acute TOD)', _hasAcuteTod, (v) => setState(() => _hasAcuteTod = v ?? false)),
              _buildCheckbox('ผู้ป่วยเปราะบาง (Frail)', _isFrail, (v) => setState(() => _isFrail = v ?? false)),
              _buildCheckbox('ความดันกลางคืนสูง (Nocturnal BP)', _hasHighNocturnalBp, (v) => setState(() => _hasHighNocturnalBp = v ?? false)),
              _buildCheckbox('ใช้ยาขนาดสูงสุดแล้ว (Max Dose)', _isMaxToleratedDose, (v) => setState(() => _isMaxToleratedDose = v ?? false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: onChanged, activeColor: ClinicalColors.primaryEmerald),
        Text(label, style: const TextStyle(fontSize: 11.5, color: ClinicalColors.textPrimary)),
      ],
    );
  }

  Widget _buildCdssResultCard() {
    final res = _cdssResult!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicalColors.surfaceWhite,
        borderRadius: BorderRadius.circular(ClinicalColors.cardRadius),
        border: Border.all(color: ClinicalColors.primaryEmerald.withValues(alpha: 0.4)),
        boxShadow: ClinicalColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.verified_rounded, color: ClinicalColors.primaryEmerald, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ผลประเมินตาม Thai HT Guidelines 2024', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('การวินิจฉัย: ${res.diagnosisEvaluation}', style: const TextStyle(fontSize: 12, color: ClinicalColors.primaryEmerald, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ClinicalColors.primaryEmerald),
                onPressed: _isSaving ? null : _saveAssessment,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึกคำสั่งการลงเวชระเบียน'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Safety Alerts
          if (res.safetyAlerts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: res.safetyAlerts.map((alert) => Text('🚨 $alert', style: const TextStyle(fontSize: 12, color: ClinicalColors.criticalRed, fontWeight: FontWeight.bold))).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Targets & Medication Choices
          Text('🎯 เป้าหมายความดัน: ${res.bpTargetOffice} (Home BP: ${res.bpTargetHome})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClinicalColors.textPrimary)),
          const SizedBox(height: 10),
          const Text('ทางเลือกการปรับยาที่แนะนำ:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ClinicalColors.textMuted)),
          const SizedBox(height: 6),
          ...res.medicationChoices.map((choice) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: ClinicalColors.primaryEmerald, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(choice, style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          Text('คำแนะนำพฤติกรรม & เวลาทานยา: ${res.defaultDosingTimeAdvice}', style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted)),
        ],
      ),
    );
  }
}