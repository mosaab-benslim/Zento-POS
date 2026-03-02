import '../database/user_dao.dart';
import '../models/user_model.dart';
import 'user_repository.dart';

class LocalUserRepository implements UserRepository {
  final UserDao _userDao;

  LocalUserRepository(this._userDao);

  @override
  Future<UserModel?> loginByPin({
    required String pin,
    required UserRole role,
  }) {
    // Calls your existing DAO logic
    return _userDao.getUserByPinAndRole(pin, role);
  }

  @override
  Future<int> getRepresentativePinLength(UserRole role) {
    return _userDao.getRepresentativePinLength(role);
  }
}
