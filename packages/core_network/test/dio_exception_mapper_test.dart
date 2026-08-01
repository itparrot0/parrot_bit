import 'package:core_network/core_network.dart';
import 'package:core_network/src/dio_exception_mapper.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final options = RequestOptions(path: '/test');

  DioException dioError(DioExceptionType type, {Response<Object?>? response}) =>
      DioException(requestOptions: options, type: type, response: response);

  group('mapDioException', () {
    test('타임아웃 계열은 NetworkTimeoutException으로 정규화된다', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(mapDioException(dioError(type)), isA<NetworkTimeoutException>());
      }
    });

    test('연결 실패는 NetworkConnectionException으로 정규화된다', () {
      expect(
        mapDioException(dioError(DioExceptionType.connectionError)),
        isA<NetworkConnectionException>(),
      );
    });

    test('badResponse는 상태 코드를 보존한다', () {
      final mapped = mapDioException(
        dioError(
          DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 404),
        ),
      );

      expect(mapped, isA<NetworkBadResponseException>());
      final badResponse = mapped as NetworkBadResponseException;
      expect(badResponse.statusCode, 404);
      expect(badResponse.isClientError, isTrue);
      expect(badResponse.isServerError, isFalse);
    });

    test('취소는 NetworkCancelledException으로 정규화된다', () {
      expect(
        mapDioException(dioError(DioExceptionType.cancel)),
        isA<NetworkCancelledException>(),
      );
    });

    test('그 외는 NetworkUnknownException으로 정규화된다', () {
      expect(
        mapDioException(dioError(DioExceptionType.unknown)),
        isA<NetworkUnknownException>(),
      );
    });
  });
}
