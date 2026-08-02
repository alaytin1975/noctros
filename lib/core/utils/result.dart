import '../errors/noctros_failure.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T get valueOrThrow {
    final self = this;
    if (self is Success<T>) {
      return self.value;
    }
    throw StateError('Called valueOrThrow on a failed result.');
  }

  NoctrosFailure? get failureOrNull {
    final self = this;
    if (self is FailureResult<T>) {
      return self.failure;
    }
    return null;
  }

  Result<R> map<R>(R Function(T value) transform) {
    final self = this;
    if (self is Success<T>) {
      return Success(transform(self.value));
    }
    return FailureResult((self as FailureResult<T>).failure);
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final NoctrosFailure failure;
}
