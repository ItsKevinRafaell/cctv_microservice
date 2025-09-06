import 'package:anomeye/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:anomeye/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:anomeye/features/auth/presentation/widgets/auth_theme.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final ctrl = ref.read(authStateProvider.notifier);
    await ctrl.signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome Back!',
      subtitle: 'Please Sign In with your account',
      activeTab: 0,
      onTapSignIn: () {},
      onTapSignUp: () => context.go('/sign-up'),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _email,
              decoration: AuthTheme.input('E-mail'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'E-mail is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              decoration: AuthTheme.input('Password').copyWith(
                suffixIcon: IconButton(
                  icon:
                      Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Min. 6 characters' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                style:
                    TextButton.styleFrom(foregroundColor: AuthTheme.borderBlue),
                child: const Text('Forgot Password?',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AuthTheme.primaryButton,
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have account yet? ",
                    style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                InkWell(
                  onTap: () => context.go('/sign-up'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 0.0),
                    child: Text('Sign Up',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AuthTheme.primaryBlue,
                          decoration: TextDecoration.underline,
                        )),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
