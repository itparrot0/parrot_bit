import 'package:dio/dio.dart';

import 'network_exception.dart';

/// 내부 전용: DioException을 [NetworkException]으로 정규화한다.
///
/// 배럴에서 export하지 않는다 — dio 타입이 공개 API에 새는 것을 막는다.
NetworkException mapDioException(DioException exception) {
  return switch (exception.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout =>
      const NetworkTimeoutException(),
    DioExceptionType.connectionError => const NetworkConnectionException(),
    DioExceptionType.badResponse => NetworkBadResponseException(
        exception.response?.statusCode ?? 0,
      ),
    DioExceptionType.cancel => const NetworkCancelledException(),
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown =>
      NetworkUnknownException(exception.message),
  };
}
