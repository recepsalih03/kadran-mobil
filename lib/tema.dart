import 'package:material_ui/material_ui.dart';

/// Kadran renkleri: web sitesinin (globals.css) birebir aynısı.
abstract final class Renk {
  static const lacivert = Color(0xFF0F1E36);
  static const lacivertUst = Color(0xFF1B3156);
  static const lacivertSoluk = Color(0xFF4A5F85);
  static const murekkep2 = Color(0xFF3A4354); // ikincil metin
  static const bant = Color(0xFFF5F5F7); // grup kutusu, panel
  static const bant2 = Color(0xFFEBEBEF);
  static const cizgi = Color(0xFFD2D2D7);
  static const alan = Color(0xFF7D8799); // alan ve seçim kenarı
  static const kapali = Color(0xFFCFD4DC);
  static const secili = Color(0xFFC2410C); // seçili kenar, onay işareti
  static const seciliZemin = Color(0xFFFED7AA);
  static const ok = Color(0xFF14532D);
  static const okZemin = Color(0xFFE3F2E7);
  static const bekle = Color(0xFF581C87);
  static const bekleZemin = Color(0xFFF1E8FB);
  static const hayir = Color(0xFF8B1C1C);
  static const hayirZemin = Color(0xFFFBE9E9);
  static const gecti = Color(0xFF2B3340);
  static const gectiZemin = Color(0xFFECEEF2);
}

/// Köşeler: küçük 8, düğme ve alan 12, panel 16, pano 22.
abstract final class Kose {
  static const kucuk = 8.0;
  static const orta = 12.0;
  static const panel = 16.0;
  static const pano = 22.0;
}

/// Yazılar: Inter, gövde 17 px (sitede okunaklılık için seçilen boy).
abstract final class Yazi {
  static const baslik = TextStyle(fontSize: 30, fontWeight: FontWeight.w600, height: 1.15, letterSpacing: -0.6, color: Renk.lacivert);
  static const bolum = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.3, color: Renk.lacivert);
  static const govde = TextStyle(fontSize: 17, height: 1.4, color: Renk.lacivert);
  static const govdeKalin = TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600, color: Renk.lacivert);
  static const ikincil = TextStyle(fontSize: 16, height: 1.4, color: Renk.murekkep2);
  static const kucuk = TextStyle(fontSize: 15, height: 1.35, color: Renk.murekkep2);
  /// Saatler ve sayılar: yarı kalın, eşit genişlikli rakam.
  static const rakam = TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()], color: Renk.lacivert);
}

ThemeData kadranTemasi() {
  final temel = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(seedColor: Renk.lacivert).copyWith(
      primary: Renk.lacivert,
      onPrimary: Colors.white,
      secondary: Renk.secili,
      surface: Colors.white,
      onSurface: Renk.lacivert,
      error: Renk.hayir,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
  final kenar = OutlineInputBorder(borderRadius: BorderRadius.circular(Kose.orta), borderSide: const BorderSide(color: Renk.alan, width: 1.5));
  return temel.copyWith(
    textTheme: temel.textTheme.apply(bodyColor: Renk.lacivert, displayColor: Renk.lacivert, fontFamily: 'Inter'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.lacivert,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Renk.lacivert,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Renk.lacivertSoluk,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Kose.orta)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Renk.lacivert,
        backgroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: Renk.alan, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Kose.orta)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Renk.lacivert,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: kenar,
      enabledBorder: kenar,
      focusedBorder: kenar.copyWith(borderSide: const BorderSide(color: Renk.lacivert, width: 2)),
      errorBorder: kenar.copyWith(borderSide: const BorderSide(color: Renk.hayir, width: 2)),
      focusedErrorBorder: kenar.copyWith(borderSide: const BorderSide(color: Renk.hayir, width: 2)),
      hintStyle: const TextStyle(color: Renk.murekkep2),
      errorStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Renk.hayir),
    ),
    dividerTheme: const DividerThemeData(color: Renk.cizgi, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Renk.lacivert,
      contentTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.lacivert),
  );
}
