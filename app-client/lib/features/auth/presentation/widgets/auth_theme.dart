import 'package:flutter/material.dart';

class AuthTheme {
  // warna sesuai mockup
  static const primaryBlue = Color(0xFF0A4D78);
  static const borderBlue  = Color(0xFF1F5F88);
  static const textDark    = Color(0xFF22313F);

  static InputDecoration input(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderBlue, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 1.6),
        ),
      );

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
  );
}
