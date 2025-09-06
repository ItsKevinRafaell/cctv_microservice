import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/notifications/presentation/fcm_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends StateNotifier<AuthState> {
  // FIX 1: Hapus deklarasi duplikat. Cukup deklarasikan di constructor.
  final AuthRepo _repo;
  final Ref _ref;
  AuthController(this._repo, this._ref)
      : super(const AuthState.unauthenticated());

  // Method bootstrap untuk memeriksa token saat aplikasi pertama kali dibuka
  Future<void> bootstrap() async {
    state = await _repo.readToken();
    // FIX 2: Gunakan .when untuk memeriksa state dengan aman
    state.when(
      unauthenticated: () {
        // Tidak perlu melakukan apa-apa jika belum login
      },
      authenticated: (token, user) {
        // Jika sudah login, langsung daftarkan FCM token
        _ref.read(fcmControllerProvider.notifier).registerIfPossible();
      },
    );
  }

  Future<void> signUp(String email, String password, String company) async {
    state = await _repo.signUp(
        email: email, password: password, companyId: company);
    // Daftarkan FCM token setelah berhasil sign up
    _ref.read(fcmControllerProvider.notifier).registerIfPossible();
  }

  Future<void> signIn(String email, String password) async {
    state = await _repo.signIn(email: email, password: password);
    // Daftarkan FCM token setelah berhasil login
    _ref.read(fcmControllerProvider.notifier).registerIfPossible();
  }

  Future<void> signOut() async {
    // Hapus token FCM dari backend sebelum sign out
    await _ref.read(fcmControllerProvider.notifier).unregisterFromBackend();
    // Hapus data lokal
    await _repo.signOut();
    state = const AuthState.unauthenticated();
    // Bersihkan state FCM controller
    await _ref.read(fcmControllerProvider.notifier).clear();
  }

  // FIX 3: Hapus method _attachFcmIfAny karena logikanya sudah dipindahkan
  // ke dalam FcmController yang lebih modern.
}
