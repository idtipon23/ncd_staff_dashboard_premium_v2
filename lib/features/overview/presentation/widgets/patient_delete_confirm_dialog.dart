import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../patient_registry/data/patient_registration_repository.dart';
import '../../data/triage_repository.dart';

class PatientDeleteConfirmDialog extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String hn;
  final VoidCallback onDeleted;

  const PatientDeleteConfirmDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.hn,
    required this.onDeleted,
  });

  @override
  ConsumerState<PatientDeleteConfirmDialog> createState() => _PatientDeleteConfirmDialogState();
}

class _PatientDeleteConfirmDialogState extends ConsumerState<PatientDeleteConfirmDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ใส่ Email ของเจ้าหน้าที่ที่กำลังล็อกอินอยู่ให้อัตโนมัติ
    final currentEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    _emailController.text = currentEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกอีเมลและรหัสผ่านเพื่อยืนยันสิทธิ์');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(patientRegistrationRepositoryProvider).deletePatientWithReAuth(
            patientId: widget.patientId,
            email: email,
            password: password,
          );

      // รีเฟรชตารางผู้ป่วยในหน้าภาพรวม
      ref.invalidate(triageOverviewProvider);

      if (mounted) {
        Navigator.pop(context); // ปิด Dialog
        widget.onDeleted();     // ดำเนินการย้อนกลับหน้าจอ
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
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
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ส่วนหัวข้อเตือนอันตราย
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ลบเวชระเบียนผู้ป่วยถาวร',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Cascade Data Purge & Verification',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // กล่องเตือนรายละเอียด
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ผู้ป่วย: ${widget.patientName} (HN: ${widget.hn})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '⚠️ ข้อมูลสัญญาณชีพ (V/S), ผลตรวจแล็บ, ประวัติการรักษา (OPD Visits), รายการยา และการนัดหมายทั้งหมดจะถูกลบทิ้งถาวรจากฐานข้อมูล ไม่สามารถกู้คืนได้',
                    style: TextStyle(color: Color(0xFFF87171), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
              ),
            ],

            const Text('ยืนยันรหัสผ่านแพทย์/เจ้าของคลินิกเพื่อดำเนินการ:',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),

            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'อีเมลเจ้าหน้าที่ / คลินิก',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B), size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'รหัสผ่านเพื่อยืนยันการลบ',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('ยืนยันลบข้อมูลทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}