/// 네트워크 실패를 정규화한 예외 체계.
///
/// UI/Repository 계층은 이 타입만 다루고, dio 예외를 직접 잡지 않는다.
sealed class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 연결/응답 시간 초과.
final class NetworkTimeoutException extends NetworkException {
  const NetworkTimeoutException() : super('request timed out');
}

/// 네트워크 연결 불가 (오프라인, DNS 실패 등).
final class NetworkConnectionException extends NetworkException {
  const NetworkConnectionException() : super('connection failed');
}

/// 서버가 4xx/5xx 상태 코드로 응답.
final class NetworkBadResponseException extends NetworkException {
  const NetworkBadResponseException(this.statusCode)
    : super('bad response ($statusCode)');

  final int statusCode;

  bool get isClientError => statusCode >= 400 && statusCode < 500;

  bool get isServerError => statusCode >= 500;
}

/// 호출 측에서 요청을 취소함.
final class NetworkCancelledException extends NetworkException {
  const NetworkCancelledException() : super('request cancelled');
}

/// 위 분류에 속하지 않는 실패.
final class NetworkUnknownException extends NetworkException {
  const NetworkUnknownException([String? detail])
    : super(detail ?? 'unknown network error');
}
