import 'package:anomeye/app/di.dart';
import 'package:dio/dio.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ctrl = ref.read(authStateProvider.notifier);
      await ctrl.signIn(_email.text.trim(), _password.text);
    } on DioException catch (e) {
      final data = e.response?.data;
      var message = 'Tidak dapat masuk. Periksa kembali kredensial Anda.';
      if (data is Map<String, dynamic>) {
        final serverMessage = data['message'] ?? data['error'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('Terjadi kesalahan tak terduga. Coba lagi.')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in to AnomEye',
      subtitle:
          'Enterprise-grade monitoring, analytics, and alerts in one secure console.',
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
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Forgot password?'),
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
          ],
        ),
      ),
    );
  }
}
