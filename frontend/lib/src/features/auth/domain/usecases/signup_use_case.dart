import 'package:so_mais_uma/src/utils/utils.dart';
import 'package:so_mais_uma/src/features/auth/domain/entities/user.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';

/// Record-shaped sign-up credentials.
typedef SignUpParams = ({String name, String email, String password});

class SignUpUseCase implements UseCase<SignUpParams, AppUser> {
  SignUpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  FutureEither<AppUser> call(SignUpParams params) {
    final (:name, :email, :password) = params;
    return _repository.signUp(name: name, email: email, password: password);
  }
}
