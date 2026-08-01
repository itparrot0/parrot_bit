/// 성공/실패를 명시적으로 표현하는 결과 타입.
///
/// Repository 계층이 예외 대신 반환값으로 실패를 전달할 때 사용한다.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(Object error, [StackTrace? stackTrace]) =
      Failure<T>;

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
  }) =>
      switch (this) {
        Success(:final value) => success(value),
        Failure(:final error, :final stackTrace) => failure(error, stackTrace),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success(:final value) => Result.success(transform(value)),
        Failure(:final error, :final stackTrace) =>
          Result.failure(error, stackTrace),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}
