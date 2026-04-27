import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryMid,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'NotoSansKR',

        // ── AppBar ──────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: false,
          titleSpacing: -4,
          leadingWidth: 34,
          scrolledUnderElevation: 1,
          shadowColor: Color(0x18000000),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D1B3E),
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0D1B3E), size: 20),
        ),

        // ── Card ────────────────────────────────
        cardTheme: const CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),

        // ── ElevatedButton ──────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMid,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(
              fontFamily: 'NotoSansKR',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),

        // ── OutlinedButton ──────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryMid,
            side: const BorderSide(color: AppColors.primaryMid, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'NotoSansKR',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── TextButton ──────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryMid,
            textStyle: const TextStyle(
              fontFamily: 'NotoSansKR',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── InputDecoration ──────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryMid, width: 2),
          ),
          hintStyle: const TextStyle(
            color: AppColors.gray3,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: const TextStyle(
            color: AppColors.text2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        // ── Divider ─────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 0,
        ),

        // ── TabBar ──────────────────────────────
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.primaryMid,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primaryMid,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        // ── BottomSheet ─────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
      );
}
