import 'package:flutter/material.dart';

class AuthTheme {
  // Core palette
  static const Color midnight = Color(0xFF010F24);
  static const Color deepBlue = Color(0xFF082448);
  static const Color royalBlue = Color(0xFF0F58B3);
  static const Color cyanGlow = Color(0xFF27C0FF);
  static const Color frost = Color(0x26FFFFFF); // 15% white
  static const Color frostStrong = Color(0x40FFFFFF); // 25% white
  static const Color frostSoft = Color(0x14FFFFFF); // 8% white

  static const Color primaryBlue = Color(0xFF0F6DFF);
  static const Color borderBlue = Color(0xFF3AA0FF);
  static const Color textLight = Colors.white;
  static const Color textDim = Color(0xCCFFFFFF);

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [midnight, deepBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentBlur = LinearGradient(
    colors: [Color(0x660F6DFF), Color(0x3327C0FF)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static InputDecoration input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xCCFFFFFF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: frostSoft,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: frost, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      );

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: Color(0xCC0F6DFF),
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(54),
    elevation: 0,
    shadowColor: Colors.black45,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  ).copyWith(
    overlayColor: MaterialStateProperty.resolveWith(
      (states) =>
          states.contains(MaterialState.pressed) ? frostStrong : null,
    ),
  );

  static BoxDecoration glassCard = BoxDecoration(
    color: frostSoft,
    borderRadius: BorderRadius.circular(36),
    border: Border.all(color: frost, width: 1.2),
    boxShadow: const [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 24,
        offset: Offset(0, 18),
      ),
    ],
  );
}
