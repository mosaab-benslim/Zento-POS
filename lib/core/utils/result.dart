class Result<T> {
  final T? _value;
  final String? _error;

  Result.success(this._value) : _error = null;
  Result.failure(this._error) : _value = null;

  bool get isSuccess => _error == null;
  bool get isFailure => _error != null;

  T get value {
    if (isFailure) throw Exception('Cannot get value from failure result: $_error');
    return _value!;
  }

  String get error {
    if (isSuccess) throw Exception('Cannot get error from success result');
    return _error!;
  }
}
