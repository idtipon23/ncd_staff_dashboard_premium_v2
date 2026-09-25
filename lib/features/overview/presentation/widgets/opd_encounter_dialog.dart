import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/clinical_theme.dart';
import '../../data/opd_visit_repository.dart';
import '../../../../core/widgets/resizable_clinical_dialog.dart';

class OpdEncounterDialog extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final int? sbp;
  final int? dbp;
  final int? pulse;
  final VoidCallback onSaved;

  const OpdEncounterDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    this.sbp,
    this.dbp,
    this.pulse,
    required this.onSaved,
  });

  @override
  ConsumerState<OpdEncounterDialog> createState() => _OpdEncounterDialogState();
}

class _OpdEncounterDialogState extends ConsumerState<OpdEncounterDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // History Taking
  final _ccController = TextEditingController();
  final _piController = TextEditingController();
  final _phController = TextEditingController();
  final _allergyController = TextEditingController();

  // Physical Examination
  final _peGeneralController = TextEditingController(text: 'Good consciousness, not pale, no jaundice');
  final _peHeentController = TextEditingController(text: 'Pharynx not injected, tonsil not enlarged');
  final _peHeartController = TextEditingController(text: 'Normal S1 S2, no murmur');
  final _peLungsController = TextEditingController(text: 'Clear both lungs, no adventitious sound');
  final _peAbdomenController = TextEditingController(text: 'Soft, not tender, no distension');
  final _peExtremitiesController = TextEditingController(text: 'No pretibial edema');

  // Diagnosis & Plan
  final _dxController = TextEditingController();
  final _icd10Controller = TextEditingController();
  final _planController = TextEditingController();
  final _rxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ccController.dispose();
    _piController.dispose();
    _phController.dispose();
    _allergyController.dispose();
    _peGeneralController.dispose();
    _peHeentController.dispose();
    _peHeartController.dispose();
    _peLungsController.dispose();
    _peAbdomenController.dispose();
    _peExtremitiesController.dispose();
    _dxController.dispose();
    _icd10Controller.dispose();
    _planController.dispose();
    _rxController.dispose();
    super.dispose();
  }

  Future<void> _submitEncounter() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    if (_dxController.text.trim().isEmpty) {
      _tabController.animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุการวินิจฉัยโรค (Diagnosis)'), backgroundColor: ClinicalColors.criticalRed),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> prescriptionList = [];
      if (_rxController.text.trim().isNotEmpty) {
        prescriptionList.add({
          'item_name': _rxController.text.trim(),
          'ordered_at': DateTime.now().toIso8601String(),
        });
      }

      await ref.read(opdVisitRepositoryProvider).saveOpdVisit(
            patientId: widget.patientId,
            sbp: widget.sbp,
            dbp: widget.dbp,
            pulse: widget.pulse,
            chiefComplaint: _ccController.text.trim(),
            presentIllness: _piController.text.trim(),
            pastHistory: _phController.text.trim(),
            medicationAllergy: _allergyController.text.trim(),
            peGeneral: _peGeneralController.text.trim(),
            peHeent: _peHeentController.text.trim(),
            peHeart: _peHeartController.text.trim(),
            peLungs: _peLungsController.text.trim(),
            peAbdomen: _peAbdomenController.text.trim(),
            peExtremities: _peExtremitiesController.text.trim(),
            diagnosisText: _dxController.text.trim(),
            icd10Code: _icd10Controller.text.trim(),
            treatmentPlan: _planController.text.trim(),
            prescriptions: prescriptionList,
          );

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResizableClinicalDialog(
        startMaximized: true,
        child: Container(
        width: 980,
        height: 780,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header ส่วนหัวสว่าง พร้อมค่าสัญญาณชีพใหญ่ชัด
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Color(0xFF0284C7), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'บันทึกการตรวจรักษาผู้ป่วยนอก (OPD Encounter)',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('ผู้ป่วย: ${widget.patientName}',
                                style: const TextStyle(color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                'V/S ล่าสุด: ${widget.sbp ?? '-'}/${widget.dbp ?? '-'} mmHg (PR: ${widget.pulse ?? '-'} bpm)',
                                style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // TabBar
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF0284C7),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF0284C7),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(icon: Icon(Icons.history_edu_outlined, size: 20), text: '1. ซักประวัติอาการ (CC / PI)'),
                    Tab(icon: Icon(Icons.accessibility_new_outlined, size: 20), text: '2. ตรวจร่างกาย (Physical Exam)'),
                    Tab(icon: Icon(Icons.assignment_turned_in_outlined, size: 20), text: '3. การวินิจฉัย & แผนการรักษา (Dx / Plan / Rx)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHistoryTab(),
                    _buildPhysicalExamTab(),
                    _buildDiagnosisPlanTab(),
                  ],
                ),
              ),

              // Actions Footer
              const Divider(color: Color(0xFFE2E8F0), height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitEncounter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('บันทึกเวชระเบียนการรักษา', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildField(
            label: 'อาการสำคัญที่มาพบแพทย์ (Chief Complaint: CC) *',
            controller: _ccController,
            hint: 'เช่น มาตรวจตามนัดความดันโลหิตสูง, ปวดศีรษะท้ายทอย 2 วัน',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณาระบุอาการสำคัญ' : null,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'ประวัติการเจ็บป่วยปัจจุบัน (Present Illness: PI)',
            controller: _piController,
            hint: 'รายละเอียดอาการ ระยะเวลา ปัจจัยกระตุ้น หรืออาการร่วมอื่นๆ',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  label: 'ประวัติโรคประจำตัว / การผ่าตัด (Past History)',
                  controller: _phController,
                  hint: 'เช่น HT 5 ปี, DLP, ไม่เคยผ่าตัด',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildField(
                  label: 'ประวัติแพ้ยา / แพ้อาหาร (Allergy)',
                  controller: _allergyController,
                  hint: 'ระบุชื่อยา หรือ ปฏิเสธการแพ้ยา',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalExamTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildField(label: 'General Appearance', controller: _peGeneralController)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(label: 'HEENT (ศีรษะ ตา หู คอ จมูก)', controller: _peHeentController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildField(label: 'Heart & CVS (หัวใจและหลอดเลือด)', controller: _peHeartController)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(label: 'Lungs & Thorax (ปอดและทรวงอก)', controller: _peLungsController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildField(label: 'Abdomen (ช่องท้อง)', controller: _peAbdomenController)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(label: 'Extremities (รยางค์/แขนขา)', controller: _peExtremitiesController)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisPlanTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildField(
                  label: 'การวินิจฉัยโรค (Diagnosis: Dx) *',
                  controller: _dxController,
                  hint: 'เช่น Essential Hypertension, Type 2 DM, Acute URI',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณาระบุผลการวินิจฉัย' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildField(
                  label: 'รหัส ICD-10',
                  controller: _icd10Controller,
                  hint: 'I10, E11.9, J00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'รายการยาที่สั่งจ่าย (Prescription / Rx)',
            controller: _rxController,
            hint: 'เช่น Amlodipine (5mg) 1 tab po od pc เช้า #30\nMetformin (500mg) 1 tab po bid pc เช้า-เย็น #60',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'แผนการดูแลและคำแนะนำผู้ป่วย (Treatment Plan & Advice)',
            controller: _planController,
            hint: 'เช่น ควบคุมอาหารเค็ม, ลดแป้ง, นัด F/U ติดตามความดัน 1 เดือน',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
            errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
          ),
        ),
      ],
    );
  }
}