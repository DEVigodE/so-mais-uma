import 'package:so_mais_uma/src/imports/core_imports.dart';
import 'package:so_mais_uma/src/imports/packages_imports.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';

class AuthStore {
  AuthStore({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;

  final _state = signal<RequestState<void>>(const RequestInitial());

  ReadonlySignal<RequestState<void>> get state => _state;

  late final ReadonlySignal<bool> isLoading =
      computed(() => _state.value.isLoading);

  void login({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    _state.value = const RequestLoading();

    final result = await _repository.login(email: email, password: password);

    result.fold(
      (failure) {
        _state.value = RequestFailure(failure);
        if (context.mounted) {
          showToast(context, message: failure.message, status: 'error');
        }
      },
      (_) {
        _state.value = const RequestSuccess(null);
        if (context.mounted) {
          context.go(AppRoutes.home);
        }
      },
    );
  }

  void signUp({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
  }) async {
    _state.value = const RequestLoading();

    final result = await _repository.signUp(
      name: name,
      email: email,
      password: password,
    );

    result.fold(
      (failure) {
        _state.value = RequestFailure(failure);
        if (context.mounted) {
          showToast(context, message: failure.message, status: 'error');
        }
      },
      (_) {
        _state.value = const RequestSuccess(null);
        if (context.mounted) {
          context.go(AppRoutes.home);
        }
      },
    );
  }

  void forgotPassword({
    required BuildContext context,
    required String email,
  }) async {
    _state.value = const RequestLoading();

    final result = await _repository.forgotPassword(email: email);

    result.fold(
      (failure) {
        _state.value = RequestFailure(failure);
        if (context.mounted) {
          showToast(context, message: failure.message, status: 'error');
        }
      },
      (_) {
        _state.value = const RequestSuccess(null);
        if (context.mounted) {
          showToast(
            context,
            message: 'Password reset link sent successfully',
            status: 'success',
          );
        }
        if (context.mounted) {
          context.go(AppRoutes.login);
        }
      },
    );
  }

  void dispose() {
    isLoading.dispose();
    _state.dispose();
  }
}
