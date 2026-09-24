import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/clinical_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/presentation/staff_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // กำหนดค่าผ่าน --dart-define ได้ และมีค่าเริ่มต้นสำรองเพื่อไม่ให้ระบบหยุดทำงาน
  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bnoeebyqecqtrjzxdwlf.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJub2VlYnlxZWNxdHJqenhkd2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzMDkzMDMsImV4cCI6MjEwMDg4NTMwM30.klDucuGqFfdXy1hAYDzTWGHG7C1Q3kMOdnfuIC5ls20',
  );

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ClinicalMonitoringApp()));
}

class ClinicalMonitoringApp extends StatelessWidget {
  const ClinicalMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCDs Clinical Command Center',
      debugShowCheckedModeBanner: false,
      theme: ClinicalTheme.lightTheme,
      home: const StaffAuthGate(),
    );
  }
}

/// ประตูดักจับสถานะการเข้าสู่ระบบของบุคลากร (Reactive Staff Auth Gate)
class StaffAuthGate extends StatelessWidget {
  const StaffAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // ตรวจสอบ Session จาก Stream หรือ Local Session ปัจจุบัน
        final session = snapshot.hasData
            ? snapshot.data!.session
            : Supabase.instance.client.auth.currentSession;

        // หากยังไม่ได้ล็อกอิน ให้พาไปหน้าเข้าสู่ระบบบุคลากร
        if (session == null) {
          return const StaffLoginScreen();
        }

        // หากล็อกอินเรียบร้อยแล้ว ให้เข้าสู่แดชบอร์ดหลักของคลินิก
        return const AppShell();
      },
    );
  }
}