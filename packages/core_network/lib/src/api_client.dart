import 'package:dio/dio.dart';

import 'dio_exception_mapper.dart';

/// dio를 캡슐화한 HTTP 클라이언트.
///
/// JSON 디코딩된 응답 본문(`Map`/`List`/원시값)을 반환하고,
/// 모든 실패는 [NetworkException] 하위 타입으로 던진다.
final class ApiClient {
  ApiClient({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String> defaultHeaders = const {},
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: timeout,
           sendTimeout: timeout,
           receiveTimeout: timeout,
           headers: defaultHeaders,
         ),
       );

  final Dio _dio;

  Future<Object?> get(String path, {Map<String, Object?>? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) =>
      _send(() => _dio.post<Object?>(path, data: body, queryParameters: query));

  Future<Object?> put(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) =>
      _send(() => _dio.put<Object?>(path, data: body, queryParameters: query));

  Future<Object?> delete(String path, {Map<String, Object?>? query}) =>
      _send(() => _dio.delete<Object?>(path, queryParameters: query));

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}
