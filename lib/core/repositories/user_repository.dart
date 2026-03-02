import '../models/user_model.dart';

abstract class UserRepository {
  Future<UserModel?> loginByPin({
    required String pin,
    required UserRole role,
  });
  Future<int> getRepresentativePinLength(UserRole role);
}
