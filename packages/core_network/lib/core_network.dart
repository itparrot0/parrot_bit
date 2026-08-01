/// HTTP 통신과 그 실패를 정규화하는 계층.
///
/// 공개 API에 dio 타입을 노출하지 않는다. 엔드포인트 정의와
/// 응답 도메인 모델은 각 앱의 Repository가 소유한다.
library;

export 'src/api_client.dart';
export 'src/network_exception.dart';
