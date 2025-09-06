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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            final maxW = c.maxWidth;
            // Responsif: di HP penuh (padding 16), di layar lebar center dengan max 420
            final double targetWidth = maxW < 480 ? maxW : 420;
            final double hPad = (maxW - targetWidth) / 2;
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Stack(
                    children: [
                      // HEADER BIRU + LOGO
                      Container(
                        height: 240,
                        decoration: const BoxDecoration(
                          color: AuthTheme.primaryBlue,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(36),
                            bottomRight: Radius.circular(36),
                          ),
                        ),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Image.asset(
                            'assets/images/logo_anomeye.png',
                            height: 160,
                            // supaya tidak crash saat asset belum ada
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.remove_red_eye,
                              color: Colors.white,
                              size: 70,
                            ),
                          ),
                        ),
                      ),

                      // KARTU PUTIH YANG MENGISI TINGGI
                      Padding(
                        padding: const EdgeInsets.only(top: 170),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(36),
                              topRight: Radius.circular(36),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, -2),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AuthTheme.textDark,
                                    )),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                if (showTabs) ...[
                                  // TAB
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
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
                                          text: 'Sign up',
                                          isActive: activeTab == 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    Container(
                                        height: 2,
                                        color: const Color(0xFF024670)),
                                    Align(
                                      alignment: activeTab == 0
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: FractionallySizedBox(
                                        widthFactor: 0.5,
                                        child: Container(
                                          height: 2.4,
                                          color: AuthTheme.borderBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // FORM
                                child,

                                // Spacer agar tombol tidak mepet bawah saat layar tinggi
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.isActive});
  final String text;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isActive ? AuthTheme.textDark : Colors.black45,
      ),
    );
  }
}
