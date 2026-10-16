import 'package:so_mais_uma/src/utils/utils.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';

class LogoutUseCase implements UseCase<NoParams, void> {
  LogoutUseCase(this._repository);

  final AuthRepository _repository;

  @override
  FutureEither<void> call(NoParams params) {
    return _repository.logout();
  }
}
