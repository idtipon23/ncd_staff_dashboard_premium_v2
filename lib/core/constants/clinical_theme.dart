import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClinicalColors {
  // Canvas & Surfaces
  static const Color canvasBg = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Brand Identity
  static const Color primaryEmerald = Color(0xFF2F9E82);
  static const Color totalBlue = Color(0xFF2563EB);
  static const Color totalBlueBg = Color(0xFFEFF6FF);
  static const Color deepCocoa = Color(0xFF4A3833);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textPrimary = Color(0xFF0F172A);

  static const Color sidebarGradientStart = Color(0xFF1F6F63);
  static const Color sidebarGradientEnd = Color(0xFF354B4A);

  static const Color overTreatmentPurple = Color(0xFF7C3AED);
  static const Color overTreatmentBg = Color(0xFFF5F3FF);
  static const Color lostToFollowUpOrange = Color(0xFFF97316);
  static const Color lostToFollowUpBg = Color(0xFFFFF7ED);

  // Clinical Triage Colors (ตามมาตรฐาน NCDs)
  static const Color criticalRed = Color(0xFFDC2626);
  static const Color criticalBg = Color(0xFFFEF2F2);

  static const Color warningOrange = Color(0xFFE8A33D);
  static const Color warningBg = Color(0xFFFFFBEB);

  static const Color normalGreen = Color(0xFF2F9E82);
  static const Color normalBg = Color(0xFFECFDF5);

  static const double cardRadius = 16;
  static const double compactCardRadius = 12;
  static const double pageSpacing = 24;

  // ── Premium depth system ──────────────────────────────────────────────
  // ใช้ soft, layered shadow แทน flat border เดิม เพื่อให้การ์ดดูมีมิติ
  // โดยไม่เปลี่ยนสี/ขนาด/radius ที่ widget อื่นอ้างอิงอยู่
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> coloredGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // Sidebar เดิมใช้ 2 สี ตอนนี้เพิ่ม stop ที่ 3 ให้ลึกขึ้นแบบ premium SaaS
  static const List<Color> sidebarGradient = [
    Color(0xFF16594E),
    sidebarGradientStart,
    sidebarGradientEnd,
  ];

  // Gradient สำหรับไอคอนแบดจ์ในการ์ด KPI (แทนพื้นสีทึบเดิม)
  static LinearGradient iconBadgeGradient(Color base) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base.withValues(alpha: 0.16), base.withValues(alpha: 0.06)],
      );
}

// lib/core/constants/clinical_theme.dart

class ClinicalTheme {
  static ThemeData get lightTheme {
    // ใช้ Inter (Google Fonts) แทนฟอนต์ default ของระบบ — ยกระดับความรู้สึก
    // "พรีเมียม" ของทั้งแอปทันทีโดยไม่ต้องแก้โค้ด UI ทีละจุด
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: ClinicalColors.canvasBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ClinicalColors.primaryEmerald,
        primary: ClinicalColors.primaryEmerald,
        surface: ClinicalColors.surfaceWhite,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: ClinicalColors.textPrimary,
        displayColor: ClinicalColors.textPrimary,
      ),
      // แก้ไขบรรทัดนี้: เปลี่ยนจาก CardTheme เป็น CardThemeData
      cardTheme: CardThemeData(
        color: ClinicalColors.surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ClinicalColors.borderLight, width: 1),
        ),
      ),
    );
  }
}
