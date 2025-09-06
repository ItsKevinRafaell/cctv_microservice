import 'package:anomeye/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:anomeye/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:anomeye/features/auth/presentation/widgets/auth_theme.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _hide1 = true, _hide2 = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (_password.text != _confirm.text) {
      setState(() => _loading = false);
      return;
    }
    try {
      final ctrl = ref.read(authStateProvider.notifier);
      await ctrl.signUp(_email.text, _password.text, 'PT. Jaya Abadi');
    } catch (e) {
      setState(() => _loading = false);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: "Let's Get Started!",
      subtitle: 'by signing up your account first.',
      activeTab: 1,
      onTapSignIn: () => context.go('/sign-in'),
      onTapSignUp: () {},
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
                  icon: Icon(_hide1 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hide1 = !_hide1),
                ),
              ),
              obscureText: _hide1,
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Min. 6 characters' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              decoration: AuthTheme.input('Confirm Password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_hide2 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hide2 = !_hide2),
                ),
              ),
              obscureText: _hide2,
              validator: (v) =>
                  (v != _password.text) ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AuthTheme.primaryButton,
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Sign Up'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                InkWell(
                  onTap: () => context.go('/sign-in'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Sign In',
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
