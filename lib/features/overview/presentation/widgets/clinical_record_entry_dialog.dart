import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/clinical_theme.dart';
import '../../../../core/utils/web_file_utils.dart';
import '../../data/clinical_entry_repository.dart';

class ClinicalRecordEntryDialog extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final VoidCallback onSaved;

  const ClinicalRecordEntryDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.onSaved,
  });

  @override
  ConsumerState<ClinicalRecordEntryDialog> createState() => _ClinicalRecordEntryDialogState();
}

class _ClinicalRecordEntryDialogState extends ConsumerState<ClinicalRecordEntryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Controllers: Vital Signs
  final _sbpController = TextEditingController();
  final _dbpController = TextEditingController();
  final _hrController = TextEditingController();
  final _tempController = TextEditingController();
  final _rrController = TextEditingController();
  final _weightController = TextEditingController();
  final _symptomsController = TextEditingController();

  // Controllers: Labs
  final _fbsController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _creatinineController = TextEditingController();
  final _egfrController = TextEditingController();
  final _potassiumController = TextEditingController();
  final _ldlController = TextEditingController();
  final _labNotesController = TextEditingController();

  // Controllers: X-ray & EKG
  String _diagType = 'EKG';
  final _diagInterpretationController = TextEditingController();
  final _imageUrlController = TextEditingController();
  Uint8List? _pickedFileBytes;
  String? _pickedFileName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sbpController.dispose();
    _dbpController.dispose();
    _hrController.dispose();
    _tempController.dispose();
    _rrController.dispose();
    _weightController.dispose();
    _symptomsController.dispose();
    _fbsController.dispose();
    _hba1cController.dispose();
    _creatinineController.dispose();
    _egfrController.dispose();
    _potassiumController.dispose();
    _ldlController.dispose();
    _labNotesController.dispose();
    _diagInterpretationController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  /// เลือกไฟล์ภาพ/เอกสารเฉพาะบน Web runtime โดยไม่ทำให้ VM/test compile ผิด
  Future<void> _pickWebFile() async {
    final picked = await WebFileUtils.pickImageOrPdf();
    if (picked == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _pickedFileName = picked.name;
        _pickedFileBytes = picked.bytes;
      });
    }
  }

  Future<void> _saveVitalSigns() async {
    final sbp = int.tryParse(_sbpController.text.trim());
    final dbp = int.tryParse(_dbpController.text.trim());
    final hr = int.tryParse(_hrController.text.trim());

    if (sbp == null || dbp == null || hr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุ SBP, DBP และชีพจรให้ครบถ้วน'),
          backgroundColor: ClinicalColors.criticalRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(clinicalEntryRepositoryProvider).saveVitalSigns(
            patientId: widget.patientId,
            systolic: sbp,
            diastolic: dbp,
            pulse: hr,
            temperature: double.tryParse(_tempController.text.trim()),
            respiratoryRate: int.tryParse(_rrController.text.trim()),
            weightKg: double.tryParse(_weightController.text.trim()),
            symptomsOrFeedback: _symptomsController.text.trim().isEmpty ? null : _symptomsController.text.trim(),
          );

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLabResults() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(clinicalEntryRepositoryProvider).saveLabResults(
            patientId: widget.patientId,
            labDate: DateTime.now(),
            fbs: double.tryParse(_fbsController.text.trim()),
            hba1c: double.tryParse(_hba1cController.text.trim()),
            creatinine: double.tryParse(_creatinineController.text.trim()),
            egfr: double.tryParse(_egfrController.text.trim()),
            potassium: double.tryParse(_potassiumController.text.trim()),
            ldl: double.tryParse(_ldlController.text.trim()),
            interpretation: _labNotesController.text.trim().isEmpty ? null : _labNotesController.text.trim(),
          );

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกผลแล็บไม่สำเร็จ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDiagnosticImaging() async {
    if (_diagInterpretationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกผลอ่าน/ข้อสรุปการตรวจ'),
          backgroundColor: ClinicalColors.criticalRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? uploadedUrl = _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : null;

      if (_pickedFileBytes != null && _pickedFileName != null) {
        uploadedUrl = await ref.read(clinicalEntryRepositoryProvider).uploadClinicalImage(
              patientId: widget.patientId,
              bytes: _pickedFileBytes!,
              fileName: _pickedFileName!,
            );
      }

      await ref.read(clinicalEntryRepositoryProvider).saveDiagnosticImaging(
            patientId: widget.patientId,
            testType: _diagType,
            examDate: DateTime.now(),
            interpretation: _diagInterpretationController.text.trim(),
            imageUrl: uploadedUrl,
          );

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_chart_rounded, color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'บันทึกผลตรวจทางคลินิก (Clinical Entry)',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'ผู้ป่วย: ${widget.patientName}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF10B981),
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: const Color(0xFF94A3B8),
              tabs: const [
                Tab(icon: Icon(Icons.favorite_outline, size: 20), text: 'สัญญาณชีพ & อาการ'),
                Tab(icon: Icon(Icons.biotech_outlined, size: 20), text: 'ผลตรวจแล็บ'),
                Tab(icon: Icon(Icons.image_outlined, size: 20), text: 'EKG / X-Ray'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVitalSignsTab(),
                  _buildLabsTab(),
                  _buildDiagnosticImagingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInput('ความดันตัวบน (SBP)', _sbpController, suffix: 'mmHg', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('ความดันตัวล่าง (DBP)', _dbpController, suffix: 'mmHg', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('ชีพจร (Pulse)', _hrController, suffix: 'bpm', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInput('อุณหภูมิ (Temp)', _tempController, suffix: '°C', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('อัตราหายใจ (RR)', _rrController, suffix: 'bpm', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('น้ำหนัก (BW)', _weightController, suffix: 'kg', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput('อาการสำคัญ / ข้อสังเกตเพิ่มเติม (Symptoms)', _symptomsController, maxLines: 3),
          const SizedBox(height: 20),
          _buildSubmitButton('บันทึกสัญญาณชีพ', _saveVitalSigns),
        ],
      ),
    );
  }

  Widget _buildLabsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInput('FBS', _fbsController, suffix: 'mg/dL')),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('HbA1c', _hba1cController, suffix: '%')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInput('Creatinine', _creatinineController, suffix: 'mg/dL')),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('eGFR', _egfrController, suffix: 'ml/min')),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('Potassium (K+)', _potassiumController, suffix: 'mEq/L')),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput('LDL Cholesterol', _ldlController, suffix: 'mg/dL'),
          const SizedBox(height: 12),
          _buildInput('สรุปผลตรวจทางห้องปฏิบัติการ', _labNotesController, maxLines: 2),
          const SizedBox(height: 20),
          _buildSubmitButton('บันทึกผลตรวจแล็บ', _saveLabResults),
        ],
      ),
    );
  }

  Widget _buildDiagnosticImagingTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ประเภทการตรวจ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('EKG 12-Lead'),
                selected: _diagType == 'EKG',
                selectedColor: const Color(0xFF059669),
                onSelected: (_) => setState(() => _diagType = 'EKG'),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('Chest X-Ray'),
                selected: _diagType == 'XRAY',
                selectedColor: const Color(0xFF059669),
                onSelected: (_) => setState(() => _diagType = 'XRAY'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInput('ผลอ่านและการวินิจฉัย (Interpretation)', _diagInterpretationController, maxLines: 3),
          const SizedBox(height: 14),

          // Upload Box
          InkWell(
            onTap: _pickWebFile,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pickedFileName ?? 'คลิกเพื่อเลือกไฟล์ภาพกราฟ EKG หรือฟิล์ม X-Ray จากเครื่อง',
                      style: TextStyle(
                        color: _pickedFileName != null ? Colors.white : const Color(0xFF64748B),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInput('หรือระบุ URL รูปภาพผลตรวจ (Direct / PACS URL)', _imageUrlController, hint: 'https://...'),
          const SizedBox(height: 20),
          _buildSubmitButton('บันทึกผลการตรวจพิเศษ', _saveDiagnosticImaging),
        ],
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    String? suffix,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }
}