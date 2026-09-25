import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/facility_management_repository.dart';

class ClinicStaffManagementScreen extends ConsumerWidget {
  const ClinicStaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityAsync = ref.watch(currentFacilityDetailProvider);
    final staffListAsync = ref.watch(facilityStaffListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ส่วนหัวและการ์ดข้อมูลหน่วยบริการ (Facility Info Banner)
            facilityAsync.when(
              loading: () => const LinearProgressIndicator(color: Color(0xFF10B981)),
              error: (err, _) => Text('ข้อผิดพลาด: $err', style: const TextStyle(color: Colors.red)),
              data: (fac) {
                if (fac == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apartment_rounded, color: Color(0xFF10B981), size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fac.facilityName,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'รหัสหน่วยบริการ: ${fac.facilityCode} | Tenant ID: ${fac.id}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          fac.subscriptionStatus,
                          style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // แถบเครื่องมือจัดการรายชื่อเจ้าหน้าที่
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'บุคลากรประจำหน่วยบริการ (Staff Roster)',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'กำหนดบทบาทและสิทธิ์การเข้าถึงเวชระเบียน (RBAC)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddStaffDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('ลงทะเบียนเจ้าหน้าที่ใหม่'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ตารางรายชื่อเจ้าหน้าที่
            Expanded(
              child: staffListAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                error: (err, _) => Center(child: Text('เกิดข้อผิดพลาด: $err', style: const TextStyle(color: Colors.red))),
                data: (staffList) {
                  if (staffList.isEmpty) {
                    return const Center(child: Text('ยังไม่มีข้อมูลเจ้าหน้าที่', style: TextStyle(color: Colors.white70)));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: ListView.separated(
                      itemCount: staffList.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFF334155), height: 1),
                      itemBuilder: (context, index) {
                        final s = staffList[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(s.role).withValues(alpha: 0.15),
                            child: Icon(_getRoleIcon(s.role), color: _getRoleColor(s.role), size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(s.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(s.role).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(s.role, style: TextStyle(color: _getRoleColor(s.role), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'อีเมล: ${s.email} | เลขใบประกอบ: ${s.licenseNo ?? '-'}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'คัดลอก UID',
                                icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Staff UID: ${s.id}'), duration: const Duration(seconds: 2)),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    final uidController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final licenseController = TextEditingController();
    String selectedRole = 'NURSE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ผูกสิทธิ์เจ้าหน้าที่เข้าคลินิก',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('นำ Auth UID ของเจ้าหน้าที่มาผูกสิทธิ์เข้ากับหน่วยบริการ',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(height: 20),
                TextField(
                  controller: uidController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dialogInputDeco('Auth User UID (จากเมนู Auth Users)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dialogInputDeco('ชื่อ - นามสกุล (พร้อมคำนำหน้า)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dialogInputDeco('อีเมลประจำตัวเจ้าหน้าที่'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _dialogInputDeco('บทบาท (Role)'),
                        items: const [
                          DropdownMenuItem(value: 'DOCTOR', child: Text('แพทย์ (DOCTOR)')),
                          DropdownMenuItem(value: 'NURSE', child: Text('พยาบาล (NURSE)')),
                          DropdownMenuItem(value: 'PHARMACIST', child: Text('เภสัชกร (PHARMACIST)')),
                          DropdownMenuItem(value: 'REGISTRATION', child: Text('เวชระเบียน (REGISTRATION)')),
                          DropdownMenuItem(value: 'ADMIN', child: Text('ผู้ดูแลคลินิก (ADMIN)')),
                        ],
                        onChanged: (v) => setDialogState(() => selectedRole = v ?? 'NURSE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: licenseController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _dialogInputDeco('เลขใบประกอบวิชาชีพ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF94A3B8)))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (uidController.text.trim().isEmpty || nameController.text.trim().isEmpty) return;
                        try {
                          await ref.read(facilityManagementRepositoryProvider).registerStaff(
                            userId: uidController.text.trim(),
                            email: emailController.text.trim(),
                            fullName: nameController.text.trim(),
                            role: selectedRole,
                            licenseNo: licenseController.text.trim().isEmpty ? null : licenseController.text.trim(),
                          );
                          ref.invalidate(facilityStaffListProvider);
                          if (context.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ผิดพลาด: $e'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: const Text('บันทึกสิทธิ์'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dialogInputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'DOCTOR':
        return const Color(0xFF0284C7);
      case 'ADMIN':
        return const Color(0xFFDC2626);
      case 'PHARMACIST':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'DOCTOR':
        return Icons.medical_services_rounded;
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'PHARMACIST':
        return Icons.medication_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}