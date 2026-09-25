import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/clinical_theme.dart';
import '../../data/clinical_entry_repository.dart';
import '../../../../core/widgets/resizable_clinical_dialog.dart';

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
  final _heightController = TextEditingController();
  final _symptomsController = TextEditingController();

  // Glycemic
  final _fbsController = TextEditingController();
  final _hba1cController = TextEditingController();

  // Lipid Profile
  final _cholesterolController = TextEditingController();
  final _triglyceridesController = TextEditingController();
  final _hdlController = TextEditingController();
  final _ldlController = TextEditingController();

  // Renal & Electrolytes
  final _bunController = TextEditingController();
  final _creatinineController = TextEditingController();
  final _egfrController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _potassiumController = TextEditingController();
  final _chlorideController = TextEditingController();
  final _bicarbonateController = TextEditingController();

  // Liver & Metabolic
  final _astController = TextEditingController();
  final _altController = TextEditingController();
  final _alpController = TextEditingController();
  final _uricAcidController = TextEditingController();

  // Urine Tests
  final _uacrController = TextEditingController();
  final _urineProteinController = TextEditingController();

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
    _heightController.dispose();
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

  void _pickWebFile() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*,.pdf';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((e) {
          if (mounted) {
            setState(() {
              _pickedFileName = file.name;
              _pickedFileBytes = reader.result as Uint8List?;
            });
          }
        });
      }
    });
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
            heightCm: double.tryParse(_heightController.text.trim()),
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
            totalCholesterol: double.tryParse(_cholesterolController.text.trim()),
            triglycerides: double.tryParse(_triglyceridesController.text.trim()),
            hdl: double.tryParse(_hdlController.text.trim()),
            ldl: double.tryParse(_ldlController.text.trim()),
            bun: double.tryParse(_bunController.text.trim()),
            creatinine: double.tryParse(_creatinineController.text.trim()),
            egfr: double.tryParse(_egfrController.text.trim()),
            sodium: double.tryParse(_sodiumController.text.trim()),
            potassium: double.tryParse(_potassiumController.text.trim()),
            chloride: double.tryParse(_chlorideController.text.trim()),
            bicarbonate: double.tryParse(_bicarbonateController.text.trim()),
            ast: double.tryParse(_astController.text.trim()),
            alt: double.tryParse(_altController.text.trim()),
            alp: double.tryParse(_alpController.text.trim()),
            uricAcid: double.tryParse(_uricAcidController.text.trim()),
            urineMicroalbumin: double.tryParse(_uacrController.text.trim()),
            urineProtein: _urineProteinController.text.trim().isEmpty ? null : _urineProteinController.text.trim(),
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
    return ResizableClinicalDialog(
      startMaximized: true,
        child: Container(
        width: 880,
        height: 720,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header ส่วนหัวคลีนสว่าง
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_chart_rounded, color: Color(0xFF059669), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'บันทึกผลตรวจทางคลินิก (Clinical Entry)',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ผู้ป่วย: ${widget.patientName} | บันทึกสัญญาณชีพ ผลแล็บ และภาพเอกซเรย์/EKG เข้าประวัติ',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
            const SizedBox(height: 18),

            // TabBar สไตล์โมเดิร์น
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF059669),
                indicatorWeight: 3,
                labelColor: const Color(0xFF059669),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.favorite_outline, size: 20), text: 'สัญญาณชีพ & อาการ (V/S)'),
                  Tab(icon: Icon(Icons.biotech_outlined, size: 20), text: 'ผลตรวจแล็บเลือด/ปัสสาวะ'),
                  Tab(icon: Icon(Icons.image_outlined, size: 20), text: 'ภาพ EKG / X-Ray ทรวงอก'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Views
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
              Expanded(child: _buildInput('ความดันตัวบน (SBP) *', _sbpController, suffix: 'mmHg', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('ความดันตัวล่าง (DBP) *', _dbpController, suffix: 'mmHg', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('ชีพจร (Pulse) *', _hrController, suffix: 'bpm', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInput('อุณหภูมิ (Body Temp)', _tempController, suffix: '°C', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('อัตราการหายใจ (RR)', _rrController, suffix: '/min', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('น้ำหนักตัว (BW)', _weightController, suffix: 'kg', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('ส่วนสูง (Height)', _heightController, suffix: 'cm', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput('อาการสำคัญ / ข้อสังเกตเพิ่มเติม (Symptoms & Notes)', _symptomsController, maxLines: 3, hint: 'เช่น ปวดศีรษะ เวียนศีรษะ ไม่มีแรง ทานยาตรงเวลา'),
          const SizedBox(height: 24),
          _buildSubmitButton('บันทึกสัญญาณชีพเข้าประวัติ', _saveVitalSigns),
        ],
      ),
    );
  }

  Widget _buildLabsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. หมวดเบาหวาน (Glycemic Control)
          _buildLabSectionHeader('1. ระดับน้ำตาลในเลือด (Glycemic Control)', Icons.water_drop_outlined),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildInput('FBS (Fasting Blood Sugar)', _fbsController, suffix: 'mg/dL')),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('HbA1c (น้ำตาลสะสม)', _hba1cController, suffix: '%')),
            ],
          ),
          const SizedBox(height: 20),

          // 2. หมวดไขมันในเลือด (Lipid Profile)
          _buildLabSectionHeader('2. ไขมันในเลือด (Lipid Profile)', Icons.pie_chart_outline_rounded),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildInput('Total Cholesterol', _cholesterolController, suffix: 'mg/dL')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('Triglycerides', _triglyceridesController, suffix: 'mg/dL')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('HDL-C', _hdlController, suffix: 'mg/dL')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('LDL-C', _ldlController, suffix: 'mg/dL')),
            ],
          ),
          const SizedBox(height: 20),

          // 3. หมวดการทำงานของไตและเกลือแร่ (Renal & Electrolytes)
          _buildLabSectionHeader('3. การทำงานของไต & เกลือแร่ (Renal Function & Electrolytes)', Icons.biotech_rounded),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildInput('BUN', _bunController, suffix: 'mg/dL')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('Creatinine', _creatinineController, suffix: 'mg/dL')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('eGFR', _egfrController, suffix: 'ml/min')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInput('Sodium (Na+)', _sodiumController, suffix: 'mEq/L')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('Potassium (K+)', _potassiumController, suffix: 'mEq/L')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('Chloride (Cl-)', _chlorideController, suffix: 'mEq/L')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('Bicarbonate (CO2)', _bicarbonateController, suffix: 'mEq/L')),
            ],
          ),
          const SizedBox(height: 20),

          // 4. หมวดตับและกรดยูริก (Liver Function & Metabolic)
          _buildLabSectionHeader('4. การทำงานของตับ & ยูริก (Liver Function & Uric Acid)', Icons.local_hospital_outlined),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildInput('AST (SGOT)', _astController, suffix: 'U/L')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('ALT (SGPT)', _altController, suffix: 'U/L')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('ALP', _alpController, suffix: 'U/L')),
              const SizedBox(width: 14),
              Expanded(child: _buildInput('Uric Acid', _uricAcidController, suffix: 'mg/dL')),
            ],
          ),
          const SizedBox(height: 20),

          // 5. หมวดตรวจปัสสาวะ (Urine Tests)
          _buildLabSectionHeader('5. การตรวจปัสสาวะ (Urinalysis & Albuminuria)', Icons.science_outlined),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildInput('Urine Microalbumin (UACR)', _uacrController, suffix: 'mg/g Cr')),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('Urine Protein / Dipstick', _urineProteinController, hint: 'Negative, Trace, 1+, 2+')),
            ],
          ),
          const SizedBox(height: 20),

          // บันทึกสรุป
          _buildInput('สรุปผลตรวจและข้อสังเกตทางห้องปฏิบัติการ', _labNotesController, maxLines: 2, hint: 'ความเห็นของแพทย์หรือนักเทคนิคการแพทย์'),
          const SizedBox(height: 24),
          _buildSubmitButton('บันทึกผลตรวจแล็บทั้งหมดเข้าประวัติ', _saveLabResults),
        ],
      ),
    );
  }

  Widget _buildLabSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildDiagnosticImagingTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ประเภทการตรวจพิเศษ', style: TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('EKG 12-Lead', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: _diagType == 'EKG',
                selectedColor: const Color(0xFF059669),
                labelStyle: TextStyle(color: _diagType == 'EKG' ? Colors.white : const Color(0xFF334155)),
                onSelected: (_) => setState(() => _diagType = 'EKG'),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Chest X-Ray', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: _diagType == 'XRAY',
                selectedColor: const Color(0xFF059669),
                labelStyle: TextStyle(color: _diagType == 'XRAY' ? Colors.white : const Color(0xFF334155)),
                onSelected: (_) => setState(() => _diagType = 'XRAY'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput('ผลอ่านและการวินิจฉัยภาพ (Clinical Interpretation) *', _diagInterpretationController, maxLines: 3, hint: 'เช่น Normal sinus rhythm, No cardiomegaly, No active lung infiltration'),
          const SizedBox(height: 16),

          // Upload Box โทนสว่าง สะอาดตา
          InkWell(
            onTap: _pickWebFile,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _pickedFileName ?? 'คลิกเพื่อเลือกไฟล์ภาพกราฟ EKG หรือฟิล์ม X-Ray จากเครื่อง',
                      style: TextStyle(
                        color: _pickedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        fontWeight: _pickedFileName != null ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildInput('หรือระบุ URL รูปภาพผลตรวจ (Direct / PACS URL)', _imageUrlController, hint: 'https://...'),
          const SizedBox(height: 24),
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
        Text(
          label,
          style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
            ),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}