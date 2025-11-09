import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:anomeye/features/auth/presentation/widgets/auth_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activeTab, // 0 = Sign In, 1 = Sign Up
    required this.onTapSignIn,
    required this.onTapSignUp,
    required this.child,
    this.showTabs = true,
  });

  final String title;
  final String subtitle;
  final int activeTab;
  final VoidCallback onTapSignIn;
  final VoidCallback onTapSignUp;
  final Widget child;
  final bool showTabs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AuthTheme.backgroundGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -40,
                child: _GlowCircle(
                  diameter: 220,
                  colors: const [
                    Color(0x3327C0FF),
                    Color(0x663AA0FF),
                  ],
                ),
              ),
              Positioned(
                bottom: -100,
                right: -40,
                child: _GlowCircle(
                  diameter: 260,
                  colors: const [
                    Color(0x3320ABFF),
                    Color(0x661672FF),
                  ],
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final targetWidth = maxW < 520 ? maxW : 460;
                    final horizontalPadding = maxW <= 520
                        ? 20.0
                        : (maxW - targetWidth) / 2;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        28,
                        horizontalPadding,
                        32,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            _LogoBadge(),
                            const SizedBox(height: 26),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(36),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 24,
                                  sigmaY: 24,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  decoration: AuthTheme.glassCard.copyWith(
                                    gradient: AuthTheme.accentBlur,
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 28, 24, 30),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: AuthTheme.textLight,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AuthTheme.textDim,
                                        ),
                                      ),
                                      if (showTabs) ...[
                                        const SizedBox(height: 20),
                                        _Tabs(
                                          activeTab: activeTab,
                                          onTapSignIn: onTapSignIn,
                                          onTapSignUp: onTapSignUp,
                                        ),
                                      ],
                                      if (showTabs) const SizedBox(height: 18),
                                      child,
                                      const SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.activeTab,
    required this.onTapSignIn,
    required this.onTapSignUp,
  });

  final int activeTab;
  final VoidCallback onTapSignIn;
  final VoidCallback onTapSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: onTapSignIn,
              child: _TabLabel(
                text: 'Sign In',
                isActive: activeTab == 0,
              ),
            ),
            InkWell(
              onTap: onTapSignUp,
              child: _TabLabel(
                text: 'Sign Up',
                isActive: activeTab == 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(height: 2, color: Colors.white24),
            AnimatedAlign(
              alignment: activeTab == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: FractionallySizedBox(
                widthFactor: 0.55,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AuthTheme.borderBlue, AuthTheme.primaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.isActive});
  final String text;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isActive ? Colors.white : Colors.white54,
      ),
      child: Text(text),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      width: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.4),
        gradient: const LinearGradient(
          colors: [Color(0x330F6DFF), Color(0x6627C0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Image.asset(
          'assets/images/logo_anomeye.png',
          color: Colors.white,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.remove_red_eye,
            color: Colors.white,
            size: 42,
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.diameter, required this.colors});

  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
