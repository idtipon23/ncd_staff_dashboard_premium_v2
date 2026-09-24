import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/clinical_theme.dart';
import '../../data/patient_registration_repository.dart';
import '../../../overview/data/triage_repository.dart';

class PatientRegistrationDialog extends ConsumerStatefulWidget {
  const PatientRegistrationDialog({super.key});

  @override
  ConsumerState<PatientRegistrationDialog> createState() =>
      _PatientRegistrationDialogState();
}

class _PatientRegistrationDialogState
    extends ConsumerState<PatientRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _hnController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _diseasesController = TextEditingController(text: 'HT');

  String _selectedGender = 'ชาย';
  String _selectedCategory = 'HT';
  bool _isLoading = false;

  @override
  void dispose() {
    _hnController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _diseasesController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final params = PatientRegistrationParams(
        hn: _hnController.text.trim().isEmpty
            ? null
            : _hnController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        phone: _phoneController.text.trim(),
        underlyingDiseases: _diseasesController.text.trim(),
        patientCategory: _selectedCategory,
        weightKg: double.tryParse(_weightController.text.trim()),
        heightCm: double.tryParse(_heightController.text.trim()),
      );

      final newPatient = await ref
          .read(patientRegistrationRepositoryProvider)
          .registerPatient(params);

      // รีเฟรชตาราง Triage Overview เพื่อให้คนไข้ใหม่แสดงขึ้นหน้าจอทันที
      ref.invalidate(triageOverviewProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ลงทะเบียนคนไข้เรียบร้อย: ${newPatient['name']} (HN: ${newPatient['hn']})',
            ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF10B981),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ลงทะเบียนผู้ป่วยใหม่ (New Patient)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ผูกเวชระเบียนเข้าสังกัดหน่วยบริการอัตโนมัติ',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // HN & Category
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        label: 'หมายเลข HN (เว้นว่างเพื่อสร้างอัตโนมัติ)',
                        controller: _hnController,
                        hint: 'เว้นว่างระบบจะออกให้ เช่น 69-000001',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'กลุ่มการรักษา',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                value: 'HT',
                                child: Text('Hypertension (HT)'),
                              ),
                              DropdownMenuItem(
                                value: 'DM',
                                child: Text('Diabetes (DM)'),
                              ),
                              DropdownMenuItem(
                                value: 'HT_DM',
                                child: Text('HT + DM'),
                              ),
                              DropdownMenuItem(
                                value: 'GENERAL',
                                child: Text('เวชปฏิบัติทั่วไป'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedCategory = val ?? 'HT'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // First Name & Last Name
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'ชื่อจริง *',
                        controller: _firstNameController,
                        hint: 'ระบุชื่อจริง',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรุณาระบุชื่อ'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildTextField(
                        label: 'นามสกุล *',
                        controller: _lastNameController,
                        hint: 'ระบุนามสกุล',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรุณาระบุนามสกุล'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gender, Age, Phone
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'เพศ *',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                value: 'ชาย',
                                child: Text('ชาย'),
                              ),
                              DropdownMenuItem(
                                value: 'หญิง',
                                child: Text('หญิง'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedGender = val ?? 'ชาย'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        label: 'อายุ (ปี) *',
                        controller: _ageController,
                        hint: 'เช่น 58',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'กรุณากรอกอายุ';
                          if (int.tryParse(v.trim()) == null)
                            return 'ตัวเลขเท่านั้น';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        label: 'เบอร์โทรศัพท์',
                        controller: _phoneController,
                        hint: '08X-XXX-XXXX',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weight, Height & Diseases
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'น้ำหนัก (kg)',
                        controller: _weightController,
                        hint: 'เช่น 68.5',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        label: 'ส่วนสูง (cm)',
                        controller: _heightController,
                        hint: 'เช่น 165',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        label: 'โรคประจำตัว',
                        controller: _diseasesController,
                        hint: 'เช่น HT, DLP, เกาต์',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(
                        'บันทึกเวชระเบียน',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(color: Color(0xFFF87171), fontSize: 11),
    );
  }
}
